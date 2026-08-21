`timescale 1ns / 1ps

//=====================================================================
// tb_dht11_controller  -  dht11_controller 단독 무작위 테스트벤치
//
//  대상 : dht11_controller.v
//
//  DHT11 은 선 하나로 주고받는다(오픈드레인 + 풀업). 순서는
//    1) MCU 가 18ms 이상 Low 로 끌고 놓는다              (START)
//    2) 풀업으로 High 복귀 -> 센서가 80us Low + 80us High (SYNC)
//    3) 비트 40개 : 각 비트는 50us Low 뒤 High 길이로 0/1
//         26~28us High = 0,  약 70us High = 1
//    4) 마지막에 센서가 Low 로 끌었다가 놓는다            (STOP)
//    체크섬 = 습도상위+습도하위+온도상위+온도하위 의 하위 8비트
//
//  테스트벤치가 DHT11 센서 역할을 한다. 시뮬에서는 "1us"=2클럭,
//  1초 최소 측정 간격(SAMPLE_GUARD_US)은 0 으로 꺼서 돌린다.
//
//  [무작위로 만드는 것]
//    1) 40비트 데이터 전부 무작위
//    2) 체크섬을 맞게 넣을지 틀리게 넣을지 무작위
//    3) 비트 High 길이를 규격 안에서 흔든다 (0 은 24~30us, 1 은 65~75us)
//    4) 센서 응답까지의 지연도 흔든다
//
//  [검사]
//    - 습도/온도 16비트가 보낸 값 그대로인가 (비트 순서/한 칸 밀림 검출)
//    - 체크섬이 맞으면 valid=1, 틀리면 valid=0 인가
//    - done 이 프레임당 한 번인가
//    - dbg_step 진행도가 어디까지 찍히는가
//        정상    111111 / 체크섬 실패 011111 / 센서 무응답 000011
//    - 센서가 아예 없을 때 타임아웃으로 빠져나오는가 (안 그러면 영구 hang)
//=====================================================================
module tb_dht11_controller ();

    localparam integer TICK = 2;  // "1us" = 2클럭

    reg  clk = 1'b0;
    reg  reset;
    reg  start;
    wire [15:0] humidity, temperature;
    wire done, valid;
    wire [5:0] dbg_step;

    wire dht11_io;
    reg  tb_low;                       // 테스트벤치(센서)가 선을 끄는 중
    assign dht11_io = tb_low ? 1'b0 : 1'bz;
    pullup (dht11_io);                 // 보드의 4.7k 풀업

    integer seed, seed0;
    integer errors, checks;
    integer i, k, guard, hi_us, dly;
    reg [39:0] frame;
    reg [7:0]  csum;
    reg        want_ok;

    reg        done_seen;
    reg        cap_valid;
    reg [15:0] cap_humi, cap_temp;
    reg [5:0]  cap_dbg;

    always #5 clk = ~clk;

    dht11_controller #(
        .TICK_1US       (TICK),
        .SAMPLE_GUARD_US(0)     // 기능 시뮬이라 1초 보호 대기는 끈다
    ) DUT (
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .humidity   (humidity),
        .temperature(temperature),
        .done       (done),
        .valid      (valid),
        .dbg_step   (dbg_step),
        .dht11_io   (dht11_io)
    );

    task chk(input cond, input [8*30:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  sent=%h got H=%h T=%h valid=%b dbg=%b",
                             $time, tag, frame, cap_humi, cap_temp, cap_valid, cap_dbg);
            end
        end
    endtask

    always @(posedge clk) begin
        if (done) begin
            done_seen = 1'b1;
            cap_valid = valid;
            cap_humi  = humidity;
            cap_temp  = temperature;
            cap_dbg   = dbg_step;
        end
    end

    task wait_us(input integer n);
        begin
            repeat (n * TICK) @(negedge clk);
        end
    endtask

    task kick;
        begin
            @(negedge clk);
            done_seen = 1'b0;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    // DUT 가 START Low 를 잡았다가 놓을 때까지 (약 19ms)
    task wait_start_pulse(output ok);
        begin
            ok    = 1'b1;
            guard = 0;
            while (dht11_io !== 1'b0 && guard < 40_000 * TICK) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (dht11_io !== 1'b0) ok = 1'b0;

            guard = 0;
            while (dht11_io !== 1'b1 && guard < 40_000 * TICK) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (dht11_io !== 1'b1) ok = 1'b0;
        end
    endtask

    // 센서 역할 : 40비트 프레임을 되돌려 준다
    task sensor_reply(input [39:0] d);
        begin
            wait_us(dly);          // 응답까지의 지연 (20~40us)
            tb_low = 1'b1;
            wait_us(80);           // 응답 Low 80us
            tb_low = 1'b0;
            wait_us(80);           // 응답 High 80us

            for (k = 39; k >= 0; k = k - 1) begin
                tb_low = 1'b1;
                wait_us(50);       // 비트 시작 Low 50us
                tb_low = 1'b0;
                if (d[k]) hi_us = 65 + ({$random(seed)} % 11);  // 1 : 65~75us
                else      hi_us = 24 + ({$random(seed)} % 7);   // 0 : 24~30us
                wait_us(hi_us);
            end

            tb_low = 1'b1;
            wait_us(50);           // 마지막 Low
            tb_low = 1'b0;         // 놓으면 풀업으로 High
        end
    endtask

    task run_frame(input [39:0] d);
        reg ok;
        begin
            frame = d;
            kick;
            wait_start_pulse(ok);
            chk(ok === 1'b1, "DUT did not drive the START low");
            sensor_reply(d);

            guard = 0;
            while (done_seen !== 1'b1 && guard < 3000 * TICK) begin
                @(negedge clk);
                guard = guard + 1;
            end
            chk(done_seen === 1'b1, "done never came");

            csum = d[39:32] + d[31:24] + d[23:16] + d[15:8];
            chk(cap_humi === d[39:24], "humidity mismatch");
            chk(cap_temp === d[23:8],  "temperature mismatch");
            chk(cap_valid === (d[7:0] == csum), "valid does not match checksum");
            if (d[7:0] == csum) chk(cap_dbg === 6'b111111, "dbg_step != 111111 on good frame");
            else                chk(cap_dbg === 6'b011111, "dbg_step != 011111 on bad checksum");
            repeat (50) @(negedge clk);
        end
    endtask

    initial begin
        seed0  = 32'h0D47_1100;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset  = 1'b1;
        start  = 1'b0;
        tb_low = 1'b0;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (20) @(negedge clk);

        //---------------- 눈으로 보이는 대표 프레임 (습도 60%, 온도 25C) ----------------
        dly   = 30;
        frame = {8'd60, 8'd0, 8'd25, 8'd0, 8'd85};  // 60+0+25+0 = 85
        run_frame(frame);
        $display("  H=%0d.%0d %%   T=%0d.%0d C   valid=%b",
                 cap_humi[15:8], cap_humi[7:0],
                 cap_temp[15:8], cap_temp[7:0], cap_valid);

        //---------------- 무작위 프레임 ----------------
        for (i = 0; i < 6; i = i + 1) begin
            frame[39:8] = {$random(seed)};
            csum        = frame[39:32] + frame[31:24] + frame[23:16] + frame[15:8];
            want_ok     = (({$random(seed)} % 3) != 0);  // 2/3 확률로 체크섬 정상
            if (want_ok) frame[7:0] = csum;
            else         frame[7:0] = csum ^ (1 + ({$random(seed)} % 255));
            dly = 20 + ({$random(seed)} % 21);
            run_frame(frame);
        end

        //---------------- 센서가 아예 없을 때 ----------------
        //  START 를 놓아도 응답 Low 가 안 오면 200us 만에 빠져나와야 한다.
        //  (타임아웃이 없으면 여기서 영영 갇힌다)
        frame = 40'h0;
        kick;
        guard = 0;
        while (done_seen !== 1'b1 && guard < 40_000 * TICK) begin
            @(negedge clk);
            guard = guard + 1;
        end
        chk(done_seen === 1'b1, "no timeout when sensor is absent");
        chk(cap_valid === 1'b0, "valid set with no sensor");
        chk(cap_dbg === 6'b000011, "dbg_step != 000011 with no sensor");
        $display("  no sensor -> dbg=%b valid=%b", cap_dbg, cap_valid);

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_dht11_controller : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_dht11_controller : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #20_000_000;
        $display("  tb_dht11_controller : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
