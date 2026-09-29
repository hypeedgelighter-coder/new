`timescale 1ns / 1ps


module pc (
    input clk,
    input rst_n,
    input logic [31:0] pc,
    output logic [31:0] instr_code_addr
);

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            instr_code_addr <= 32'h00;
        end else instr_code_addr <= pc;
    end



endmodule
