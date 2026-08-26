`timescale 1ns / 1ps

//=====================================================================
// tb_uart_tx  -  uart_tx 단독 무작위 테스트벤치
//
//  대상 : uart.v 의 uart_tx
//
//  IDLE 에서 tx_start 를 보면 그 클럭에 tx_data 를 래치하고
//  스타트비트(0) - 데이터 8비트(LSB first) - 스톱비트(1) 를 내보낸다.
//
//  시뮬 시간을 줄이려고 보드레이트를 625kbps 로 올려 쓴다.
//    한 비트 = 16 * DIV(10) = 160클럭
//
//  [무작위로 만드는 것]
//    1) 보내는 바이트 값
//    2) 바이트와 바이트 사이 쉬는 시간
//
//  [검사]  테스트벤치가 시리얼 선을 직접 받아서 되돌린다
//    - 스타트비트가 0 인가
//    - 8비트가 LSB first 로 나오는가 (되돌린 값이 보낸 값과 같은가)
//    - 스톱비트가 1 이고, 끝나면 선이 1(유휴)로 돌아오는가
//    - tx_busy 가 전송 중에만 1 인가
//=====================================================================
module tb_uart_tx ();

    localparam integer BAUD     = 625_000;
    localparam integer DIV      = 100_000_000 / (BAUD * 16);  // 10
    localparam integer BIT_CLKS = 16 * DIV;                   // 160
    localparam integer N_BYTE   = 40;

    reg        clk = 1'b0;
    reg        reset;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       baud_tick;
    wire       tx_busy, tx_done, tx;

    integer seed, seed0;
    integer errors, checks;
    integer i, k, gapn;
    reg [7:0] sent, got;

    always #5 clk = ~clk;

    baud_tick_gen #(
        .SYS_CLK(100_000_000),
        .BAUD   (BAUD)
    ) U_BAUD (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(baud_tick)
    );

    uart_tx DUT (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(baud_tick),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx         (tx)
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

    initial begin
        seed0  = 32'h7A00_1234;
        seed   = seed0;
        errors = 0;
        checks = 0;

        reset    = 1'b1;
        tx_start = 1'b0;
        tx_data  = 8'h00;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(negedge clk);

        chk(tx === 1'b1,      "tx is not idle-high after reset");
        chk(tx_busy === 1'b0, "tx_busy set while idle");

        for (i = 0; i < N_BYTE; i = i + 1) begin
            sent = {$random(seed)} % 256;

            // tx_start 를 1클럭만 준다. 그 posedge 에 START 상태로 들어가고,
            // tx 는 그 다음 클럭에 0 으로 떨어진다 (IDLE 에서는 tx_next=1).
            @(negedge clk);
            tx_data  = sent;
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;
            tx_data  = 8'hFF;  // 래치했는지 보려고 곧바로 값을 흐트러뜨린다
            chk(tx_busy === 1'b1, "tx_busy not set while sending");

            @(negedge clk);    // 여기서는 스타트비트가 선에 나와 있어야 한다
            chk(tx === 1'b0, "start bit is not low");

            // 스타트비트 남은 구간 + 반 비트 = 첫 데이터비트 한가운데
            repeat (BIT_CLKS + BIT_CLKS / 2) @(negedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                got[k] = tx;
                repeat (BIT_CLKS) @(negedge clk);
            end
            chk(tx === 1'b1, "stop bit is not high");
            chk(got === sent, "transmitted byte mismatch");

            // 스톱비트가 끝나 IDLE 로 돌아올 때까지
            repeat (BIT_CLKS) @(negedge clk);
            chk(tx === 1'b1,      "line not idle-high after byte");
            chk(tx_busy === 1'b0, "tx_busy stuck after byte");

            gapn = 5 + ({$random(seed)} % 200);
            repeat (gapn) @(negedge clk);
        end

        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_uart_tx : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_uart_tx : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #10_000_000;
        $display("  tb_uart_tx : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
