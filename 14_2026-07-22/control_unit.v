`timescale 1ns / 1ps



module control_unit (
    input  clk,
    input  reset,
    input  i_run_stop,
    input  i_clear,
    input  i_mode,
    output o_run_stop,
    output o_clear,
    output o_mode


);

    parameter STOP = 0, RUN = 1, CLEAR = 2, MODE = 3;
    reg [1:0] c_state, n_state;
    assign{o_clear,o_run_stop,o_mode}={c_state==STOP}?3'b000:
                                        {c_state==RUN}?3'b010:
                                        {c_state==CLEAR}?3'b100:
                                        {c_state==MODE}?3'b000:3'b000;

    //state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end

    end

    //NEXT,OUTPUT CL

    always @(*) begin
        n_state = c_state;

        case (c_state)
            STOP: begin
                if (i_run_stop) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
                else n_state = c_state;
            end
            RUN: begin
                if (i_run_stop) begin
                    n_state = STOP;
                end
            end
            MODE: begin
                n_state = STOP;
            end
            CLEAR: begin
                n_state = STOP;
            end
        endcase

    end
endmodule
