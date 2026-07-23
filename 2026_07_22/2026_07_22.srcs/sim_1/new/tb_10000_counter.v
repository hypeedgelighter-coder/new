`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module tb_10000_counter();

    reg  clk;
    reg  reset;
    reg  [2:0]sw;      
    wire [3:0]fnd_com;
    wire [7:0]fnd_data;

    parameter TEST_DELAY =25_000_000;
    top_counter_10000 dut(
    .clk(clk),
    .reset(reset),
    .sw(sw),
    .fnd_data(fnd_data),
    .fnd_com(fnd_com)
);                   

    
    always #5 clk = ~clk;

        

    initial begin
        clk   = 0;
        reset = 1;
        sw=3'b000;
        #10;
        reset = 0;

        sw=3'b000;
        #(TEST_DELAY);
        sw=3'b010;
        #(TEST_DELAY);
        sw=3'b000;
        #(TEST_DELAY);
        sw=3'b011;
        #(TEST_DELAY);
        sw=3'b001;
        #(TEST_DELAY);
        sw=3'b101;
        #(TEST_DELAY);
        sw=3'b000;
        #(TEST_DELAY);

      
        // #(1_000_000 * 10 * 10);  
        #1000;
        $stop;
    end

endmodule