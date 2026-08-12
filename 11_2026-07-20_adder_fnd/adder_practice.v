`timescale 1ns / 1ps



module adder_fnd (
    input  [7:0] a,
    input  [7:0] b,
    input        btn_L,
    input        btn_R,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output       c
);
    wire [7:0] s;

    full_adder_8bit U_ADDER (
        .a(a), .b(b),
        .s(s),
        .c(c)
    );

     fnd_controller U_FND_CNTL (
        .fnd_in  (s),
        .digit_sel({btn_L, btn_R}),   
        .fnd_com (fnd_com),
        .fnd_data(fnd_data)
    );
endmodule

module full_adder_8bit (
    input [7:0]a,
    input [7:0]b,
    output [7:0]s,
    output c

    
);
wire c1;
full_adder_4bit a1(.a(a[3:0]),.b(b[3:0]),.cin(1'b0),.s(s[3:0]),.c(c1));
full_adder_4bit a2(.a(a[7:4]),.b(b[7:4]),.cin(c1),.s(s[7:4]),.c(c));
    
endmodule



module full_adder_4bit (
    input [3:0]a,
    input [3:0]b,
    input cin,
    output [3:0]s,
    output c

);

wire c1,c2,c3;
full_adder f1(.a(a[0]),.b(b[0]),.cin(cin),.s(s[0]),.c(c1));
full_adder f2(.a(a[1]),.b(b[1]),.cin(c1),.s(s[1]),.c(c2));
full_adder f3(.a(a[2]),.b(b[2]),.cin(c2),.s(s[2]),.c(c3));
full_adder f4(.a(a[3]),.b(b[3]),.cin(c3),.s(s[3]),.c(c));

    
endmodule



module full_adder (
    input a,
    input b,
    input cin,
    output s,
    output c
);
wire s1,c1,c2;
assign c=c1|c2;
half_adder h1(.a(a),.b(b),.c(c1),.s(s1));
half_adder h2(.a(cin),.b(s1),.c(c2),.s(s));


    
endmodule

module half_adder(
    input a,
    input b,
    output c,
    output s
    
);
// assign c=a&b;
// assign s=a^b;
xor(s,a,b);
and(c,a,b);
    
endmodule
