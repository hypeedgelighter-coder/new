`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module tb_10000_counter();

    reg  clk;
    reg  reset;       
    wire [13:0]counter;

    datapath_10000 dut (
        .clk  (clk),
        .reset(reset),   
        .counter (counter)

        
    );                   

    
    always #5 clk = ~clk;

        

    initial begin
        clk   = 0;
        reset = 1;
        #10;
        reset = 0;

      
        #(1_000_000 * 10 * 10);  
        $stop;
    end

endmodule
