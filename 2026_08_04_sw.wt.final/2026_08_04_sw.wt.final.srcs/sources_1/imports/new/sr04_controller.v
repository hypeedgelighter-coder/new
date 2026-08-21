`timescale 1ns / 1ps


module sr04_controller (
    input clk,
    input reset,
    input start,
    input echo,
    output done,
    output reg trigger,
    output [8:0] distance
);
    parameter [2:0 ]IDLE = 3'h0, START = 3'h1, WAIT = 3'h2, COUNT = 3'h3, DISTANCE=3'h4;
    reg [2:0] c_state, n_state;
    reg  run_stop;
    reg  clear;
    wire w_tick;
    reg [$clog2(23200)-1:0] count_reg, count_next;
    reg [8:0] distance_reg;

    assign distance = distance_reg;
    assign done = (c_state == DISTANCE);


    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick(w_tick)
    );

    ila_1 U_ILA (
        .clk(clk),
        .probe0(start),
        .probe1(trigger),
        .probe2(echo),
        .probe3(c_state)
    );


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state      <= IDLE;
            count_reg    <= 0;
            distance_reg <= 0;
        end else begin
            c_state   <= n_state;
            count_reg <= count_next;
            if (c_state == COUNT && n_state == DISTANCE) begin
                distance_reg <= count_reg / 58;
            end
        end
    end

    always @(*) begin
        run_stop = 0;
        clear = 0;
        n_state = c_state;
        trigger = 0;
        count_next = count_reg;
        case (c_state)
            IDLE: begin
                run_stop = 0;
                clear = 1;
                count_next = 0;
                if (start) n_state = START;
                else n_state = c_state;
            end
            START: begin
                run_stop = 1;
                clear = 0;
                trigger = 1;
                if (w_tick) begin
                    count_next = count_reg + 1;
                end
                if (count_reg == 11) begin
                    count_next = 0;
                    n_state = WAIT;
                end
            end
            WAIT: begin
                run_stop = 1;
                if (w_tick) begin
                    count_next = count_reg + 1;
                    if (count_reg > 201) begin
                        if (echo) begin
                            n_state = COUNT;
                            count_next = 0;
                        end
                    end
                end
            end
            COUNT: begin
                run_stop = 1;
                if (w_tick) begin
                    count_next = count_reg + 1;
                end
                if (!echo) begin
                    n_state = DISTANCE;
                end
            end
            DISTANCE: begin
                run_stop = 0;
                count_next = 0;
                n_state = IDLE;
            end
        endcase
    end

endmodule





module tick_gen (
    input clk,
    input reset,
    input run_stop,
    input clear,
    output reg o_tick
);


    reg [$clog2(100)-1:0] clk_counter;

    always @(posedge clk, posedge reset)
        if (reset | clear) begin
            clk_counter <= 0;
            o_tick <= 0;
        end else begin
            o_tick <= 0;
            if (run_stop) begin
                clk_counter <= clk_counter + 1;
                if (clk_counter == (100 - 1)) begin
                    clk_counter <= 0;
                    o_tick <= 1;
                end
            end
        end

endmodule


