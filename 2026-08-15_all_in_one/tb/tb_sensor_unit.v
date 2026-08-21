`timescale 1ns / 1ps

//=====================================================================
// tb_sensor_unit  -  sensor_unit 단독 무작위 테스트벤치
//
//  대상 : sensor_unit.v  (sr04_controller + dht11_controller + 값 래치)
//
//  두 컨트롤러 자체는 tb_sr04_controller / tb_dht11_controller 에서
//  따로 본다. 여기서 볼 것은 이 블록이 더 얹은 부분이다.
//    - 체크섬을 통과한 DHT11 값만 래치해서 내보내는가
//    - 체크섬이 깨지면 0 으로 지우고 dht_valid=0 으로 내리는가
//    - 래치한 값이 다음 측정 전까지 그대로 유지되는가
//    - 표시/전송에 쓰는 정수부([15:8])만 잘라 내보내는가
//    - SR04 쪽 값이 그대로 통과하는가
//    - 두 센서가 서로 간섭하지 않는가
//
//  테스트벤치가 HC-SR04 와 DHT11 센서 역할을 한다. "1us"=2클럭.
//
//  [무작위로 만드는 것]
//    SR04 : echo 폭과 응답 지연
//    DHT11 : 40비트 데이터, 체크섬 정상/불량, 비트 길이, 응답 지연
//=====================================================================
module tb_sensor_unit ();

    localparam integer TICK = 2;  // "1us" = 2클럭

    reg clk = 1'b0;
    reg reset;

    reg  sr04_start;
    reg  echo;
    wire trigger;
    wire [8:0] distance;
    wire sr04_done, sr04_valid;

    reg  dht_start;
    wire [7:0] humidity, temperature;
    wire dht_done, dht_valid;
    wire [5:0] dht_dbg_step;

    wire dht11_io;
    reg  tb_low;
    assign dht11_io = tb_low ? 1'b0 : 1'bz;
    pullup (dht11_io);

    integer seed, seed0;
    integer errors, checks;
    integer i, k, guard, hi_us, dly, w;
    integer exp_lo, exp_hi;
    reg [39:0] frame;
    reg [7:0]  csum;
    reg        want_ok;

    reg       sr_done_seen, sr_cap_valid;
    reg [8:0] sr_cap_dist;
    reg       dh_done_seen;

    always #5 clk = ~clk;

    sensor_unit #(
        .TICK_1US       (TICK),
        .SAMPLE_GUARD_US(0)
    ) DUT (
        .clk         (clk),
        .reset       (reset),
        .sr04_start  (sr04_start),
        .echo        (echo),
        .trigger     (trigger),
        .distance    (distance),
        .sr04_done   (sr04_done),
        .sr04_valid  (sr04_valid),
        .dht_start   (dht_start),
        .dht11_io    (dht11_io),
        .humidity    (humidity),
        .temperature (temperature),
        .dht_done    (dht_done),
        .dht_valid   (dht_valid),
        .dht_dbg_step(dht_dbg_step)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  H=%0d T=%0d dv=%b dist=%0d sv=%b",
                             $time, tag, humidity, temperature, dht_valid,
                             distance, sr04_valid);
            end
        end
    endtask

    always @(posedge clk) begin
        if (sr04_done) begin
            sr_done_seen = 1'b1;
            sr_cap_valid = sr04_valid;
            sr_cap_dist  = distance;
        end
        if (dht_done) dh_done_seen = 1'b1;
    end

    task wait_us(input integer n);
        begin
            repeat (n * TICK) @(negedge clk);
        end
    endtask

    function integer calc_cm(input integer us);
        begin
            calc_cm = (us * 1130 + 32768) / 65536;
        end
    endfunction

    //================= HC-SR04 한 번 측정 =================
    task sr04_shot(input integer width_us, input integer delay_us);
        begin
            w = width_us;
            @(negedge clk);
            sr_done_seen = 1'b0;
            sr04_start   = 1'b1;
            @(negedge clk);
            sr04_start = 1'b0;

            guard = 0;
            while (trigger !== 1'b1 && guard < 200) begin
                @(negedge clk);
                guard = guard + 1;
            end
            chk(trigger === 1'b1, "no trigger from sensor_unit");
            while (trigger === 1'b1) @(negedge clk);

            wait_us(delay_us);
            echo = 1'b1;
            wait_us(width_us);
            echo = 1'b0;

            guard = 0;
            while (sr_done_seen !== 1'b1 && guard < (width_us + 3000) * TICK) begin
                @(negedge clk);
                guard = guard + 1;
            end
            chk(sr_done_seen === 1'b1, "sr04_done never came");

            exp_lo = calc_cm(width_us - 1);
            exp_hi = calc_cm(width_us + 1);
            chk(sr_cap_valid === 1'b1, "sr04 valid echo reported invalid");
            chk(sr_cap_dist >= exp_lo && sr_cap_dist <= exp_hi, "sr04 distance wrong");
            repeat (20) @(negedge clk);
        end
    endtask

    //================= DHT11 한 프레임 =================
    task dht_frame(input [39:0] d);
        begin
            frame = d;
            @(negedge clk);
            dh_done_seen = 1'b0;
            dht_start = 1'b1;
            @(negedge clk);
            dht_start = 1'b0;

            // START Low 를 잡았다 놓을 때까지
            guard = 0;
            while (dht11_io !== 1'b0 && guard < 40_000 * TICK) begin
                @(negedge clk); guard = guard + 1;
            end
            chk(dht11_io === 1'b0, "DUT did not drive the START low");
            guard = 0;
            while (dht11_io !== 1'b1 && guard < 40_000 * TICK) begin
                @(negedge clk); guard = guard + 1;
            end

            // 센서 응답
            wait_us(dly);
            tb_low = 1'b1; wait_us(80);
            tb_low = 1'b0; wait_us(80);
            for (k = 39; k >= 0; k = k - 1) begin
                tb_low = 1'b1; wait_us(50);
                tb_low = 1'b0;
                if (d[k]) hi_us = 65 + ({$random(seed)} % 11);
                else      hi_us = 24 + ({$random(seed)} % 7);
                wait_us(hi_us);
            end
            tb_low = 1'b1; wait_us(50);
            tb_low = 1'b0;

            guard = 0;
            while (dh_done_seen !== 1'b1 && guard < 3000 * TICK) begin
                @(negedge clk); guard = guard + 1;
            end
            chk(dh_done_seen === 1'b1, "dht_done never came");
            @(negedge clk);  // 래치가 반영되는 클럭

            csum = d[39:32] + d[31:24] + d[23:16] + d[15:8];
            if (d[7:0] == csum) begin
                chk(dht_valid === 1'b1,      "checksum ok but dht_valid=0");
                chk(humidity  === d[39:32],  "humidity integer part wrong");
                chk(temperature === d[23:16],"temperature integer part wrong");
            end else begin
                chk(dht_valid === 1'b0,     "checksum bad but dht_valid=1");
                chk(humidity  === 8'd0,     "humidity not cleared on bad checksum");
                chk(temperature === 8'd0,   "temperature not cleared on bad checksum");
            end
            repeat (50) @(negedge clk);
        end
    endtask

    initial begin
        seed0  = 32'h5E4E_0011;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset      = 1'b1;
        sr04_start = 1'b0;
        dht_start  = 1'b0;
        echo       = 1'b0;
        tb_low     = 1'b0;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (20) @(negedge clk);

        //---------------- start 전에는 아무 것도 안 나간다 ----------------
        repeat (300) begin
            @(negedge clk);
            chk(trigger === 1'b0,      "trigger without start");
            chk(dht11_io === 1'b1,     "DHT line pulled low without start");
        end

        //---------------- SR04 : 무작위 3회 ----------------
        for (i = 0; i < 3; i = i + 1)
            sr04_shot(150 + ({$random(seed)} % 2500), 10 + ({$random(seed)} % 100));
        $display("  sr04 last : %0d cm (valid=%b)", distance, sr04_valid);

        //---------------- DHT11 : 정상 프레임 ----------------
        dly   = 30;
        frame = {8'd60, 8'd0, 8'd25, 8'd0, 8'd85};
        dht_frame(frame);
        $display("  dht latched : H=%0d%% T=%0dC valid=%b", humidity, temperature, dht_valid);

        // 래치한 값이 그대로 유지되는가
        repeat (500) begin
            @(negedge clk);
            chk(humidity === 8'd60 && temperature === 8'd25 && dht_valid === 1'b1,
                "latched value did not hold");
        end

        //---------------- DHT11 : 체크섬 깨진 프레임 -> 0 으로 지워야 한다 ----------------
        frame = {8'd77, 8'd0, 8'd33, 8'd0, 8'd0};  // 올바른 값은 110
        dht_frame(frame);

        //---------------- 다시 정상 프레임이면 살아나야 한다 ----------------
        frame = {8'd41, 8'd0, 8'd18, 8'd0, 8'd59};
        dht_frame(frame);

        //---------------- 무작위 프레임 ----------------
        for (i = 0; i < 3; i = i + 1) begin
            frame[39:8] = {$random(seed)};
            csum        = frame[39:32] + frame[31:24] + frame[23:16] + frame[15:8];
            want_ok     = (({$random(seed)} % 2) == 0);
            if (want_ok) frame[7:0] = csum;
            else         frame[7:0] = csum ^ 8'h5a;
            dly = 20 + ({$random(seed)} % 21);
            dht_frame(frame);
        end

        //---------------- 두 센서가 서로 간섭하지 않는가 ----------------
        //  DHT11 값을 래치해 둔 뒤 SR04 를 돌려도 온습도가 흔들리면 안 된다
        frame = {8'd55, 8'd0, 8'd22, 8'd0, 8'd77};
        dht_frame(frame);
        sr04_shot(1740, 40);
        chk(humidity === 8'd55 && temperature === 8'd22,
            "sr04 measurement disturbed the dht values");
        chk(distance > 0, "sr04 distance lost after dht frame");

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_sensor_unit : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_sensor_unit : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #30_000_000;
        $display("  tb_sensor_unit : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
