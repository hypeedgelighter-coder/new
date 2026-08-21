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
    reg run_stop_reg, run_stop_next, clear_reg, clear_next, mode_reg, mode_next;
    // assign{o_clear,o_run_stop,o_mode}={c_state==STOP}?3'b000:
    // {c_state==RUN}?3'b010:
    // {c_state==CLEAR}?3'b100:
    // {c_state==MODE}?3'b000:3'b000;
    assign o_run_stop=run_stop_reg;
    assign o_clear=clear_reg;
    assign o_mode=mode_reg;


    //state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            run_stop_reg <= 0;
            clear_reg <= 0;
            mode_reg <= 0;
        end else begin
            c_state <= n_state;
            run_stop_reg <= run_stop_next;
            clear_reg <= clear_next;
            mode_reg <= mode_next;
        end

    end

    //NEXT,OUTPUT CL

    always @(*) begin
        n_state = c_state;
        run_stop_next = run_stop_reg;
        clear_next = clear_reg;
        mode_next=mode_reg;
        case (c_state)
            STOP: begin
                run_stop_next=1'b0;
                clear_next=1'b0;
                if (i_run_stop) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
                else n_state=c_state;

            end
            RUN: begin
                run_stop_next=1'b1;
                if (i_run_stop) begin
                    n_state = STOP;
                end
            end
            MODE: begin
                mode_next=~mode_reg;
                n_state = STOP;
            end
            CLEAR: begin
                clear_next=1;
                n_state = STOP;
            end
        endcase

    end
endmodule
