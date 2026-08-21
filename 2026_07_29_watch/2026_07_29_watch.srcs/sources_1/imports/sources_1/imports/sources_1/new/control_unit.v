`timescale 1ns / 1ps



module control_unit (
    input  clk,
    input  reset,
    input  i_btn_L,
    input  i_btn_R,
    input  i_btn_U,
    input  i_btn_D,
    output o_btn_L,
    output o_btn_R,
    output o_btn_U,
    output o_btn_D,


);

    parameter LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3;
    reg [3:0] c_state, n_state;
    reg LEFT_reg,;



    always@(*)begin
        case (c_state)
        b'1110:begin
            if(i_btn_L) next_state=o_btn_L;
            else if(i_btn_R) next_state=o_btn_R;
            else if(i_btn_U) next_state=o_btn_U;
            else if(i_btn_D) next_state=o_btn_D;
                      
        end
        b'1101:begin
            if(i_btn_L) next_state=o_btn_L;
            else if(i_btn_R) next_state=o_btn_R;
            else if(i_btn_U) next_state=o_btn_U;
            else if(i_btn_D) next_state=o_btn_D;
                      
        end
        b'1011:begin
            if(i_btn_L) next_state=o_btn_L;
            else if(i_btn_R) next_state=o_btn_R;
            else if(i_btn_U) next_state=o_btn_U;
            else if(i_btn_D) next_state=o_btn_D;
                      
        end
        b'0111:begin
            if(i_btn_L) next_state=o_btn_L;
            else if(i_btn_R) next_state=o_btn_R;
            else if(i_btn_U) next_state=o_btn_U;
            else if(i_btn_D) next_state=o_btn_D;
                      
        end

       
             
        endcase
        
        
    end

    endmodule