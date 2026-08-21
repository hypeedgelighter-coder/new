`timescale 1ns / 1ps

module clock_control_unit (
    input        clk,
    input        reset,
    input        i_set_mode, 
    input        i_left,     
    input        i_right,    
    input        i_up,       
    input        i_down,     
    output       o_set_mode, 
    output [1:0] o_digit_pos,
    output       o_up,
    output       o_down
);

    reg [1:0] digit_pos_reg, digit_pos_next;

    assign o_set_mode  = i_set_mode;
    assign o_digit_pos = digit_pos_reg;
    assign o_up        = i_up & i_set_mode;
    assign o_down      = i_down & i_set_mode;

   
    always @(posedge clk, posedge reset) begin
        if (reset) digit_pos_reg <= 2'd0;
        else digit_pos_reg <= digit_pos_next;
    end

 
    always @(*) begin
        digit_pos_next = digit_pos_reg;
        if (i_set_mode) begin
            if (i_left && digit_pos_reg != 2'd3) digit_pos_next = digit_pos_reg + 1'b1;
            else if (i_right && digit_pos_reg != 2'd0) digit_pos_next = digit_pos_reg - 1'b1;
        end
    end

endmodule
