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
        .clk  (clk),
        .reset(reset),
        .clk1 (clk1),
        .clk2 (clk2)
    );

endmodule



module clk_counter (
    input  clk,
    input  reset,
    output clk1
);
    reg clk1_reg;
    reg [$clog2(1_000_000)-1:0] counter_reg;

    assign clk1 = clk1_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk1_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (1_000_000 - 1)) begin
                counter_reg <= 0;
                clk1_reg <= 1;

            end else begin
                clk1_reg <= 0;
            end
        end
    end

endmodule





module clk1_counter (
    input clk,
    input clk1,
    input reset,
    output [13:0] clk2

);



    reg [13:0] clk2_reg;
    assign clk2 = clk2_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk2_reg <= 0;
        end else begin
            if (clk1) begin
                clk2_reg <= clk2_reg + 1;
            end
            if (clk2_reg == 10000) clk2_reg <= 0;
        end
    end

endmodule

