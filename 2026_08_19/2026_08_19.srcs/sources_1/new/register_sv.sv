`timescale 1ns / 1ps


module register_sv (
    input logic clk,
    input logic rst,
    input logic enable,
    input logic [31:0] d,
    output logic [31:0] q

);




    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            q <= 0;
        end else begin
            if (enable) begin
                q <= d;
            end
        end
    end
endmodule
