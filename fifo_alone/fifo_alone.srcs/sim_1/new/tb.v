`timescale 1ns / 1ps


module tb ();


    reg clk;
    reg reset;
    reg [7:0] wdata;
    reg pop;
    reg push;
    wire [7:0] rdata;
    wire full;
    wire empty;


    fifo dut (
        .clk  (clk),
        .reset(reset),
        .wdata(wdata),
        .pop  (pop),
        .push (push),
        .rdata(rdata),
        .full (full),
        .empty(empty)
    );


    always #5 clk = ~clk;
    initial begin
        clk   = 0;
        reset = 1;
        push  = 0;
        pop   = 0;
        #10;
        reset = 0;
        push  = 1;
        wdata = 8'h64;
        #10;
        push  = 1;
        wdata = 8'h64;
        #10;
        push  = 1;
        wdata = 8'h50;
        #10;
        push  = 1;
        wdata = 8'h70;
        #10;
        push  = 1;
        wdata = 8'h84;

    end
endmodule
