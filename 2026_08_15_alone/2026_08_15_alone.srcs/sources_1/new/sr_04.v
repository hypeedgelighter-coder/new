`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/17 21:16:10
// Design Name: 
// Module Name: sr_04
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sr_04 (
    input  clk,
    input  reset,
    input  start,
    input  echo,
    output trigger
);
    wire w_tick_us;
    tick_us U_TICK_US (
        .clk(clk),
        .reset(reset),
        .tick_us(w_tick_us)
    );

    parameter [2:0]IDLE=3'h0,START=3'h1,WAIT=3'h2,MEASURE=3'h3,DONE=3'h4;
    reg [2:0] n_state, c_state;
    reg trigger_reg, trigger_next;
    reg [4:0] counter_reg, counter_next;

    assign trigger = trigger_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= 0;
            trigger_reg <= 0;
            counter_reg <= 0;
        end else begin
            c_state <= n_state;
            trigger_reg <= trigger_next;
            counter_reg <= counter_next;
        end
    end


    always @(*) begin
        n_state = c_state;
        trigger_next = trigger_reg;
        counter_next = counter_reg;
        case (c_state)
            IDLE: begin
                trigger_next = 0;
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                trigger_next = 1;
                if (w_tick_us) begin
                    counter_next = counter_reg + 1;
                    if (counter_reg == 11) begin
                        n_state = IDLE;
                        trigger_next = 0;
                        counter_next = 0;
                    end
                end
            end
        endcase

    end




endmodule

module tick_us (
    input clk,
    input reset,
    output reg tick_us
);
    reg [$clog2(100)-1:0] counter_reg, counter_next;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_us <= 0;
        end else begin
            counter_next <= counter_reg+1;
            if (counter_reg == 99) begin
                counter_next <= 0;
                tick_us <= 1;
            end else tick_us <= 0;
        end

    end

endmodule
