`timescale 1ns / 1ps


module adder (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] c
);

    assign c = a + b;

endmodule

module adder_btype (
    input  logic [31:0] a,
    input  logic [11:0] b,
    output logic [31:0] c
);

    assign c = a + {b,1'b0};

endmodule

module adder_imm_type (
    input  logic [31:0] a,
    input  logic [11:0] b,
    output logic [31:0] c
);

    assign c = a + b;

endmodule

module adder_u_type (
    input  logic [31:0] a,
    input  logic [19:0] b,
    output logic [31:0] c
);

    assign c = a + {b,12'b0};

endmodule

module adder_j_type (
    input  logic [31:0] a,
    input  logic [19:0] b,
    output logic [31:0] c
);

    assign c = a + {b,1'b0};

endmodule