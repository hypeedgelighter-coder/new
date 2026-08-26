`timescale 1ns / 1ps

//=====================================================================
// tb_uart_fifo  -  uart_fifo 단독 무작위 테스트벤치
//
//  대상 : uart_fifo.v  (baud_tick_gen + uart_rx + uart_tx + FIFO 2개)
//
//   PC --TX--> [uart_rx] --> [RX FIFO] --> rx_data/rx_empty/rx_pop
//   PC <--RX-- [uart_tx] <-- [TX FIFO] <-- tx_data/tx_push/tx_full
//
//  시뮬 시간을 줄이려고 625kbps 로 올려 쓴다 (한 비트 = 160클럭).
//
//  [무작위로 만드는 것]
//    1) 주고받는 바이트 값 전부
//    2) 한 묶음에 몇 바이트를 연달아 보낼지
//    3) pop 을 언제 할지 (바로 빼기도 하고 한참 쌓아 두기도 한다)
//    4) TX 쪽은 FIFO 깊이(16)보다 많이 밀어넣어 backpressure 를 만든다
//
//  [검사]
//    - RX : 보낸 순서 그대로 rx_data 로 나오는가 (유실/뒤바뀜 없이)
//    - RX : 비었을 때 rx_empty=1 인가
//    - TX : tx_full 을 지켜 밀어넣으면 한 바이트도 안 잃는가
//    - TX : 시리얼 선에 나온 순서가 밀어넣은 순서와 같은가
//=====================================================================
module tb_uart_fifo ();

    localparam integer BAUD     = 625_000;
    localparam integer DIV      = 100_000_000 / (BAUD * 16);  // 10
    localparam integer BIT_CLKS = 16 * DIV;                   // 160
    localparam integer AWIDTH   = 3;
    localparam integer DEPTH    = 1 << AWIDTH;

    localparam integer N_RX_BURST = 6;   // RX 묶음 횟수
    localparam integer N_TX_BYTE  = 25;  // TX 로 밀어넣을 바이트 수 (깊이 초과)

    reg        clk = 1'b0;
    reg        reset;
    reg        rx;
    wire       tx;
    wire [7:0] rx_data;
    wire       rx_empty;
    reg        rx_pop;
    reg  [7:0] tx_data;
    reg        tx_push;
    wire       tx_full;

    integer seed, seed0;
    integer errors, checks;
    integer i, j, nburst;

    reg [7:0] sent_q[0:63];   // RX 로 보낸 것
    reg [7:0] got_q [0:63];   // RX 로 받은 것
    integer   n_sent, n_got;

    reg [7:0] tx_src[0:63];   // TX 로 밀어넣은 것
    reg [7:0] tx_log[0:63];   // 시리얼 선에서 되돌린 것
    integer   n_txsrc, n_txlog;

    reg     tx_mon_on;
    integer k2;
    reg [7:0] b2;

    always #5 clk = ~clk;

    uart_fifo #(
        .SYS_CLK(100_000_000),
        .BAUD   (BAUD),
        .AWIDTH (AWIDTH)
    ) DUT (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .tx      (tx),
        .rx_data (rx_data),
        .rx_empty(rx_empty),
        .rx_pop  (rx_pop),
        .tx_data (tx_data),
        .tx_push (tx_push),
        .tx_full (tx_full)
    );

    task chk(input cond, input [8*28:1] tag);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL [%0t] %0s", $time, tag);
            end
        end
    endtask

    //-----------------------------------------------------------------
    //  TX 선을 계속 지켜보다가 바이트를 되돌려 기록한다
    //-----------------------------------------------------------------
    initial begin : tx_monitor
        n_txlog = 0;
        forever begin
            @(negedge tx);                                    // 스타트비트
            repeat (BIT_CLKS + BIT_CLKS / 2) @(negedge clk);  // 첫 비트 한가운데
            for (k2 = 0; k2 < 8; k2 = k2 + 1) begin
                b2[k2] = tx;
                if (k2 < 7) repeat (BIT_CLKS) @(negedge clk);
            end
            if (tx_mon_on) begin
                tx_log[n_txlog] = b2;
                n_txlog = n_txlog + 1;
            end
        end
    end

    // 한 바이트를 시리얼로 밀어 넣는다
    task send_serial(input [7:0] b);
        integer k;
        begin
            rx = 1'b0;
            repeat (BIT_CLKS) @(negedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                rx = b[k];
                repeat (BIT_CLKS) @(negedge clk);
            end
            rx = 1'b1;
            repeat (BIT_CLKS) @(negedge clk);
        end
    endtask

    // FIFO 가 빌 때까지 꺼내서 got_q 에 기록
    task drain_rx;
        integer guard;
        begin
            guard = 0;
            while (rx_empty !== 1'b1 && guard < 200) begin
                got_q[n_got] = rx_data;
                n_got        = n_got + 1;
                rx_pop       = 1'b1;
                @(negedge clk);
                rx_pop = 1'b0;
                @(negedge clk);
                guard = guard + 1;
            end
        end
    endtask

    initial begin
        seed0  = 32'h0F1F_0ABC;
        seed   = seed0;
        errors = 0;
        checks = 0;
        n_sent = 0; n_got = 0;
        n_txsrc = 0;
        tx_mon_on = 1'b0;

        reset   = 1'b1;
        rx      = 1'b1;
        rx_pop  = 1'b0;
        tx_push = 1'b0;
        tx_data = 8'h00;
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(negedge clk);

        chk(rx_empty === 1'b1, "rx_empty is not 1 after reset");
        chk(tx_full  === 1'b0, "tx_full is set after reset");

        //=============== RX : 무작위 묶음으로 보내고 꺼내기 ===============
        for (i = 0; i < N_RX_BURST; i = i + 1) begin
            nburst = 1 + ({$random(seed)} % DEPTH);  // 한 번에 1~DEPTH 바이트
            // 안 꺼낸 채 다음 묶음이 오면 쌓인다. 깊이를 넘으면 FIFO 가
            // push 를 흘리므로(정상 동작), 넘칠 것 같으면 먼저 비운다.
            if ((n_sent - n_got) + nburst > DEPTH) drain_rx;
            for (j = 0; j < nburst; j = j + 1) begin
                sent_q[n_sent] = {$random(seed)} % 256;
                send_serial(sent_q[n_sent]);
                n_sent = n_sent + 1;
                repeat ({$random(seed)} % 100) @(negedge clk);
            end
            // 절반의 확률로 바로 꺼내고, 아니면 다음 묶음까지 쌓아 둔다
            if (({$random(seed)} % 2) == 0) drain_rx;
        end
        repeat (20) @(negedge clk);
        drain_rx;

        chk(n_got == n_sent, "RX byte count mismatch");
        for (i = 0; i < n_got && i < n_sent; i = i + 1)
            chk(got_q[i] === sent_q[i], "RX byte order/value mismatch");
        chk(rx_empty === 1'b1, "rx_empty is not 1 after draining");

        //=============== TX : 깊이보다 많이 밀어넣기 ===============
        tx_mon_on = 1'b1;
        for (i = 0; i < N_TX_BYTE; i = i + 1) tx_src[i] = {$random(seed)} % 256;

        i = 0;
        while (i < N_TX_BYTE) begin
            @(negedge clk);
            if (tx_full !== 1'b1) begin
                tx_data = tx_src[i];
                tx_push = 1'b1;
                i       = i + 1;
            end else begin
                tx_push = 1'b0;  // full 이면 기다린다 (backpressure)
            end
        end
        @(negedge clk);
        tx_push = 1'b0;

        // 다 나갈 때까지 기다린다 (한 바이트 약 1600클럭)
        j = 0;
        while (n_txlog < N_TX_BYTE && j < N_TX_BYTE * 2000) begin
            @(negedge clk);
            j = j + 1;
        end
        repeat (2 * BIT_CLKS) @(negedge clk);

        chk(n_txlog == N_TX_BYTE, "TX byte count mismatch");
        for (i = 0; i < N_TX_BYTE && i < n_txlog; i = i + 1)
            chk(tx_log[i] === tx_src[i], "TX byte order/value mismatch");

        $display("  RX %0d bytes, TX %0d bytes", n_got, n_txlog);
        report;
    end

    task report;
        begin
            $display("=====================================================");
            if (errors == 0)
                $display("  tb_uart_fifo : ALL PASS  (checks=%0d, seed=%0d)",
                         checks, seed0);
            else
                $display("  tb_uart_fifo : FAIL =====  errors=%0d / checks=%0d",
                         errors, checks);
            $display("=====================================================");
            $finish;
        end
    endtask

    initial begin
        #40_000_000;
        $display("  tb_uart_fifo : FAIL =====  TIMEOUT");
        $finish;
    end

endmodule
