`timescale 1ns / 1ps

//=====================================================================
// tb_uart_comm  -  UART 통신 블록 전체 검증
//   (uart_fifo + ascii_decoder + ascii_sender + 송신 타이밍)
//
//  PC 쪽 역할을 테스트벤치가 한다. 문자를 보내면 명령 펄스가 나오는지,
//  값을 넣으면 약속된 문자열이 나오는지 본다.
//
//  검사 항목
//   1) 수신 : 문자 -> 해당 명령 펄스 1회 (다른 명령은 안 나감)
//   2) 수신 : 매핑 안 된 문자(개행 등)는 버려진다
//   3) 송신 : 센서 측정 완료(done)에 맞춰 문자열이 나간다
//              SR04  "DIST 123cm"
//              DHT11 "H 60% T 25C"
//   4) 송신 : 아무 일 없어도 주기적으로 현재 시간이 나간다
//              "01:02:03.45"
//=====================================================================
module tb_uart_comm ();

    localparam integer P_SYS_CLK  = 100_000_000;
    localparam integer P_BAUD     = 625_000;
    localparam integer P_BIT_CLKS = 160;      // 16 * DIV(10)
    localparam integer P_SEND_PER = 600_000;  // 자동 송신 주기

    reg clk, reset;
    reg rx;
    wire tx;

    wire cmd_run, cmd_stop, cmd_clear, cmd_mode;
    wire cmd_up, cmd_down, cmd_left, cmd_right;
    wire cmd_sel_s, cmd_sel_m, cmd_sel_h, cmd_start;

    reg [1:0] mode_sel;
    reg [6:0] msec;
    reg [5:0] sec, min;
    reg [4:0] hour;
    reg [8:0] distance;
    reg [7:0] humidity, temperature;
    reg sr04_done, dht_done;

    integer err;
    integer s0;

    uart_comm #(
        .SYS_CLK    (P_SYS_CLK),
        .BAUD       (P_BAUD),
        .SEND_PERIOD(P_SEND_PER)
    ) DUT (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .tx         (tx),
        .cmd_run    (cmd_run),
        .cmd_stop   (cmd_stop),
        .cmd_clear  (cmd_clear),
        .cmd_mode   (cmd_mode),
        .cmd_up     (cmd_up),
        .cmd_down   (cmd_down),
        .cmd_left   (cmd_left),
        .cmd_right  (cmd_right),
        .cmd_sel_s  (cmd_sel_s),
        .cmd_sel_m  (cmd_sel_m),
        .cmd_sel_h  (cmd_sel_h),
        .cmd_start  (cmd_start),
        .mode_sel   (mode_sel),
        .msec       (msec),
        .sec        (sec),
        .min        (min),
        .hour       (hour),
        .distance   (distance),
        .humidity   (humidity),
        .temperature(temperature),
        .sr04_done  (sr04_done),
        .dht_done   (dht_done)
    );

    always #5 clk = ~clk;

    //---------------- 명령 펄스 개수 세기 ----------------
    integer n_run, n_sel_m, n_start, n_any;

    always @(posedge clk) begin
        if (cmd_run)   n_run   = n_run + 1;
        if (cmd_sel_m) n_sel_m = n_sel_m + 1;
        if (cmd_start) n_start = n_start + 1;
        if (cmd_run | cmd_stop | cmd_clear | cmd_mode |
            cmd_up | cmd_down | cmd_left | cmd_right |
            cmd_sel_s | cmd_sel_m | cmd_sel_h | cmd_start)
            n_any = n_any + 1;
    end

    task clr_cnt;
        begin
            n_run = 0; n_sel_m = 0; n_start = 0; n_any = 0;
        end
    endtask

    task ok(input cond);
        begin
            if (cond) $write("  OK   : ");
            else begin
                $write("  FAIL : ");
                err = err + 1;
            end
        end
    endtask

    //---------------- PC -> FPGA ----------------
    task uart_send(input [7:0] d);
        integer i;
        begin
            rx = 1'b0;
            repeat (P_BIT_CLKS) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rx = d[i];
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            rx = 1'b1;
            repeat (P_BIT_CLKS) @(posedge clk);
            repeat (200) @(posedge clk);  // 디코더가 처리할 시간
        end
    endtask

    //---------------- FPGA -> PC : 한 줄씩 모으기 ----------------
    reg [8*16-1:0] line_buf, last_line;
    integer line_seq;

    initial begin : tx_monitor
        reg [7:0] b;
        integer i;
        line_buf = 0;
        last_line = 0;
        line_seq = 0;
        forever begin
            @(negedge tx);
            repeat (P_BIT_CLKS + (P_BIT_CLKS / 2)) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx;
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            if (b == 8'h0a) begin        // LF -> 한 줄 끝
                last_line = line_buf;
                line_buf  = 0;
                line_seq  = line_seq + 1;
            end else if (b != 8'h0d) begin  // CR 은 버림
                line_buf = (line_buf << 8) | b;
            end
        end
    end

    // 다음 한 줄이 올 때까지 기다린다
    task wait_line(input integer max_clk);
        integer k, s;
        begin
            s = line_seq;
            k = 0;
            while (line_seq == s && k < max_clk) begin
                @(posedge clk);
                k = k + 1;
            end
            if (line_seq == s) begin
                $display("  FAIL : 문자열 송신 타임아웃");
                err = err + 1;
            end
        end
    endtask

    // 1클럭 폭 펄스. 자극은 항상 "엣지 + 1ns" 에 준다. 엣지와 같은 시각에
    // 값을 바꾸면 DUT 가 그 엣지에서 볼지 다음 엣지에서 볼지가 시뮬레이터
    // 실행 순서에 달려서, 한 번 준 펄스가 두 번 먹기도 한다.
    task pulse_sr04_done;
        begin
            @(posedge clk);
            #1;
            sr04_done = 1'b1;
            @(posedge clk);
            #1;
            sr04_done = 1'b0;
        end
    endtask

    task pulse_dht_done;
        begin
            @(posedge clk);
            #1;
            dht_done = 1'b1;
            @(posedge clk);
            #1;
            dht_done = 1'b0;
        end
    endtask

    //=================================================================
    // 시나리오
    //=================================================================
    initial begin
        clk         = 1'b0;
        reset       = 1'b1;
        rx          = 1'b1;
        mode_sel    = 2'd0;
        msec        = 7'd45;
        sec         = 6'd3;
        min         = 6'd2;
        hour        = 5'd1;
        distance    = 9'd123;
        humidity    = 8'd60;
        temperature = 8'd25;
        sr04_done   = 1'b0;
        dht_done    = 1'b0;
        err         = 0;
        clr_cnt;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);
        clr_cnt;

        $display("\n===== tb_uart_comm =====");

        //---------------- 1) 수신 명령 ----------------
        $display("\n[1] 수신 : 문자 -> 명령 펄스");
        clr_cnt;
        uart_send("r");
        ok(n_run === 1); $display("'r' -> cmd_run 펄스 1회");
        ok(n_any === 1); $display("다른 명령은 같이 나가지 않음");

        clr_cnt;
        uart_send("M");
        ok(n_sel_m === 1 && n_any === 1); $display("'M' -> cmd_sel_m 펄스 1회");

        clr_cnt;
        uart_send("t");
        ok(n_start === 1 && n_any === 1); $display("'t' -> cmd_start 펄스 1회");

        $display("\n[2] 수신 : 매핑 안 된 문자는 버린다");
        clr_cnt;
        uart_send(8'h0a);  // LF
        uart_send("Z");
        ok(n_any === 0); $display("개행/미정의 문자로는 아무 명령도 안 나감");

        //---------------- 3) 센서 완료 송신 ----------------
        $display("\n[3] 송신 : SR04 측정 완료 -> \"DIST 123cm\"");
        mode_sel = 2'd2;
        distance = 9'd123;
        repeat (10) @(posedge clk);
        pulse_sr04_done;
        wait_line(100_000);  // 주기 송신(600k)보다 훨씬 빨리 나와야 한다
        ok(last_line === "DIST 123cm"); $display("SR04 문자열 일치");
        if (last_line !== "DIST 123cm")
            $display("         받은 문자열 = \"%0s\"", last_line);

        $display("\n[4] 송신 : DHT11 측정 완료 -> \"H 60%% T 25C\"");
        mode_sel    = 2'd3;
        humidity    = 8'd60;
        temperature = 8'd25;
        repeat (10) @(posedge clk);
        pulse_dht_done;
        wait_line(100_000);
        ok(last_line === "H 60% T 25C"); $display("DHT11 문자열 일치");
        if (last_line !== "H 60% T 25C")
            $display("         받은 문자열 = \"%0s\"", last_line);

        $display("\n[5] 송신 : 다른 모드의 done 은 무시한다");
        mode_sel = 2'd2;  // SR04 모드인데 DHT done 을 준다
        repeat (10) @(posedge clk);
        s0 = line_seq;
        pulse_dht_done;
        repeat (60_000) @(posedge clk);
        ok(line_seq === s0); $display("SR04 모드에서 DHT done 은 송신을 유발하지 않음");

        //---------------- 6) 주기 송신 ----------------
        $display("\n[6] 송신 : 주기적으로 현재 시간 (\"01:02:03.45\")");
        mode_sel = 2'd0;
        hour     = 5'd1;
        min      = 6'd2;
        sec      = 6'd3;
        msec     = 7'd45;
        repeat (10) @(posedge clk);
        wait_line(P_SEND_PER + 100_000);  // 다음 주기 tick 을 기다린다
        ok(last_line === "01:02:03.45"); $display("시간 문자열 일치");
        if (last_line !== "01:02:03.45")
            $display("         받은 문자열 = \"%0s\"", last_line);

        if (err == 0) $display("\n===== tb_uart_comm : ALL PASS =====\n");
        else $display("\n===== tb_uart_comm : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
