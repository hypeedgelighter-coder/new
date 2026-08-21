`timescale 1ns / 1ps

module tb ();
    reg  clk;
    reg  reset;
    reg  start;
    reg  echo;
    wire trigger;

    sr_04 dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .echo(echo),
        .trigger(trigger)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        start = 0;
        #10;
        reset = 0;
        start = 1;
    end
endmodule
