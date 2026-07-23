`timescale 1ns / 1ps





module full_adder_8bit (
    input [8:0]a,
    input [8:0]b,
    input cin,
    output [8:0]s,
    output c
);
    wire c1;
    full_adder_4bit a7(.a(a[3:0]),.b(b[3:0]),.cin(cin),.s(s[3:0]),.c(c1));
    full_adder_4bit a8(.a(a[7:4]),.b(b[7:4]),.cin(c1),.s(s[7:4]),.c(c));
    
endmodule

module full_adder_4bit (
    input [3:0]a,
    input [3:0]b,
    input cin,
    output [3:0]s,
    output c

    
);
    wire c1,c2,c3;

    full_adder a3(.a(a[0]),.b(b[0]),.cin(cin),.c(c1),.s(s[0]));
    full_adder a4(.a(a[1]),.b(b[1]),.cin(c1),.c(c2),.s(s[1]));
    full_adder a5(.a(a[2]),.b(b[2]),.cin(c2),.c(c3),.s(s[2]));
    full_adder a6(.a(a[3]),.b(b[3]),.cin(c3),.c(c),.s(s[3]));
    
endmodule


module full_adder (
    input a,
    input b,
    input cin,
    output c,
    output s
);
    wire c1,c2,s1;
    assign c=c1|c2;
    
    a a1(.a(a),.b(b),.c(c1),.s(s1));
    a a2(.a(cin),.b(s1),.c(c2),.s(s));

endmodule


module a(
    input a,
    input b,
    output c,
    output s
);
assign s=a^b;
assign c=a&b;

endmodule
