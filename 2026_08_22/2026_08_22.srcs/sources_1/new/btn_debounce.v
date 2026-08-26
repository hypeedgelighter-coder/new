`timescale 1ns / 1ps


module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn

);
    reg [7:0] q_reg;
    reg btn_debounce_delay;
    reg btn_debounce;
    reg o_btn_reg;

    assign o_btn = o_btn_reg;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            o_btn_reg <= 0;
            btn_debounce<=0;
            btn_debounce_delay<=0;
            q_reg <= 8'h0;
        end else begin
            if (i_btn) begin
                q_reg <= {q_reg[6:0], i_btn};
                if (&q_reg) begin
                    btn_debounce = 1;
                end
            end
        end
    end


    always @(posedge clk) begin
        if (btn_debounce) begin
            btn_debounce_delay <= 1;
        end
    end

    always @(posedge clk) begin
        if (btn_debounce & ~btn_debounce_delay) begin
            o_btn_reg <= 1;
        end
    end





endmodule


