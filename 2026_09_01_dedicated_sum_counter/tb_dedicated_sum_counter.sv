`timescale 1ns / 1ps

//=============================================================================
//  tb_dedicated_sum_counter
//  1 + 2 + ... + 10 = 55 를 계산하는 dedicated CPU 확인용 testbench
//=============================================================================

module tb_dedicated_sum_counter ();

    logic clk = 0, rst_n = 0;
    logic [7:0] out;

    always #5 clk = ~clk;

    dedicated_sum_counter dut (
        .clk  (clk),
        .rst_n(rst_n),
        .out  (out)
    );

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_dedicated_sum_counter);
    end

    initial begin
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // S0 1 cycle + (S1,S2,S3) x 10 + 마지막 S1 -> S4 : 약 33 cycle
        repeat (40) @(posedge clk);

        if (out === 8'd55) $display("[PASS] out = %0d", out);
        else $display("[FAIL] out = %0d (expected 55)", out);

        #500;
        $finish;
    end

endmodule
