module count_10000 (
    input  clk,
    input  reset,
    input  i_tick,
    input  sel,
    output [13:0] counter
);
    reg [13:0] tick_counter_reg;
    reg tick_counter_reg_reset;
    reg next_count;    
    assign counter = tick_counter_reg;
    
    always @(sel) begin
        if(sel)begin
            tick_counter_reg_reset<=14'd99;
            next_count<=tick_counter_reg+1;
        end else begin
            tick_counter_reg_reset<=0;
            next_count<=tick_counter_reg-1;
        end

        
    end

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_counter_reg<=tick_counter_reg_reset;
        end else begin
            tick_counter_reg<=next_count;
        end
    end
endmodule

