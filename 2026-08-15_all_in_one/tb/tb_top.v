`timescale 1ns / 1ps

//=====================================================================
// tb_top  -  통합 top 검증용 테스트벤치
//
//  실보드 값(1초, 100ms, 9600bps ...) 그대로 돌리면 시뮬이 몇 분씩
//  걸리므로, top 의 파라미터를 확 줄여서 인스턴스한다.
//  로직 자체는 동일하고 카운터 상수만 작아진다.
//
//  검사 항목
//   1) UART RX -> ASCII Decoder -> Control Unit -> 스톱워치 run/stop
//   2) ASCII Sender -> TX FIFO -> UART TX 로 나가는 문자열 (콘솔 출력)
//   3) SR04 : trigger 발생 -> echo 응답 -> 거리 계산 -> "DIST xxxcm"
//   4) DHT11 : 1-wire 프레임 수신 -> 체크섬 통과 -> "H xx% T xxC"
//=====================================================================

//=====================================================================
//  ▼ 실행할 항목 고르기
//
//  아래 `define 줄을 주석 처리(//)하면 그 시나리오가 통째로 빠진다.
//  시나리오뿐 아니라 거기 딸린 센서 모델까지 같이 빠져서, 시뮬 시간도
//  그만큼 줄어든다. 네 시나리오는 서로 독립이라 아무거나 꺼도 된다.
//
//  예) DHT11 만 보고 싶으면 위 세 줄을 주석 처리한다.
//        //`define RUN_STOPWATCH
//        //`define RUN_WATCH
//        //`define RUN_SR04
//        `define RUN_DHT11
//=====================================================================
`define RUN_STOPWATCH
`define RUN_WATCH
`define RUN_SR04
`define RUN_DHT11

// UART 로 나가는 문자열을 콘솔에 찍는 모니터. 필요 없으면 주석 처리.
`define SHOW_TX

module tb_top ();

    // ---- 시뮬용 축소 파라미터 ----
    localparam integer P_SYS_CLK      = 100_000_000;
    localparam integer P_BAUD         = 625_000;  // DIV = 100M/(625k*16) = 10
    localparam integer P_BIT_CLKS     = 160;      // 16 * 10
    localparam integer P_DEBOUNCE     = 10;
    localparam integer P_FND_SCAN     = 50;
    localparam integer P_TICK_100HZ   = 200;
    localparam integer P_TICK_1US     = 4;        // "1us" = 4 clk
    localparam integer P_SEND_PERIOD  = 50_000;

    // 실패 개수. 검사에서 실패할 때마다 올리고 맨 끝에 한 줄로 요약한다.
    // (tb/ 폴더의 다른 테스트벤치와 같은 형식으로 맞춘 것)
    integer err = 0;

    reg        clk;
    reg        reset;
    reg  [3:0] sw;
    reg        btn_L, btn_R, btn_U, btn_D;
    reg        rx;
    wire       tx;
    reg        echo;
    wire       trigger;
    wire       dht11_io;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire [7:0] led;

    top #(
        .SYS_CLK     (P_SYS_CLK),
        .BAUD        (P_BAUD),
        .DEBOUNCE_CNT(P_DEBOUNCE),
        .FND_SCAN_CNT(P_FND_SCAN),
        .TICK_100HZ  (P_TICK_100HZ),
        .TICK_1US    (P_TICK_1US),
        .DHT_GUARD_US(0),  // 기능 시뮬레이션에서는 1초 보호 대기 생략
        .SEND_PERIOD (P_SEND_PERIOD)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .sw      (sw),
        .btn_L   (btn_L),
        .btn_R   (btn_R),
        .btn_U   (btn_U),
        .btn_D   (btn_D),
        .rx      (rx),
        .tx      (tx),
        .echo    (echo),
        .trigger (trigger),
        .dht11_io(dht11_io),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data),
        .led     (led)
    );

    //-----------------------------------------------------------------
    // top 내부 신호 별칭
    //   블록으로 묶으면서 top 안쪽으로 한 단계 들어간 신호들이다.
    //   나중에 계층이 또 바뀌면 아래 검사문은 그대로 두고 여기만 고치면 된다.
    //-----------------------------------------------------------------
    wire [6:0] sw_msec = DUT.U_TIME_DATAPATH.sw_msec;
    wire [5:0] sw_sec  = DUT.U_TIME_DATAPATH.sw_sec;
    wire [5:0] sw_min  = DUT.U_TIME_DATAPATH.sw_min;
    wire [4:0] sw_hour = DUT.U_TIME_DATAPATH.sw_hour;

    wire [5:0] wt_sec  = DUT.U_TIME_DATAPATH.wt_sec;
    wire [5:0] wt_min  = DUT.U_TIME_DATAPATH.wt_min;
    wire [4:0] wt_hour = DUT.U_TIME_DATAPATH.wt_hour;

    wire [15:0] humidity_reg    = DUT.U_SENSOR_UNIT.humidity_reg;
    wire [15:0] temperature_reg = DUT.U_SENSOR_UNIT.temperature_reg;
    wire        dht_valid_raw   = DUT.U_SENSOR_UNIT.w_dht_valid;   // 컨트롤러 직출력
    wire        dht_valid_hold  = DUT.U_SENSOR_UNIT.dht_valid_reg; // done 에 래치된 값

    // 100MHz
    always #5 clk = ~clk;

    // "1us" 만큼 대기 (컨트롤러 tick 기준)
    task us_wait(input integer n);
        begin
            repeat (n * P_TICK_1US) @(posedge clk);
        end
    endtask

    // btn_L 을 눌렀다 뗀다. 디바운스 8샘플(= 8*P_DEBOUNCE clk) 이상 유지해야
    // 인정되므로 넉넉히 200클럭 누른다.
    task press_L;
        begin
            btn_L = 1'b1;
            repeat (200) @(posedge clk);
            btn_L = 1'b0;
            repeat (200) @(posedge clk);
        end
    endtask

    //=================================================================
    // UART 송신 태스크 (PC -> FPGA)
    //=================================================================
    task uart_send(input [7:0] d);
        integer i;
        begin
            rx = 1'b0;  // start bit
            repeat (P_BIT_CLKS) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rx = d[i];
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            rx = 1'b1;  // stop bit
            repeat (P_BIT_CLKS) @(posedge clk);
            $display("[%0t] RX->FPGA : '%c'", $time, d);
        end
    endtask

`ifdef SHOW_TX
    //=================================================================
    // UART 수신 모니터 (FPGA -> PC). 받은 문자열을 줄 단위로 찍는다.
    //=================================================================
    integer line_len;
    reg [8*24-1:0] line_buf;

    initial begin : tx_monitor
        reg [7:0] b;
        integer i;
        line_len = 0;
        line_buf = 0;
        forever begin
            @(negedge tx);  // start bit 검출
            // 첫 데이터 비트 중앙으로 이동
            repeat (P_BIT_CLKS + (P_BIT_CLKS / 2)) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx;
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            if (b == 8'h0a) begin  // LF -> 한 줄 완성
                $display("[%0t] TX->PC   : \"%0s\"", $time, line_buf);
                line_buf = 0;
                line_len = 0;
            end else if (b != 8'h0d) begin  // CR 은 버림
                line_buf = (line_buf << 8) | b;
                line_len = line_len + 1;
            end
        end
    end
`endif

`ifdef RUN_SR04
    //=================================================================
    // HC-SR04 동작 모델
    //   trigger 가 끝나면 300us 뒤에 echo 를 (cm * 58)us 만큼 High
    //=================================================================
    integer sr04_cm;
    reg sr04_respond;
    reg sr04_stuck_high;
    time trigger_rise_time;

    always @(posedge trigger) trigger_rise_time = $time;
    always @(negedge trigger) begin
        if (($time - trigger_rise_time) < (10 * P_TICK_1US * 10)) begin
            err = err + 1;
            $display("  ** FAIL : SR04 trigger shorter than 10 us");
            $display("  tb_top : FAIL =====  errors=%0d", err);
            $finish;
        end
    end

    initial begin : sr04_model
        echo    = 1'b0;
        sr04_cm = 30;
        sr04_respond = 1'b1;
        sr04_stuck_high = 1'b0;
        forever begin
            @(posedge trigger);
            @(negedge trigger);
            us_wait(300);
            if (sr04_stuck_high) begin
                echo = 1'b1;
                us_wait(24_000);
                echo = 1'b0;
            end else if (sr04_respond) begin
                echo = 1'b1;
                us_wait(sr04_cm * 58);
                echo = 1'b0;
            end
        end
    end
`endif

    // 버스 풀업은 모델을 꺼도 살려둔다.
    // (안 그러면 dht11_io 가 Z 로 떠서 X 가 번진다)
    pullup (dht11_io);

`ifdef RUN_DHT11
    //=================================================================
    // DHT11 동작 모델
    //   습도 60.0%, 온도 25.0C  -> 체크섬 60+0+25+0 = 85
    //=================================================================
    reg dht_pull_low;
    assign dht11_io = dht_pull_low ? 1'b0 : 1'bz;

    // 구형 RTL은 마지막 비트 뒤 센서가 50us Low를 유지하는 동안 High를
    // 능동 구동해서 여기서 X(버스 충돌)가 발생했다. 매 클럭 확인한다.
    always @(posedge clk) begin
        if (reset === 1'b0 && dht11_io === 1'bx) begin
            err = err + 1;
            $display("  ** FAIL : DHT11 bus contention (X) detected");
            $display("  tb_top : FAIL =====  errors=%0d", err);
            $finish;
        end
    end

    initial begin : dht_model
        reg [39:0] frame;
        integer i;
        dht_pull_low = 1'b0;
        frame = {8'd60, 8'd0, 8'd25, 8'd0, 8'd85};
        forever begin
            @(negedge dht11_io);  // 마스터가 18ms Low 로 당김
            @(posedge dht11_io);  // 놓으면(하이임피던스 + 풀업) 응답 시작
            us_wait(30);
            dht_pull_low = 1'b1;
            us_wait(80);  // 싱크1 : 80us Low
            dht_pull_low = 1'b0;
            us_wait(80);  // 싱크2 : 80us High
            for (i = 39; i >= 0; i = i - 1) begin
                dht_pull_low = 1'b1;
                us_wait(50);  // 비트 시작 50us Low
                dht_pull_low = 1'b0;
                if (frame[i]) us_wait(70);  // 1 : 약 70us High
                else us_wait(27);           // 0 : 약 27us High
            end
            dht_pull_low = 1'b1;
            us_wait(50);  // 종료 Low
            dht_pull_low = 1'b0;
        end
    end
`endif

    //=================================================================
    // 메인 시나리오
    //   네 구간은 서로 독립이다. 맨 위 `define 을 주석 처리하면
    //   해당 구간이 통째로 빠진다.
    //=================================================================
    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        sw    = 4'b0000;
        {btn_L, btn_R, btn_U, btn_D} = 4'b0000;
        rx    = 1'b1;
        echo  = 1'b0;  // SR04 모델을 꺼도 X 가 되지 않도록 여기서 초기화

        repeat (20) @(posedge clk);
        reset = 1'b0;
        repeat (50) @(posedge clk);

`ifdef RUN_STOPWATCH
        //---------------- 1) 스톱워치 ----------------
        $display("\n===== [1] STOPWATCH : sw=0000 (기본 모드), UART 'r' 로 RUN =====");
        sw = 4'b0000;
        repeat (200) @(posedge clk);

        uart_send("r");
        repeat (200) @(posedge clk);
        if (DUT.w_sw_run_stop !== 1'b1) begin
            err = err + 1;
            $display("  ** FAIL : run_stop 이 1 이 아님");
        end else $display("  OK : run_stop = 1 (카운트 시작)");

        repeat (P_SEND_PERIOD + 30000) @(posedge clk);  // 자동 송신 한 번 받기

        uart_send("s");
        repeat (200) @(posedge clk);
        if (DUT.w_sw_run_stop !== 1'b0) begin
            err = err + 1;
            $display("  ** FAIL : stop 이 안 먹음");
        end else $display("  OK : run_stop = 0 (정지)");
        $display("  현재값 %0d:%0d:%0d.%0d",
                 sw_hour, sw_min, sw_sec, sw_msec);
`endif

`ifdef RUN_WATCH
        //---------------- 2) 시계 ----------------
        $display("\n===== [2] WATCH : sw=0010, 'M' 로 분 선택 후 'U' 3번 =====");
        sw = 4'b0010;
        repeat (200) @(posedge clk);
        uart_send("M");
        repeat (200) @(posedge clk);
        if (DUT.w_wt_edit_sel !== 2'd1) begin
            err = err + 1;
            $display("  ** FAIL : edit_sel 이 min(1) 이 아님");
        end else $display("  OK : edit_sel = 1 (min)");

        uart_send("U");
        uart_send("U");
        uart_send("U");
        repeat (200) @(posedge clk);
        $display("  시계값 %0d:%0d:%0d  (min 이 3 이어야 함)",
                 wt_hour, wt_min, wt_sec);
`endif

`ifdef RUN_SR04
        //---------------- 3) SR04 ----------------
        $display("\n===== [3] SR04 : sw=0100, btn_L 로 1회 측정 (30cm 응답) =====");
        sw = 4'b0100;
        repeat (5000) @(posedge clk);
        // 자동측정이 제거됐으므로 버튼 전에는 측정이 나가면 안 된다
        if (DUT.w_distance !== 9'd0) begin
            err = err + 1;
            $display("  ** FAIL : btn_L 없이 측정됨 (자동측정이 남아있음)");
        end else $display("  OK : btn_L 전에는 측정 안 나감");

        press_L;
        repeat (40000) @(posedge clk);
        $display("  distance = %0d cm (30 이어야 함)", DUT.w_distance);
        if (DUT.w_distance !== 9'd30) begin
            err = err + 1;
            $display("  ** FAIL");
        end else $display("  OK");

        // The top-level reset port is physically mapped to BTNC.
        reset = 1'b1;
        repeat (5) @(posedge clk);
        if (DUT.w_distance !== 9'd0 || DUT.w_sr04_valid !== 1'b0) begin
            err = err + 1;
            $display("  ** FAIL : BTNC/global reset did not clear SR04");
        end else
            $display("  OK : BTNC/global reset clears SR04");
        reset = 1'b0;
        repeat (10) @(posedge clk);

        // A stuck-high echo used to be clamped and stored as a valid 400 cm.
        // It must now finish as invalid and clear the displayed distance.
        sr04_stuck_high = 1'b1;
        press_L;
        repeat (105_000) @(posedge clk);
        if (DUT.w_sr04_valid !== 1'b0 || DUT.w_distance !== 9'd0) begin
            err = err + 1;
            $display("  ** FAIL : stuck-high echo was accepted (distance=%0d valid=%0b)",
                     DUT.w_distance, DUT.w_sr04_valid);
        end else
            $display("  OK : stuck-high echo rejected (not displayed as 400 cm)");
        sr04_stuck_high = 1'b0;
        repeat (P_SEND_PERIOD) @(posedge clk);
`endif

`ifdef RUN_DHT11
        //---------------- 4) DHT11 ----------------
        $display("\n===== [4] DHT11 : sw=1000, btn_L 로 1회 측정 (습도60 온도25) =====");
        sw = 4'b1000;
        repeat (5000) @(posedge clk);
        if (humidity_reg[15:8] !== 8'd0) begin
            err = err + 1;
            $display("  ** FAIL : btn_L 없이 측정됨 (자동측정이 남아있음)");
        end else $display("  OK : btn_L 전에는 측정 안 나감");

        press_L;
        repeat (250_000) @(posedge clk);
        $display("  humidity=%0d temperature=%0d valid=%0b",
                 humidity_reg[15:8], temperature_reg[15:8], dht_valid_raw);
        if (dht_valid_raw !== 1'b1) begin
            err = err + 1;
            $display("  ** FAIL : 체크섬 불통과");
        end else if (humidity_reg[15:8] !== 8'd60 ||
                     temperature_reg[15:8] !== 8'd25) begin
            err = err + 1;
            $display("  ** FAIL : 값이 다름");
        end else if (dht11_io !== 1'b1) begin
            err = err + 1;
            $display("  ** FAIL : 프레임 종료 뒤 버스가 High로 복귀하지 않음");
        end else $display("  OK");

        reset = 1'b1;
        repeat (5) @(posedge clk);
        if (humidity_reg !== 16'd0 || temperature_reg !== 16'd0 ||
            dht_valid_hold !== 1'b0) begin
            err = err + 1;
            $display("  ** FAIL : BTNC/global reset did not clear DHT11");
        end else
            $display("  OK : BTNC/global reset clears DHT11");
        reset = 1'b0;
        repeat (10) @(posedge clk);
        repeat (P_SEND_PERIOD + 30000) @(posedge clk);
`endif

        $display("\n=====================================================");
        if (err == 0) $display("  tb_top : ALL PASS");
        else          $display("  tb_top : FAIL =====  errors=%0d", err);
        $display("=====================================================");
        $finish;
    end

endmodule
