`timescale 1ns / 1ps


module multiply(
    input [3:0]a,
    input [3:0]b,
    output [7:0]p
    );
    // wire [7:0]p0,p1,p2,p3;

    // assign p0=b[0]? {4'b0,a}:8'b0;
    // assign p1=b[1]? {3'b0,a,1'b0}:8'b0;
    // assign p2=b[2]? {2'b0,a,2'b0}:8'b0;
    // assign p3=b[3]? {1'b0,a,3'b0}:8'b0;

    // assign p=p0+p1+p2+p3;

    assign p=a*b;


endmodule
