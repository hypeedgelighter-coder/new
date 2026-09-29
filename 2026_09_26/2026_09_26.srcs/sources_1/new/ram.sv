`timescale 1ns / 1ps



module ram (
    input clk,
    input mem,
    input [31:0] ram_waddr,
    input [31:0] ram_wdata,
    input [31:0] ram_raddr,
    output [31:0] ram_rdata
);
    logic [31:0] ram_file[0:256];

    always_ff @(posedge clk) begin
        if (mem) ram_file[ram_waddr] <= ram_wdata;
    end

    always_comb begin
        if (mem) ram_file[ram_raddr] = ram_rdata;
    end

endmodule
