`timescale 1ns / 1ps



module register (
    input logic clk,
    input logic rst,
    input logic enable,
    input logic [7:0] d,
    output logic [7:0] q
);

    always @(posedge clk, posedge rst) begin
        if (rst) q <= 8'h0;
        else if(enable)q <= d;
    end
endmodule
