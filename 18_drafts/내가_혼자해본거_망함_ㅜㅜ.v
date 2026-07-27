`timescale 1ns / 1ps

// module  (
//     input clk,
//     input reset,
//     output 
// );
// endmodule


module datapath (
    input clk,
    input reset,
    output [13:0] clk2
);


    wire clk1;
    clk_counter a1 (
        .clk  (clk),
        .reset(reset),
        .clk1 (clk1)
    );
    clk1_counter a2 (
        .clk  (clk1),
        .reset(reset),
        .clk2 (clk2)
    );

endmodule





module clk_counter (
    input  clk,
    input  reset,
    output clk1
);
    reg clk1_counter;
    reg counter_reg;

    assign clk1 = clk1_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg  <= 0;
            clk1_counter <= 0;
        end else counter_reg <= counter_reg + 1;
        if (counter_reg == (1_000_000 - 1)) begin
            counter_reg  <= 0;
            clk1_counter <= clk1_counter + 1;
        end else counter_reg <= counter_reg + 1;
    end

endmodule


module clk1_counter (
    input clk,
    input reset,
    output [13:0] clk2

);


    reg clk1_counter;
    reg [13:0] clk2_reg;
    assign clk2 = clk2_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk1_counter <= 0;
            clk2_reg <= 0;
        end else clk1_counter <= clk1_counter + 1;

        if (clk1_counter == (10000 - 1)) begin
            clk1_counter <= 0;
            clk2_reg <= clk2_reg + 1;
        end

    end

endmodule

