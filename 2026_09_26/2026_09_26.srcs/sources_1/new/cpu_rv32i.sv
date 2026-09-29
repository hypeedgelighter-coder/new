`timescale 1ns / 1ps



module cpu_rv32i (
    input [31:0] instr_code,
    input clk,
    input rst_n,
    output mem,
    output [31:0] ram_waddr,
    output [31:0] ram_wdata,
    output [31:0] ram_raddr,
    input [31:0] ram_rdata,
    output [31:0] instr_code_addr

);

    logic [4:0] instr_code_rs1, instr_code_rs2, instr_code_rd;
    logic [3:0] alu_controller;
    logic [2:0] comp_controller;
    logic [11:0] instr_code_imm;
    logic [19:0] instr_code_imm_long;
    logic alu_src_sel;
    logic [2:0] strb;
    logic [2:0] mux_sel_pc;
    logic wb;
    control_unit U_CONTROL_UNIT (
        .instr_code(instr_code),
        .instr_code_rs1(instr_code_rs1),
        .instr_code_rs2(instr_code_rs2),
        .instr_code_rd(instr_code_rd),
        .alu_controller(alu_controller),
        .instr_code_imm(instr_code_imm),
        .instr_code_imm_long(instr_code_imm_long),
        .alu_src_sel(alu_src_sel),
        .comp_controller(comp_controller),
        .strb(strb),
        .mux_sel_pc(mux_sel_pc),
        .mem(mem),
        .wb(wb)
    );


    cpu_rv32i_datapath U_CPU_RV32I_DATAPATH (
        .clk(clk),
        .rst_n(rst_n),
        .instr_code_rs1(instr_code_rs1),
        .instr_code_rs2(instr_code_rs2),
        .instr_code_rd(instr_code_rd),
        .alu_controller(alu_controller),
        .instr_code_imm(instr_code_imm),
        .instr_code_imm_long(instr_code_imm_long),
        .alu_src_sel(alu_src_sel),
        .comp_controller(comp_controller),
        .ram_waddr(ram_waddr),
        .ram_wdata(ram_wdata),
        .ram_raddr(ram_raddr),
        .ram_rdata(ram_rdata),
        .instr_code_addr(instr_code_addr),
        .mux_sel_pc(mux_sel_pc),
        .wb(wb)

    );




endmodule
