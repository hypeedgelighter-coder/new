`timescale 1ns / 1ps

//=====================================================================
// tb_uart_fifo  -  UART + FIFO 블록 검증
//
//  시뮬 시간을 줄이려고 보드레이트를 625kbps 로 올려 쓴다.
//  (DIV = 100M/(625k*16) = 10, 한 비트 = 160클럭)
//
//  검사 항목
//   1) 수신 : 시리얼 1바이트 -> RX FIFO -> rx_data/rx_empty/rx_pop
//   2) 수신 : 연속 3바이트가 순서대로 쌓이는가
//   3) 송신 : TX FIFO 에 push -> 시리얼로 나가는가
//   4) 송신 : FIFO 깊이(16)를 넘겨 20바이트를 밀어넣어도
//             tx_full 백프레셔를 지키면 한 바이트도 안 잃는가
//=====================================================================
module tb_uart_fifo ();

    localparam integer P_SYS_CLK  = 100_000_000;
    localparam integer P_BAUD     = 625_000;
    localparam integer P_BIT_CLKS = 160;  // 16 * DIV(10)

    reg clk, reset;
    reg rx;
    wire tx;
    wire [7:0] rx_data;
    wire rx_empty;
    reg  rx_pop;
    reg  [7:0] tx_data;
    reg  tx_push;
    wire tx_full;

    integer err;

    uart_fifo #(
        .SYS_CLK(P_SYS_CLK),
        .BAUD   (P_BAUD),
        .AWIDTH (4)
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

    //---------------- PC -> FPGA 시리얼 송신 ----------------
    task uart_send(input [7:0] d);
        integer i;
        begin
            rx = 1'b0;  // start bit
            repeat (P_BIT_CLKS) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rx = d[i];  // LSB first
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            rx = 1'b1;  // stop bit
            repeat (P_BIT_CLKS) @(posedge clk);
        end
    endtask

    //---------------- RX FIFO 에서 한 바이트 꺼내기 ----------------
    //  자극은 항상 "클럭 엣지 + 1ns" 에 준다. 엣지와 같은 시각에 값을 바꾸면
    //  DUT 가 그 엣지에서 볼지 다음 엣지에서 볼지가 시뮬레이터 실행 순서에
    //  달려서, 1클럭 펄스가 두 엣지에 걸쳐 두 번 샘플링되기도 한다.
    task pop_rx(output [7:0] d);
        integer k;
        begin
            k = 0;
            while (rx_empty && k < 100_000) begin
                @(posedge clk);
                k = k + 1;
            end
            if (rx_empty) begin
                $display("  FAIL : RX FIFO 가 비어 있음 (타임아웃)");
                err = err + 1;
                d   = 8'h00;
            end else begin
                @(posedge clk);
                #1;
                d      = rx_data;  // 조합 출력이라 지금 head 가 보인다
                rx_pop = 1'b1;
                @(posedge clk);
                #1;
                rx_pop = 1'b0;
            end
        end
    endtask

    //---------------- TX FIFO 로 한 바이트 밀어넣기 ----------------
    task push_tx(input [7:0] d);
        begin
            @(posedge clk);
            #1;
            while (tx_full) begin
                @(posedge clk);
                #1;
            end
            tx_data = d;
            tx_push = 1'b1;
            @(posedge clk);
            #1;
            tx_push = 1'b0;
        end
    endtask

    //---------------- FPGA -> PC 시리얼 수신 모니터 ----------------
    reg [7:0] rxbuf[0:31];
    integer nrx;

    initial begin : tx_monitor
        reg [7:0] b;
        integer i;
        nrx = 0;
        forever begin
            @(negedge tx);  // start bit
            repeat (P_BIT_CLKS + (P_BIT_CLKS / 2)) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx;
                repeat (P_BIT_CLKS) @(posedge clk);
            end
            rxbuf[nrx] = b;
            nrx = nrx + 1;
        end
    end

    task wait_tx(input integer n, input integer max_clk);
        integer k;
        begin
            k = 0;
            while (nrx < n && k < max_clk) begin
                @(posedge clk);
                k = k + 1;
            end
            if (nrx < n) begin
                $display("  FAIL : 송신 타임아웃 (%0d/%0d 바이트만 수신)", nrx, n);
                err = err + 1;
            end
        end
    endtask

    //=================================================================
    // 시나리오
    //=================================================================
    reg [7:0] d0, d1, d2;
    reg [7:0] bval;
    integer i;
    integer bad;

    initial begin
        clk     = 1'b0;
        reset   = 1'b1;
        rx      = 1'b1;
        rx_pop  = 1'b0;
        tx_push = 1'b0;
        tx_data = 8'h00;
        err     = 0;

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);

        $display("\n===== tb_uart_fifo =====");

        //---------------- 1) 수신 1바이트 ----------------
        $display("\n[1] 수신 : 'A' 한 바이트");
        ok(rx_empty === 1'b1); $display("처음에는 RX FIFO 가 비어 있다");
        uart_send("A");
        repeat (50) @(posedge clk);
        ok(rx_empty === 1'b0); $display("수신 후 empty 가 내려간다");
        pop_rx(d0);
        ok(d0 === "A"); $display("꺼낸 값이 'A'");
        repeat (5) @(posedge clk);
        ok(rx_empty === 1'b1); $display("pop 후 다시 비었다");

        //---------------- 2) 수신 3바이트 순서 ----------------
        $display("\n[2] 수신 : 'a','b','c' 순서 유지");
        uart_send("a");
        uart_send("b");
        uart_send("c");
        repeat (50) @(posedge clk);
        pop_rx(d0);
        pop_rx(d1);
        pop_rx(d2);
        ok(d0 === "a" && d1 === "b" && d2 === "c"); $display("꺼낸 순서가 a, b, c");
        ok(rx_empty === 1'b1); $display("3개 다 꺼내면 빈다");

        //---------------- 3) 송신 2바이트 ----------------
        $display("\n[3] 송신 : \"Hi\" 를 push 하면 시리얼로 나가는가");
        nrx = 0;
        push_tx("H");
        push_tx("i");
        wait_tx(2, 20_000);
        ok(rxbuf[0] === "H" && rxbuf[1] === "i"); $display("시리얼로 'H','i' 수신");

        //---------------- 4) FIFO 깊이 초과 ----------------
        $display("\n[4] 송신 : 20바이트 (FIFO 16단 초과) 무손실");
        nrx = 0;
        for (i = 0; i < 20; i = i + 1) begin
            bval = 8'h30 + i;  // '0' 부터 20개
            push_tx(bval);
        end
        wait_tx(20, 200_000);
        bad = 0;
        for (i = 0; i < 20; i = i + 1) begin
            bval = 8'h30 + i;
            if (rxbuf[i] !== bval) bad = bad + 1;
        end
        ok(bad === 0); $display("20바이트가 순서대로 하나도 안 빠지고 나옴");

        if (err == 0) $display("\n===== tb_uart_fifo : ALL PASS =====\n");
        else $display("\n===== tb_uart_fifo : %0d FAIL =====\n", err);
        $finish;
    end

endmodule
