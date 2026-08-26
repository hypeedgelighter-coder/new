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

//sequence,(generator)
//randomize,seq_item(transaction object)
class adder_sequence extends uvm_sequence;
`uvm _object_utils(adder_sequence)
    seq_item adder_seq_item;

    function new(string name ="ADDER_Sequence");
        super.new(name);
    endfunction

    task body();
        adder_seq_item=seq_item::type_id::create("SEQ_ITEM");//transaction new()
        start_item(adder_seq_item);
        finish_itme(adder_seq_item);
        //randomize
        if(adder_seq_item.randomize())begin
            `uvm_fatal("SEQ,"adder_seq_item randomized fail")
        end
        `uvm_info("SEQ","")
    finish_item(adder_seq_item);
    endtask
endclass

module tbtbtb ();
    logic clk=0;
    always #5 clk=~clk;
    adder_if a_if ();

endmodule
