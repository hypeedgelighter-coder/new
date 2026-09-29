`timescale 1ns / 1ps



module tb_top ();

    logic clk;
    logic rst_n;

    top dut (
        .clk  (clk),
        .rst_n(rst_n)
    );

    always #5 clk = ~clk;
    initial begin
        clk   = 0;
        rst_n = 1'b0;
        #10;
        rst_n = 1'b1;
        #100;
        $finish;
        $stop;
    end
endmodule
