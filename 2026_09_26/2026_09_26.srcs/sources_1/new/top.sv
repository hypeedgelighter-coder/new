`timescale 1ns / 1ps



module top (
    input clk,
    input rst_n
);
    logic [31:0] instr_code;
    logic mem;
    logic [31:0] ram_waddr, ram_wdata, ram_raddr, ram_rdata;
    logic [31:0] instr_code_addr;
    cpu_rv32i U_CPU_RV32I (
        .instr_code(instr_code),
        .clk(clk),
        .rst_n(rst_n),
        .mem(mem),
        .ram_waddr(ram_waddr),
        .ram_wdata(ram_wdata),
        .ram_raddr(ram_raddr),
        .ram_rdata(ram_rdata),
        .instr_code_addr(instr_code_addr)

    );
    ram U_RAM (
        .clk(clk),
        .mem(mem),
        .ram_waddr(ram_waddr),
        .ram_wdata(ram_wdata),
        .ram_raddr(ram_raddr),
        .ram_rdata(ram_rdata)
    );

    rom U_ROM (
        .clk(clk),
        .instr_code_addr(instr_code_addr),
        .instr_code(instr_code)
    );


endmodule
