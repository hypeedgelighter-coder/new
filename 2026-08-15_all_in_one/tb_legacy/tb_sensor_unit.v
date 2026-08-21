`timescale 1ns / 1ps

//=====================================================================
// tb_sensor_unit  -  SR04 + DHT11 묶음 검증
//
//  센서 동작 모델(HC-SR04 에코 응답, DHT11 1-wire 프레임)을 테스트벤치가
//  들고 있다. 시뮬용으로 "1us" 를 4클럭으로 줄였다.
//
//  검사 항목
//   1) start 전에는 측정이 나가지 않는다
//   2) SR04 : trigger -> echo 응답 -> 거리 계산 (30cm, 100cm)
//   3) SR04 : echo 가 계속 High 로 붙어 있으면 invalid (400cm 로 안 찍힘)
//   4) DHT11 : 체크섬 통과 -> 습도/온도 래치, valid=1
//   5) DHT11 : 체크섬 실패 -> 값이 0 으로 지워지고 valid=0
//=====================================================================
module tb_sensor_unit ();

    localparam integer P_TICK_1US = 4;  // "1us" = 4클럭

    reg clk, reset;
    reg sr04_start, dht_start;
    reg echo;
    wire trigger;
    wire [8:0] distance;
    wire sr04_done, sr04_valid;
    wire dht11_io;
    wire [7:0] humidity, temperature;
    wire dht_done, dht_valid;
    wire [5:0] dht_dbg_step;

    integer err;

    sensor_unit #(
        .TICK_1US       (P_TICK_1US),
        .SAMPLE_GUARD_US(0)          // 기능 시뮬에서는 1초 보호 대기 생략
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

    always #5 clk = ~clk;

    task ok(input cond);
        begin
            if (cond) $write("  OK   : ");
            else begin
                $write("  FAIL : ");
                err = err + 1;
            end
        end
    endtask

    task us_wait(input integer n);
        begin
            repeat (n * P_TICK_1US) @(posedge clk);
        end
    endtask

    // 1클럭 폭 펄스. 자극은 항상 "엣지 + 1ns" 에 준다. 엣지와 같은 시각에
    // 값을 바꾸면 DUT 가 그 엣지에서 볼지 다음 엣지에서 볼지가 시뮬레이터
    // 실행 순서에 달려서, 한 번 준 펄스가 두 번 먹기도 한다.
    task pulse_sr04_start;
        begin
            @(posedge clk);
            #1;
            sr04_start = 1'b1;
            @(posedge clk);
            #1;
            sr04_start = 1'b0;
        end
    endtask

    task pulse_dht_start;
        begin
            @(posedge clk);
            #1;
            dht_start = 1'b1;
            @(posedge clk);
            #1;
            dht_start = 1'b0;
        end
    endtask

    // done 이 뜰 때까지 기다린다 (안 오면 타임아웃 보고)
    task wait_sr04_done(input integer max_clk);
        integer k;
        begin
            k = 0;
            while (!sr04_done && k < max_clk) begin
                @(posedge clk);
                k = k + 1;
            end
            if (k >= max_clk) begin
                $display("  FAIL : sr04_done 타임아웃");
                err = err + 1;
            end
            repeat (3) @(posedge clk);  // 래치 반영 대기
        end
    endtask

    task wait_dht_done(input integer max_clk);
        integer k;
        begin
            k = 0;
            while (!dht_done && k < max_clk) begin
                @(posedge clk);
                k = k + 1;
            end
            if (k >= max_clk) begin
                $display("  FAIL : dht_done 타임아웃");
                err = err + 1;
            end
            repeat (3) @(posedge clk);  // 래치 반영 대기
        end
    endtask

    //=================================================================
    // HC-SR04 동작 모델
    //   trigger 가 끝나면 300us 뒤에 echo 를 (cm * 58)us 만큼 High
    //=================================================================
    integer sr04_cm;
    reg sr04_stuck_high;

    initial begin : sr04_model
        echo            = 1'b0;
        sr04_cm         = 30;
        sr04_stuck_high = 1'b0;
        forever begin
            @(posedge trigger);
            @(negedge trigger);
            us_wait(300);
            if (sr04_stuck_high) begin
                echo = 1'b1;
                us_wait(24_000);
                echo = 1'b0;
            end else begin
                echo = 1'b1;
                us_wait(sr04_cm * 58);
                echo = 1'b0;
            end
        end
    end

    //=================================================================
    // DHT11 동작 모델
    //   습도 60.0%, 온도 25.0C -> 체크섬 60+0+25+0 = 85
    //   dht_bad = 1 이면 체크섬을 일부러 틀리게 보낸다.
    //=================================================================
    reg dht_pull_low;
    reg dht_bad;
    assign dht11_io = dht_pull_low ? 1'b0 : 1'bz;
    pullup (dht11_io);

    initial begin : dht_model
        reg [39:0] frame;
        integer i;
        dht_pull_low = 1'b0;
        dht_bad      = 1'b0;
        forever begin
            @(negedge dht11_io);  // 마스터가 18ms Low 로 당김
            @(posedge dht11_io);  // 놓으면 응답 시작
            frame = dht_bad ? {8'd60, 8'd0, 8'd25, 8'd0, 8'd99}   // 틀린 체크섬
                            : {8'd60, 8'd0, 8'd25, 8'd0, 8'd85};  // 정상
            us_wait(30);
            dht_pull_low = 1'b1;
            us_wait(80);  // 싱크1 : 80us Low
            dht_pull_low = 1'b0;
            us_wait(80);  // 싱크2 : 80us High
            for (i = 39; i >= 0; i = i - 1) begin
                dht_pull_low = 1'b1;
                us_wait(50);
                dht_pull_low = 1'b0;
                if (frame[i]) us_wait(70);
                else us_wait(27);
            end
            dht_pull_low = 1'b1;
            us_wait(50);
            dht_pull_low = 1'b0;
        end
    end

    //=================================================================
    // 시나리오
    //=================================================================
    initial begin
        clk        = 1'b0;
        reset      = 1'b1;
        sr04_start = 1'b0;
        dht_start  = 1'b0;
        err        = 0;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (50) @(posedge clk);

        $display("\n===== tb_sensor_unit =====");

        //---------------- 1) 자동 측정이 없는지 ----------------
        $display("\n[1] start 전에는 측정이 나가지 않는가");
        repeat (5000) @(posedge clk);
        ok(distance === 9'd0); $display("SR04 거리 0 유지");
        ok(humidity === 8'd0 && temperature === 8'd0); $display("DHT11 값 0 유지");

        //---------------- 2) SR04 정상 측정 ----------------
        $display("\n[2] SR04 : 30cm 측정");
        sr04_cm = 30;
        pulse_sr04_start;
        wait_sr04_done(200_000);
        ok(distance === 9'd30); $display("distance = 30cm");
        ok(sr04_valid === 1'b1); $display("valid = 1");

        $display("\n[3] SR04 : 100cm 재측정");
        sr04_cm = 100;
        pulse_sr04_start;
        wait_sr04_done(200_000);
        ok(distance === 9'd100); $display("distance = 100cm");
        ok(sr04_valid === 1'b1); $display("valid = 1");

        //---------------- 4) SR04 비정상 에코 ----------------
        $display("\n[4] SR04 : echo 가 High 로 붙어 있으면");
        sr04_stuck_high = 1'b1;
        pulse_sr04_start;
        wait_sr04_done(500_000);
        ok(sr04_valid === 1'b0); $display("valid = 0 (측정 실패로 처리)");
        ok(distance === 9'd0); $display("distance = 0 (400cm 로 찍히지 않음)");
        sr04_stuck_high = 1'b0;

        //---------------- 5) DHT11 정상 ----------------
        $display("\n[5] DHT11 : 체크섬 통과 프레임");
        dht_bad = 1'b0;
        pulse_dht_start;
        wait_dht_done(2_000_000);
        ok(dht_valid === 1'b1); $display("체크섬 통과 -> valid = 1");
        ok(humidity === 8'd60); $display("습도 60%%");
        ok(temperature === 8'd25); $display("온도 25C");
        ok(dht_dbg_step === 6'b111111); $display("진단 단계 전부 통과");

        //---------------- 6) DHT11 체크섬 실패 ----------------
        $display("\n[6] DHT11 : 체크섬 틀린 프레임");
        dht_bad = 1'b1;
        pulse_dht_start;
        wait_dht_done(2_000_000);
        ok(dht_valid === 1'b0); $display("체크섬 실패 -> valid = 0");
        ok(humidity === 8'd0 && temperature === 8'd0); $display("깨진 값이 남지 않고 0 으로 지워짐");

        if (err == 0) $display("\n===== tb_sensor_unit : ALL PASS =====\n");
        else $display("\n===== tb_sensor_unit : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
