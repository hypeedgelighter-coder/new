`timescale 1ns / 1ps

module control_unit_watch (
    input        clk,
    input        reset,
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    input        btn_C,
    output [1:0] edit_sel,
    output       o_clear,
    output       o_up,
    output       o_down
);
    parameter CLEAR = 0, LEFT = 1, RIGHT = 2, UP = 3, DOWN = 4;

    reg [2:0] c_state, n_state;
    reg btn_L_reg, btn_L_next, btn_R_reg, btn_R_next, btn_U_reg, btn_U_next;
    reg btn_D_reg, btn_D_next, btn_C_reg, btn_C_next;
    reg clear_reg, clear_next;
    reg [1:0] edit_sel_reg, edit_sel_next;

    
    
    //sec 0 min 1 hour 2

    //output
    assign edit_sel = edit_sel_reg;
    assign o_clear  = clear_reg;
    assign o_up     = btn_U_reg;
    assign o_down   = btn_D_reg;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state      <= CLEAR;
            btn_L_reg    <= 1'b0;
            btn_R_reg    <= 1'b0;
            btn_U_reg    <= 1'b0;
            btn_D_reg    <= 1'b0;
            btn_C_reg    <= 1'b0;
            clear_reg    <= 1'b0;
            edit_sel_reg <= 2'b00;
        end else begin
            c_state      <= n_state;
            btn_L_reg    <= btn_L_next;
            btn_R_reg    <= btn_R_next;
            btn_U_reg    <= btn_U_next;
            btn_D_reg    <= btn_D_next;
            btn_C_reg    <= btn_C_next;
            clear_reg    <= clear_next;
            edit_sel_reg <= edit_sel_next;
        end
    end

    // next CL 조합은 현재값 을 읽고 SL은 next값을 읽는다.
    always @(*) begin
        n_state       = c_state;
        clear_next    = clear_reg;
        btn_C_next    = btn_C_reg;
        btn_D_next    = btn_D_reg;
        btn_L_next    = btn_L_reg;
        btn_R_next    = btn_R_reg;
        btn_U_next    = btn_U_reg;
        edit_sel_next = edit_sel_reg;

        case (c_state)
            CLEAR: begin
                clear_next = 1'b0;
                btn_L_next = 1'b0;
                btn_R_next = 1'b0;
                btn_U_next = 1'b0;
                btn_D_next = 1'b0;
                if      (btn_L) n_state = LEFT;
                else if (btn_R) n_state = RIGHT;
                else if (btn_U) n_state = UP;
                else if (btn_D) n_state = DOWN;
                else if (btn_C) clear_next = 1'b1;   
            end

            LEFT: begin
                btn_L_next    = 1'b1;
                edit_sel_next = (edit_sel_reg == 2'd0) ? 2'd2 : edit_sel_reg - 2'd1;  // 0→2→1→0
                n_state       = CLEAR;
            end

            RIGHT: begin
                btn_R_next    = 1'b1;
                edit_sel_next = (edit_sel_reg == 2'd2) ? 2'd0 : edit_sel_reg + 2'd1;  // 0→1→2→0
                n_state       = CLEAR;
            end

            UP: begin
                btn_U_next = 1'b1;
                n_state    = CLEAR;
            end

            DOWN: begin
                btn_D_next = 1'b1;
                n_state    = CLEAR;
            end
        endcase
    end

endmodule







module control_unit_stopwatch (
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

    // output
    // assign {o_clear, o_run_stop, o_mode} = (c_state == STOP) ? 3'b000:
    //                                         (c_state == RUN) ? 3'b010:
    //                                         (c_state == CLEAR) ? 3'b100:
    //                                         (c_state == MODE) ? 3'b000: 3'b000;

    assign o_run_stop = run_stop_reg;
    assign o_clear = clear_reg;
    assign o_mode = mode_reg;


    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            run_stop_reg <= 1'b0;
            clear_reg    <= 1'b0;
            mode_reg     <= 1'b0;
        end else begin
            c_state      <= n_state;
            run_stop_reg <= run_stop_next;
            clear_reg    <= clear_next;
            mode_reg     <= mode_next;
        end
    end
       
    // Next CL
    always @(*) begin
        n_state       = c_state;
        run_stop_next = run_stop_reg;
        clear_next    = clear_reg;
        mode_next     = mode_reg;
        case (c_state)
            STOP: begin
                // moore output
                run_stop_next = 1'b0;
                clear_next    = 1'b0;
                if (i_run_stop) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
                else n_state = c_state;
            end

            RUN: begin
                run_stop_next = 1'b1;
                if (i_run_stop) begin
                    n_state = STOP;
                end
            end

            CLEAR: begin
                clear_next = 1'b1;
                n_state = STOP;
            end

            MODE: begin
                mode_next = ~mode_reg; 
                n_state = STOP;
             end
        endcase
    end

endmodule