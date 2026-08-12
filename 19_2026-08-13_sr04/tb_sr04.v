`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/12 14:21:18
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb ();

    reg clk;
    reg reset;
    reg start;
    reg echo;
    wire trigger, done;
    wire [8:0] distance;

    sr04_controller dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .echo(echo),
        .done(done),
        .trigger(trigger),
        .distance(distance)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        start = 0;
        echo  = 0;
        #10;
        reset = 0;
        @(negedge clk);
        start = 1;
        #10;
        start = 0;
        #120_000;
        $stop;
    end


endmodule
