`timescale 1ns / 1ps

module tick_gen_100hz(
    input clk,
    input reset,
    output reg o_tick
);
    parameter F_COUNT = 1_000_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
                    
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1;
                    o_tick      <= 1'b0;
                end
            end
        end
endmodule



module time_counter#(parameter BIT_WIDTH = 7, TIMES =100, INIT_VAL = 0)(
    input clk,
    input reset,
    input i_tick,
    input mode,
    input clear,
    input run_stop,
    input up, 
    input down,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= INIT_VAL;
            o_tick <= 1'b0;
        end else if (clear) begin
            counter_reg <= INIT_VAL;
            o_tick <= 1'b0;
        end else if (up | down) begin
            if (up) begin
                counter_reg <= (counter_reg == (TIMES - 1)) ? 0 : counter_reg + 1;
            end else begin
                counter_reg <= (counter_reg == 0) ? (TIMES - 1) : counter_reg - 1;
            end
            o_tick <= 1'b0;
        end else if (run_stop && i_tick) begin
            if (!mode) begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1;
                    o_tick      <= 1'b0;
                end
            end else begin
                if (counter_reg == 0) begin
                    counter_reg <= (TIMES - 1);
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg - 1;
                    o_tick      <= 1'b0;
                end
            end
        end else begin
            o_tick <= 1'b0;
        end
    end
endmodule