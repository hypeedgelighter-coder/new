`timescale 1ns / 1ps


module top_sr04 (
    input clk,
    input reset,
    input btn_start,
    input echo,
    output trigger,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_start;
    wire w_done;
    wire [8:0] w_distance;

    btn_debounce U_BTN_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_start),
        .o_btn(w_start)
    );

    sr04_controller U_SR04_CONTROLLER (
        .clk    (clk),
        .reset  (reset),
        .start  (w_start),
        .echo   (echo),
        .done   (w_done),
        .trigger(trigger),
        .distance(w_distance)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk    (clk),
        .reset  (reset),
        .fnd_in ({5'b0, w_distance}),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule
