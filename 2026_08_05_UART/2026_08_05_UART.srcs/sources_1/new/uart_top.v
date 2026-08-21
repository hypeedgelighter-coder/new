`timescale 1ns / 1ps



module uart_top (
    input  clk,
    input  reset,
    input  rx,
    output tx,
    output run,
    output stop,
    output clear,
    output mode,
    output up,
    output down,
    output left,
    output right,
    output S,
    output M,
    output H

);
    wire w_rx_done;
    wire [7:0] w_rx_data;
    wire w_i_baud_tick_16;
    wire w_tx_busy;

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .i_baud_tick(w_i_baud_tick_16),
        .tx_start(w_rx_done),
        .tx_data(w_rx_data),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .tx(tx)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .reset(reset),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .run(run),
        .stop(stop),
        .clear(clear),
        .mode(mode),
        .up(up),
        .down(down),
        .left(left),
        .right(right),
        .S(S),
        .M(M),
        .H(H)
    );


    baud_tick_rx U_BAUD_TICK_RX (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_i_baud_tick_16)
    );
    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .i_baud_tick(w_i_baud_tick_16),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );

endmodule
