`timescale 1ns / 1ps



module tb_rtype ();

    logic clk;
    logic [31:0] instr_code;


    cpu_rv32i dut (
        .clk(clk),
        .instr_code(instr_code)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        instr_code = 32'b0000_0000_0001_0000_1000_0001_0011_0011;
        

        $finish;
    end

endmodule
