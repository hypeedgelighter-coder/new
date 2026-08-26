`timescale 1ns / 1ps

//=====================================================================
// uart_fifo  -  블록도의 "UART_FIFO" 덩어리
//
//   PC --TX--> [uart_rx] --rx_done--> [RX_FIFO] --rx_data/rx_empty--> ASCII Decoder
//                                          ^-- rx_pop --------------------'
//
//   PC <--RX-- [uart_tx] <--pop-- [TX_FIFO] <--tx_data/tx_push-- ASCII Sender
//                                          '-- tx_full ------------------->
//
//  RX 쪽은 pop 을 밖(ascii_decoder)에서 하고, TX 쪽은 push 를 밖
//  (ascii_sender)에서 한다. full 을 밖으로 내보내서 sender 가
//  backpressure 를 보고 밀어넣게 한다.
//=====================================================================
module uart_fifo #(
    parameter SYS_CLK = 100_000_000,
    parameter BAUD    = 9600,
    parameter AWIDTH  = 3       // FIFO 깊이 2**3 = 8
) (
    input        clk,
    input        reset,

    // 물리 UART
    input        rx,
    output       tx,

    // 수신측 (ASCII Decoder 로)
    output [7:0] rx_data,
    output       rx_empty,
    input        rx_pop,

    // 송신측 (ASCII Sender 에서)
    input  [7:0] tx_data,
    input        tx_push,
    output       tx_full
);

    wire       w_baud_tick;
    wire [7:0] w_rx_byte;
    wire       w_rx_done;
    wire [7:0] w_tx_byte;
    wire       w_tx_empty;
    wire       w_tx_busy;
    wire       w_tx_pop;

    baud_tick_gen #(
        .SYS_CLK(SYS_CLK),
        .BAUD   (BAUD)
    ) U_BAUD_TICK_GEN (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick)
    );

    //--------------------------- 수신 ---------------------------
    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .i_baud_tick(w_baud_tick),
        .rx_data    (w_rx_byte),
        .rx_done    (w_rx_done)
    );

    fifo #(
        .AWIDTH(AWIDTH)
    ) U_RX_FIFO (
        .clk   (clk),
        .reset (reset),
        .push  (w_rx_done),
        .pop   (rx_pop),
        .w_data(w_rx_byte),
        .r_data(rx_data),
        .empty (rx_empty),
        .full  ()             // RX 오버런은 무시 (명령 문자는 드문드문 들어옴)
    );

    //--------------------------- 송신 ---------------------------
    fifo #(
        .AWIDTH(AWIDTH)
    ) U_TX_FIFO (
        .clk   (clk),
        .reset (reset),
        .push  (tx_push),
        .pop   (w_tx_pop),
        .w_data(tx_data),
        .r_data(w_tx_byte),
        .empty (w_tx_empty),
        .full  (tx_full)
    );

    // uart_tx 가 IDLE(=tx_busy 0) 이고 FIFO 에 데이터가 있으면
    // 그 클럭에 tx_start 와 pop 을 같이 준다.
    // uart_tx 는 같은 엣지에서 r_data 를 래치하므로 (rptr 이 올라가기 전 값)
    // 바이트당 정확히 한 번 pop 된다.
    assign w_tx_pop = ~w_tx_empty & ~w_tx_busy;

    uart_tx U_UART_TX (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(w_baud_tick),
        .tx_start   (~w_tx_empty),
        .tx_data    (w_tx_byte),
        .tx_busy    (w_tx_busy),
        .tx_done    (),
        .tx         (tx)
    );

endmodule
