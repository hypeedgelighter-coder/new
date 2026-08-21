`timescale 1ns / 1ps

module uart ();
endmodule

module uart_rx (
    input clk,
    input reset,
    input start,
    input rx,
    output [7:0] rx_data,
    output rx_done,
    output rx_busy,
    output rx_error
);
    parameter [1:0] IDLE = 2'h0, START = 2'h1, DATA = 2'h2, STOP = 2'h3;
    wire baud_tick;
    reg [1:0]c_state, n_state;
    reg [3:0] counter_reg, counter_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next;
    reg rx_busy_reg, rx_busy_next;

    baud_tick U_BAUD_TICK (.clk(clk), .reset(reset), .o_baud_tick(baud_tick));
    assign rx_data = data_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            counter_reg <= 0;
            rx_done_reg <= 0;
            rx_busy_reg <= 0;
            data_reg <= 0;
        end else begin
            c_state <= n_state;
            counter_reg <= counter_next;
            rx_done_reg <= rx_done_next;
            rx_busy_reg <= rx_busy_next;
            data_reg <= data_next;
        end
    end

    always @(*) begin
        case (c_state)
            IDLE: begin
                if (start) n_state = START;
                else n_state = c_state;
            end
            START: begin
                if (baud_tick) begin
                    counter_next = counter_reg + 1;
                    if (counter_reg == 7) begin
                        n_state = DATA;
                        counter_reg = 0;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick (
    input clk,
    input reset,
    output o_baud_tick
);
    reg [$clog2(100_000_000/153600)-1:0] counter_reg;
    reg o_baud_tick_reg;
    assign o_baud_tick = o_baud_tick_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            o_baud_tick_reg <= 0;
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (100_000_000 / 153600) - 1) begin
                counter_reg <= 0;
                o_baud_tick_reg <= 1;
            end else o_baud_tick_reg <= 0;
        end
    end
endmodule
