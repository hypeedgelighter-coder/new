`timescale 1ns / 1ps

module control_unit(

    input clk,
    input reset,
    input i_run_stop,
    input i_clear,
    input i_mode,
    input i_store,
    output o_run_stop,
    output o_clear,
    output o_mode,
    output o_store
);

    parameter STOP = 0, RUN = 1, CLEAR = 2, MODE = 3, STORE = 4;

    reg [2:0] c_state, n_state;
    reg run_stop_reg, run_stop_next, clear_reg, clear_next, mode_reg, mode_next, store_reg, store_next;
   
    // output
    assign o_run_stop = run_stop_reg;
    assign o_clear = clear_reg;
    assign o_mode = mode_reg;
    assign o_store = store_reg;
    

    // state resister
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state         <= STOP;
            run_stop_reg    <= 1'b0;
            clear_reg       <= 1'b0;
            mode_reg        <= 1'b0;
            store_reg       <= 1'b0;
        end else begin
             c_state        <= n_state;
             run_stop_reg   <= run_stop_next;
             clear_reg      <= clear_next;
             mode_reg       <= mode_next;
             store_reg      <= store_next;
        end
    end
   

    // next CL
    always @(*) begin
        n_state             = c_state;
        run_stop_next       = run_stop_reg;
        clear_next          = clear_reg;
        mode_next           = mode_reg;
        store_next          = store_reg;
       
        case(c_state)
            STOP : begin
                // moore output
                run_stop_next = 1'b0;
                clear_next = 1'b0;
                store_next = 1'b0;
               
                if(i_run_stop) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
                else if(i_store) n_state = STORE;
                else n_state = c_state; 
                end

            RUN : begin
                run_stop_next = 1'b1;
                if (i_run_stop) begin
                    n_state = STOP;
                    // mealy outputdlgo
                    // run_stop_next = 1'b0;
                    // clear_next = 1'b0;
                end
            end
            
            CLEAR : begin
                clear_next = 1'b1;
                n_state = STOP;
            end

            MODE : begin
                mode_next = ~mode_reg;
                n_state = STOP;
            end

            STORE : begin
                store_next =1'b1;
                n_state = STOP;
                end
        endcase
    end

   
endmodule
