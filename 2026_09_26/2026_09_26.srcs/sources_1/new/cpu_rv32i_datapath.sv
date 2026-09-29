`timescale 1ns / 1ps



module cpu_rv32i_datapath (
    input logic clk,
    input logic rst_n,
    input logic [4:0] instr_code_rs1,
    input logic [4:0] instr_code_rs2,
    input logic [4:0] instr_code_rd,
    input logic [3:0] alu_controller,
    input logic [11:0] instr_code_imm,
    input logic [19:0] instr_code_imm_long,
    input logic alu_src_sel,
    input logic [2:0] comp_controller,
    output logic [31:0] instr_code_addr,
    output logic [31:0] ram_waddr,
    output logic [31:0] ram_wdata,
    output logic [31:0] ram_raddr,
    input logic [31:0] ram_rdata,
    input logic [2:0] mux_sel_pc,
    input logic wb
);
    logic [31:0] alu_imm;
    logic [31:0]
        instr_code_addr_basic,
        instr_code_addr_btype,
        instr_code_addr_imm,
        instr_code_addr_utype,
        instr_code_addr_jtype,
        instr_code_addr_sel;
    logic [31:0] pc;
    logic b_type_sel;
    logic [31:0] wb_data;
    logic [31:0] rs1, rs2;
    logic [31:0] mux_sel;

    assign ram_waddr = rs1 + alu_imm;
    assign ram_wdata = rs2;
    assign ram_raddr = rs1 + alu_imm;
    assign alu_imm   = {20'b0, instr_code_imm};
    register_file U_REGISTER_FILE (
        .clk(clk),
        .instr_code_rs1(instr_code_rs1),
        .instr_code_rs2(instr_code_rs2),
        .instr_code_rd(instr_code_rd),
        .wb_data(wb_data),
        .wb(wb),
        .rs1(rs1),
        .rs2(rs2)
        
    );
    mux_2x1 U_ALU_SRC_SEL (
        .mux_sel(alu_src_sel),
        .a(rs2),
        .b(alu_imm),
        .c(mux_sel)
    );
    alu U_ALU (
        .rs1(rs1),
        .rs2(mux_sel),
        .alu_controller(alu_controller),
        .wb_data(wb_data)
    );
    adder U_ADDER_PC_BASIC (
        .a(instr_code_addr),
        .b(32'b1),
        .c(instr_code_addr_basic)
    );
    adder_btype U_ADDER_PC_BTYPE (
        .a(instr_code_addr),
        .b(instr_code_imm),
        .c(instr_code_addr_btype)
    );
    adder_imm_type U_ADDER_PC_IMM (
        .a(instr_code_addr),
        .b(instr_code_imm),
        .c(instr_code_addr_imm)
    );
    adder_u_type U_ADDER_UTYPE (
        .a(instr_code_addr),
        .b(instr_code_imm_long),
        .c(instr_code_addr_utype)
    );
    adder_j_type U_ADDER_JTYPE (
        .a(instr_code_addr),
        .b(instr_code_imm_long),
        .c(instr_code_addr_jtype)
    );
    mux_5x1 U_MUX_5X1 (
        .mux_sel_pc(mux_sel_pc),
        .b_type_sel(b_type_sel),
        .instr_code_addr_basic(instr_code_addr_basic),
        .instr_code_addr_btype(instr_code_addr_btype),
        .instr_code_addr_imm(instr_code_addr_imm),
        .instr_code_addr_utype(instr_code_addr_utype),
        .instr_code_addr_jtype(instr_code_addr_jtype),
        .c(instr_code_addr_sel)
    );
    pc U_PC (
        .clk(clk),
        .rst_n(rst_n),
        .instr_code_addr(instr_code_addr),
        .pc(instr_code_addr_sel)
    );
    compare U_COMPARE (
        .comp_controller(comp_controller),
        .rs1(rs1),
        .rs2(rs2),
        .b_type_sel(b_type_sel)
    );



endmodule
