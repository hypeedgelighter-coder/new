`timescale 1ns / 1ps


module sim ();

    reg clk;
    reg reset;
    reg run_stop;
    reg clear;
    reg mode;
    wire [6:0] msec;
    wire [5:0] sec;
    wire [5:0] min;
    wire [4:0] hour;

    parameter TICK_DELAY = 1_000_000*10;


    stopwatch_datapath dut (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .mode(mode),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        run_stop = 0;
        clear = 0;
        mode = 0;
        #10;
        reset = 0;
        #(TICK_DELAY*5);
        #100;
        $stop;
    end
endmodule
