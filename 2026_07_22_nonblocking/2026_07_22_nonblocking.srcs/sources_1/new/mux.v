`timescale 1ns / 1ps



module mux(
    input sel,
    input a,
    input b,
    output reg mux_out

    );
    always @(*) begin
        
            if(sel) mux_out=b;
            else mux_out=a;
        end
endmodule