`timescale 1ns / 1ps

// ============================================================
// adder_uvm : UVM lab DUT (combinational 8-bit adder)
//
// diff vs adder.sv
//   [1] y : [7:0] -> [8:0]
//       8b + 8b can reach 510, so the carry needs a 9th bit.
//       adder_if in tbtbtb.sv already declares y as [8:0],
//       so the old [7:0] port was both truncating and
//       width-mismatched against the interface.
//
//   [2] always_comb -> assign
//       Single unconditional expression, no branching,
//       so a continuous assign says the same thing in one line.
//       always_comb stays the right choice once if/case appears.
// ============================================================

module adder_uvm (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [8:0] y
);

    // RHS is evaluated at the width of the widest operand
    // including the LHS (9), so the carry is preserved here.
    assign y = a + b;

endmodule
