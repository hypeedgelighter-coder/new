`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module tb_10000_counter ();

    reg clk;
    reg reset;
    reg btn_L;
    reg btn_UP;
    reg btn_R;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    parameter TEST_DELAY = 25_000_000;
    top_counter_10000 dut (
        .clk(clk),
        .reset(reset),
        .btn_L(btn_L),
        .btn_R(btn_R),
        .btn_UP(btn_UP),
        .fnd_data(fnd_data),
        .fnd_com(fnd_com)
    );


    always #5 clk = ~clk;



    initial begin
        clk = 0;
        reset = 1;
        {btn_R, btn_L, btn_UP} = 3'b000;
        #10;
        reset = 0;

        {btn_R, btn_L, btn_UP} = 3'b000;
         #(TEST_DELAY);

         #10;
        {btn_R, btn_L, btn_UP} = 3'b010;
         #(TEST_DELAY);
        
       


        // #(1_000_000 * 10 * 10);  
        #1000;
        $stop;
    end

endmodule
