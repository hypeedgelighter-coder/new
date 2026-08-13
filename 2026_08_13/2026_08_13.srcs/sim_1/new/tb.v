`timescale 1ns / 1ps



module tb ();
    reg  clk;
    reg  reset;
    reg  start;
    wire humidity;
    wire temperature;
    wire done;
    wire valid;
    wire dht11_io;

    dht_controller dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .humidity(humidity),
        .temperature(temperature),
        .done(done),
        .valid(valid),
        .dht11_io(dhi11_io)

    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        #10;
        reset = 0;
        #10;
        start = 1;
        #10;
        start = 0;
    end
endmodule
