`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

interface adder_if;
    logic [7:0] a;
    logic [7:0] b;
    logic [8:0] y;
endinterface

// transaction -> seq_item from uvm_sequence_item
class seq_item extends uvm_sequence_item;
    rand bit [7:0] a;
    rand bit [7:0] b;
    logic [8:0] y;

    function new(string name = "ADDER_Seq_item");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(a, UVM_DEFAULT)
        `uvm_field_int(b, UVM_DEFAULT)
        `uvm_field_int(y, UVM_DEFAULT)
    `uvm_object_utils_end

endclass

module tb_adder_uvm ();

    adder_if a_if ();

endmodule
