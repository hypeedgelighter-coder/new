`include "uvm_macros.svh"
`include


interface counter_if(input clk);
  logic       rst_n;
  logic       enable;
  logic [2:0] counter;
  logic       o_tick;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output rst_n;
    output enable;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n;
    input enable;
    input counter;
    input o_tick;
  endclocking

  modport drv_mb (clocking drv_cb, input clk);
  modport mon_mb (clocking mon_cb, input clk);

endinterface

class counter_seq_item extends uvm_sequence_item;
  rand bit       enable;
       bit       rst_n;
       bit [2:0] counter;
       bit       o_tick;
