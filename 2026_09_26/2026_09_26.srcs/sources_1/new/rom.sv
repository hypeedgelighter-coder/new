`timescale 1ns / 1ps


module rom (
    input clk,
    input logic [31:0] instr_code_addr,
    output logic [31:0] instr_code
);
    logic [31:0] rom_file[0:128];

    assign rom_file[0] = 32'b0000_0000_0001_0000_1000_0001_0011_0011;//reg[2]=reg[1](1)+reg[1](1)=2
    assign rom_file[1] = 32'b0100_0000_0001_0001_0000_0001_1011_0011;//reg[3]=reg[2](2)-reg[1](1)=1
    assign rom_file[2] = 32'b0000_0000_0010_0000_1001_0010_0011_0011;//reg[4]=reg[1](1)<<reg[2](2)=4
    assign rom_file[3] = 32'b0000_0000_0010_0000_1010_0010_1011_0011;//reg[5]=reg[1]<reg[2]=1
    assign rom_file[4] = 32'b0000_0000_0010_0000_1011_0011_0011_0011;//reg[6]=reg[1]<reg[2]=1
    assign rom_file[5] = 32'b0000_0000_0010_0000_1100_0011_1011_0011;//reg[7]=reg[1]^reg[2]=3
    assign rom_file[6] = 32'b0000_0000_0000_0000_0000_0101_0110_0011;//reg[0]=reg[0]instr_code_addr+10
    assign rom_file[16]= 32'b0000_0000_0100_0010_0000_0100_0011_0011;//reg[8]=reg[4]+reg[4]


    assign instr_code = rom_file[instr_code_addr];

endmodule
