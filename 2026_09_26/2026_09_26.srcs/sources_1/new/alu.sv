`timescale 1ns / 1ps


module alu (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [ 3:0] alu_controller,
    output logic [31:0] wb_data
);

    always_comb begin
        case (alu_controller)
            4'b0_000: wb_data = rs1 + rs2;  //ADD
            4'b1_000: wb_data = rs1 - rs2;  //SUB
            4'b0_001: wb_data = rs1 << rs2;  //SLL
            4'b0_010: wb_data = ($signed(rs1) < $signed(rs2)) ? 1 : 0;  //SLT
            4'b0_011: wb_data = (rs1 < rs2) ? 1 : 0;  //SLTU
            4'b0_100: wb_data = rs1 ^ rs2;  //XOR      
            4'b0_101: wb_data = rs1 >> rs2;  //SRL
            4'b1_101: wb_data = $signed(rs1) >>> rs2;  //SRA
            4'b0_110: wb_data = rs1 | rs2;  //OR
            4'b0_111: wb_data = rs1 & rs2;  //AND
        endcase
    end


endmodule


