`timescale 1ns / 1ps



module ram (
    input logic clk,
    input logic mem,
    input logic [31:0] ram_waddr,
    input logic [31:0] ram_wdata,
    input logic [31:0] ram_raddr,
    output logic [31:0] ram_rdata
);
    logic [31:0] ram_file[0:256];


    always_ff @(posedge clk) begin
        if (mem) begin
            ram_file[ram_waddr] <= ram_wdata;
        end
    end

    always_comb begin
        ram_rdata = ram_file[ram_raddr];
    end



endmodule
