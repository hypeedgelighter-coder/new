`timescale 1ns / 1ps




module tb_clkdiv();
    reg clk,reset;
    wire o_1khz;
    clk_div dut (
        .clk(clk),
        .reset(reset),
        .o_1khz(o_1khz)
);
    always #5 clk=~clk;
    initial begin
        clk=0;
        reset=1;
        #10;
        reset=0;
        #(500_000*3);
        $finish;
 end
    
endmodule
