`timescale 1ns / 1ps



module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    reg [7:0] q_reg;
    reg edge_reg;
    wire debounce;


    reg [5:0] clk_counter;
    reg oclk;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
            oclk <= 0;
        end else begin
            clk_counter <= clk_counter + 1;
            if (clk_counter == (50 - 1)) begin
                clk_counter <= 0;
                oclk <= ~oclk;
            end
        end
    end


    always @(posedge oclk, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h0;
        end else begin
            q_reg <= {i_btn, q_reg[7:1]};
        end
    end
    assign debounce = &q_reg;



    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else begin
            edge_reg <= debounce;
        end

    end

    assign o_btn = debounce & (~edge_reg);


endmodule
