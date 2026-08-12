`timescale 1ns / 1ps

module top_counter_10000 (
    input clk,
    input reset,
    input sel,
    output [7:0]fnd_data,
    output [3:0]fnd_com
);
wire [13:0] w_counter;

datapath_10000 U_DATAPATH_100000 (
        .clk    (clk),
        .reset  (reset),
        .sel (sel),
        .counter(w_counter)
    );
fnd_controller U_FND_CNTL(
    .clk(clk),
    .reset(reset),
    .fnd_in(w_counter),
    .fnd_com(fnd_com),      
    .fnd_data(fnd_data)

);
    
endmodule


module counter_10000 (
    input  clk,
    input  reset,
    output [13:0] counter
);
    datapath_10000 U_DATAPATH (
        .clk    (clk),
        .reset  (reset),
        .counter(counter)
    );
endmodule


module tick_gen (
    input  clk,
    input  reset,
    input sel,
    output reg tick
);
    reg [$clog2(1_000_000)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick        <= 1'b0;
        end else begin
            if (counter_reg == (1_000_000 - 1)) begin
                counter_reg <= 0;
                tick        <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                tick        <= 1'b0;
            end
        end
    end
endmodule


module datapath_10000 (
    input  clk,
    input  reset,
    input sel,
    output [13:0] counter
);
    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk  (clk),
        .reset(reset),
        .sel(sel),
        .tick (w_tick)       
    );

    count_10000 U_COUNTER_10000 (
        .clk    (clk),
        .reset  (reset),
        .i_tick (w_tick),
        .sel(sel),    
        .counter(counter)
    );
endmodule


module count_10000 (
    input  clk,
    input  reset,
    input  i_tick,
    input  sel,
    output [13:0] counter
);
    reg [13:0] tick_counter_reg;    
    assign counter = tick_counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
           
            if (sel) tick_counter_reg <= 14'd9999;  
            else     tick_counter_reg <= 14'd0;     
        end else begin
            if (i_tick) begin
                if (sel) begin
                   `
                    if (tick_counter_reg == 0)
                        tick_counter_reg <= 14'd9999;
                    else
                        tick_counter_reg <= tick_counter_reg - 1;
                end else begin
                    
                    if (tick_counter_reg == 14'd9999)
                        tick_counter_reg <= 14'd0;
                    else
                        tick_counter_reg <= tick_counter_reg + 1;
                end
            end
        end
    end
endmodule

