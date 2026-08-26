`timescale 1ns / 1ps


module uvm_register (
    input clk,
    input resetn,
    input en,
    input [31:0] d,
    output [31:0] q
);

    reg [31:0] q_reg;
    assign q = q_reg;


    always @(posedge clk, negedge resetn) begin
        if (!resetn) begin
            q_reg <= 0;
        end else begin
            if (en) q_reg <= d;
        end
    end
endmodule
