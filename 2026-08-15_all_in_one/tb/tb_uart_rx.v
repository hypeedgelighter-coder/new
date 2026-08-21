`timescale 1ns / 1ps

//=====================================================================
// tb_uart_rx  -  uart_rx 단독 무작위 테스트벤치
//
//  대상 : uart.v 의 uart_rx
//
//  16배 오버샘플 수신기. 스타트비트 한가운데(8틱)에서 한 번 더 확인해서
//  노이즈면 IDLE 로 돌아간다. 데이터는 LSB first.
//
//  시뮬 시간을 줄이려고 보드레이트를 625kbps 로 올려 쓴다.
//    DIV = 100M/(625k*16) = 10  ->  한 비트 = 160클럭
//
//  [무작위로 만드는 것]
//    1) 보내는 바이트 값 (0~255 무작위)
//    2) 바이트 사이 유휴 구간 길이 (무작위)
//    3) 유휴 구간에 끼워 넣는 짧은 글리치 (5~60클럭, 무작위)
//       -> 스타트비트 중앙 재확인이 제대로 걸러내는지 본다
//
//  [검사]
//    - 보낸 바이트가 그대로 rx_data 로 나오는가 (비트 순서 포함)
//    - rx_done 이 바이트당 정확히 한 번인가
//    - 글리치로는 rx_done 이 뜨지 않는가
//=====================================================================
module tb_uart_rx ();

    localparam integer BAUD     = 625_000;
    localparam integer DIV      = 100_000_000 / (BAUD * 16);  // 10
    localparam integer BIT_CLKS = 16 * DIV;                   // 160
    localparam integer N_BYTE   = 40;

    reg        clk = 1'b0;
    reg        reset;
    reg        rx;
    wire       baud_tick;
    wire [7:0] rx_data;
    wire       rx_done;

    integer seed, seed0;
    integer errors, checks;
    integer i, idle, gw;
    reg [7:0] sent, got;
    integer   n_done;

    always #5 clk = ~clk;

    baud_tick_gen #(
        .SYS_CLK(100_000_000),
        .BAUD   (BAUD)
    ) U_BAUD (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(baud_tick)
    );

    uart_rx DUT (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .i_baud_tick(baud_tick),
        .rx_data    (rx_data),
        .rx_done    (rx_done)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  FAIL [%0t] %0s  sent=%h got=%h",
                             $time, tag, sent, got);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rx_done) begin
            got    = rx_data;
            n_done = n_done + 1;
        end
    end

    // 한 바이트를 시리얼로 보낸다 (8N1, LSB first)
    task send_byte(input [7:0] b);
        integer k;
        begin
            rx = 1'b0;                                 // 스타트비트
            repeat (BIT_CLKS) @(negedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rx = b[k];
                repeat (BIT_CLKS) @(negedge clk);
            end
            rx = 1'b1;                                 // 스톱비트
            repeat (BIT_CLKS) @(negedge clk);
        end
    endtask

    initial begin
        seed0  = 32'h0A27_5A11;
        seed   = seed0;
        errors = 0;
        checks = 0;
        n_done = 0;

        reset = 1'b1;
        rx    = 1'b1;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(negedge clk);

        //---------------- 무작위 바이트 보내기 ----------------
        for (i = 0; i < N_BYTE; i = i + 1) begin
            sent   = {$random(seed)} % 256;
            n_done = 0;
            send_byte(sent);
            repeat (20) @(negedge clk);
            chk(n_done == 1,     "rx_done count != 1");
            chk(got === sent,    "received byte mismatch");

            idle = 10 + ({$random(seed)} % 300);  // 무작위 유휴
            repeat (idle) @(negedge clk);
        end

        //---------------- 글리치는 무시되어야 한다 ----------------
        for (i = 0; i < 15; i = i + 1) begin
            n_done = 0;
            gw     = 5 + ({$random(seed)} % 56);  // 5~60클럭 (반 비트 미만)
            rx     = 1'b0;
            repeat (gw) @(negedge clk);
            rx = 1'b1;
            repeat (3 * BIT_CLKS) @(negedge clk);
            chk(n_done == 0, "glitch was accepted as a byte");
        end

        //---------------- 글리치 직후에도 정상 수신되는가 ----------------
        for (i = 0; i < 5; i = i + 1) begin
            rx = 1'b0;
            repeat (20) @(negedge clk);
            rx = 1'b1;
            repeat (2 * BIT_CLKS) @(negedge clk);

            sent   = {$random(seed)} % 256;
            n_done = 0;
            send_byte(sent);
            repeat (20) @(negedge clk);
            chk(n_done == 1,  "no byte after a glitch");
            chk(got === sent, "byte after glitch mismatch");
            repeat (50) @(negedge clk);
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_uart_rx : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_uart_rx : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #10_000_000;
        $display("  tb_uart_rx : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
