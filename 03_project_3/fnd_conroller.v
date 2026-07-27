`timescale 1ns / 1ps



module fnd_conroller ();
endmodule

module clk_div (
    input  clk,
    input  reset,
    output clk1
);


    reg clk_counter1;
    reg clk1_reg;
    assign clk1 = clk1_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_counter1 <= 0;
            clk1_reg <= 0;
        end else begin
            clk_counter1 <= clk_counter1 + 1;
            if (clk_counter1 == 50000) begin
                clk_counter1 <= 0;
                clk1_reg = ~clk1_reg;

            end
        end
    end
endmodule

module clk_div_counter (
    input clk,
    input reset,
    output [1:0] sel

);

    reg [1:0] sel_reg;
    assign sel=sel_reg;


    always @(posedge clk, posedge reset) begin
        if (reset) sel_reg <= 0;
        else sel_reg <= sel_reg + 1;


    end

endmodule

