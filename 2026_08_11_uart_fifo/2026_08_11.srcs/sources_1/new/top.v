`timescale 1ns / 1ps



module top (
    input  clk,
    input  reset,
    input  rx,
    output tx
);
    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire [7:0] fifo_rx_rdata;
    wire [7:0] fifo_tx_rdata;
    wire fifo_rx_empty;
    wire fifo_tx_empty;
    wire fifo_tx_full;
    wire w_tx_busy;
    wire w_i_baud_tick_16;


    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .i_baud_tick(w_i_baud_tick_16),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );
    fifo RX_FIFO (
        .push(w_rx_done),
        .pop(~fifo_tx_full),
        .clk(clk),
        .reset(reset),
        .w_data(w_rx_data),
        .r_data(fifo_rx_rdata),
        .empty(fifo_rx_empty),
        .full()
    );
    fifo TX_FIFO (

        .push(~fifo_rx_empty),
        .pop(~w_tx_busy),
        .clk(clk),
        .reset(reset),
        .w_data(fifo_rx_rdata),
        .r_data(fifo_tx_rdata),
        .empty(fifo_tx_empty),
        .full(fifo_tx_full)
    );
    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .i_baud_tick(w_i_baud_tick_16),
        .tx_start(~fifo_tx_empty),
        .tx_data(fifo_tx_rdata),
        .tx_busy(w_tx_busy),
        .tx_done(),
        .tx(tx)
    );

    baud_tick_rx U_BAUD_TICK (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_i_baud_tick_16)
    );
endmodule
