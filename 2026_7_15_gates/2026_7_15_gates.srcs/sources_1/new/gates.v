`timescale 1ns / 1ps


module gates(
    input a,
    input b,
    output y0,
    output y1,
    output y2,
    output y3,
    output y4,
    output y5,
    output y6
    );

    assign y0 = a & b;              //AND
    assign y1 = ~(a & b);           //NAND
    assign y2 = a | b;              //OR
    assign y3 = ~(a | b);           //NOR
    assign y4 = (a ^ b);            //Exor
    assign y5 = ~(a ^ b);           //Exnor
    assign y6 = ~b;


endmodule
