`timescale 1ns / 1ps



module mux_2x1 (
    input logic mux_sel,
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] c
);

    always_comb begin
        if (mux_sel) begin
            c = b;
        end else c = a;
    end
endmodule

