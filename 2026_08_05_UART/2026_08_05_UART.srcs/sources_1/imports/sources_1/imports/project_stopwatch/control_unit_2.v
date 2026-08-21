`timescale 1ns / 1ps

module control_unit2 (

    input clk,
    input reset,
    input i_up,
    input i_down,
    input i_beside,
    input i_start,
    input i_zero,
    output o_up,
    output o_down,
    output o_beside,
    output o_start,
    output [1:0] o_digit_cho
);

    parameter STOP = 0, UP = 1, DOWN = 2, BESIDE = 3, START = 4, DONE = 5;

    reg [2:0] c_state, n_state;
    reg
        up_reg,
        up_next,
        down_reg,
        down_next,
        beside_reg,
        beside_next,
        start_reg,
        start_next;
    reg [1:0] digit_cho_reg, digit_cho_next;


    assign o_up = up_reg;
    assign o_down = down_reg;
    assign o_beside = beside_reg;
    assign o_start = start_reg;
    assign o_digit_cho = digit_cho_reg;

    // state resister
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state       <= STOP;
            up_reg        <= 1'b0;
            down_reg      <= 1'b0;
            beside_reg    <= 1'b0;
            start_reg     <= 1'b0;
            digit_cho_reg <= 2'b00;
        end else begin
            c_state       <= n_state;
            up_reg        <= up_next;
            down_reg      <= down_next;
            beside_reg    <= beside_next;
            start_reg     <= start_next;
            digit_cho_reg <= digit_cho_next;

        end
    end


    // next CL
    always @(*) begin
        n_state        = c_state;
        up_next        = up_reg;
        down_next      = down_reg;
        beside_next    = beside_reg;
        start_next     = start_reg;
        digit_cho_next = digit_cho_reg;

        case (c_state)
            STOP: begin
                // moore output
                up_next = 1'b0;
                down_next = 1'b0;
                beside_next = 1'b0;
                start_next = 1'b0;
                // digit_cho_next = 2'b00;

                if (i_up) n_state = UP;
                else if (i_down) n_state = DOWN;
                else if (i_beside) n_state = BESIDE;
                else if (i_start) n_state = START;
                else n_state = c_state;
            end

            START: begin
                start_next = 1'b1;
                if (i_zero) n_state = DONE;
                else if (i_start) n_state = STOP;
                else n_state = c_state;


            end

            DONE: begin
                start_next = 1'b0;
                n_state = STOP;
            end

            BESIDE: begin
                beside_next = 1'b1;
                digit_cho_next = digit_cho_reg + 2'b01;
                n_state = STOP;
            end

            UP: begin
                up_next = 1'b1;
                n_state = STOP;

            end

            DOWN: begin
                down_next = 1'b1;
                n_state   = STOP;
            end

        endcase
    end


endmodule
