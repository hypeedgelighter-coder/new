`timescale 1ns / 1ps


module register_file (
    input logic clk,
    input logic [4:0] instr_code_rs1,
    input logic [4:0] instr_code_rs2,
    input logic [4:0] instr_code_rd,
    input logic wb,
    input logic [31:0] wb_data,
    output logic [31:0] rs1,
    output logic [31:0] rs2
);

    logic [31:0] register_file[0:31];
    assign register_file[0] = 32'h00;
    assign register_file[1] = 32'h01;

    always_ff @(posedge clk) begin
        if(wb)begin
        if (instr_code_rd) register_file[instr_code_rd] <= wb_data;
        end
    end
    assign rs1 = register_file[instr_code_rs1];
    assign rs2 = register_file[instr_code_rs2];
endmodule
