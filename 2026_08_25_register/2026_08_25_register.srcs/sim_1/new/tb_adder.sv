`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`define REPEAT_CNT 100  // number of randomized transactions

interface adder_if (
    input bit clk
);

    logic [7:0] a;
    logic [7:0] b;
    logic [8:0] y;

endinterface

class seq_item extends uvm_sequence_item;
    rand bit [7:0] a;
    rand bit [7:0] b;
    logic    [8:0] y;

    function new(string name = "ADDER_Seq_item");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(a, UVM_DEFAULT)
        `uvm_field_int(b, UVM_DEFAULT)
        `uvm_field_int(y, UVM_DEFAULT)
    `uvm_object_utils_end

endclass

class adder_sequence extends uvm_sequence;

    `uvm_object_utils(adder_sequence)
    seq_item adder_seq_item;

    function new(string name = "ADDER_Sequence");
        super.new(name);
    endfunction

    task body();
        repeat (`REPEAT_CNT) begin
            adder_seq_item =
                seq_item::type_id::create("SEQ_ITEM");
            start_item(adder_seq_item);

            if (!adder_seq_item.randomize()) begin
                `uvm_fatal("SEQ", "adder_seq_item randomized fail")
            end

            `uvm_info("SEQ", $sformatf(" a = %d, b = %d", adder_seq_item.a,
                                       adder_seq_item.b), UVM_MEDIUM)
            finish_item(adder_seq_item);
        end
    endtask

endclass

class adder_driver extends uvm_driver #(seq_item);

    `uvm_component_utils(adder_driver)
    seq_item adder_seq_item;

    virtual adder_if    a_vif;

    function new(string name = "ADDER_DRV", uvm_component c = null);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual adder_if)::get(
                this, "", "a_vif", a_vif
            )) begin
            `uvm_fatal(get_name(), "unable to access adder interface")
        end
    endfunction

    task run_phase(uvm_phase phase);

        forever begin
            seq_item_port.get_next_item(adder_seq_item);

            @(posedge a_vif.clk);
            a_vif.a <= adder_seq_item.a;
            a_vif.b <= adder_seq_item.b;

            seq_item_port.item_done();  // no response : queue would overflow
        end
    endtask

endclass

class adder_monitor extends uvm_monitor;
    `uvm_component_utils(adder_monitor)

    uvm_analysis_port #(seq_item) send;
    virtual adder_if              a_vif;
    seq_item                      adder_seq_item;

    function new(string name = "ADDER_MON", uvm_component c = null);
        super.new(name, c);
        send = new("WRITE", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual adder_if)::get(
                this, "", "a_vif", a_vif
            )) begin
            `uvm_fatal(get_name(), "unable to access adder interface")
        end
    endfunction

    task run_phase(uvm_phase phase);

        forever begin
            adder_seq_item = seq_item::type_id::create("SEQ_ITEM");

            @(negedge a_vif.clk);
            adder_seq_item.a = a_vif.a;
            adder_seq_item.b = a_vif.b;
            adder_seq_item.y = a_vif.y;
            send.write(adder_seq_item);

            `uvm_info("MON", $sformatf(" a = %d, b = %d", adder_seq_item.a,
                                       adder_seq_item.b), UVM_MEDIUM)
        end
    endtask

endclass

class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard)
    uvm_analysis_imp #(seq_item, adder_scoreboard) recv;

    function new(string name = "ADDER_SCB", uvm_component c = null);
        super.new(name, c);
        recv = new("READ", this);
    endfunction

    bit [8:0] expected_data = 0;
    int pass_cnt = 0, fail_cnt = 0;

    function void write(seq_item data);

        expected_data = data.a + data.b;
        if (expected_data == data.y) begin
            `uvm_info("SCB", $sformatf(" PASS : a = %d, b = %d, y = %d",
                                       data.a, data.b, data.y), UVM_MEDIUM)
            pass_cnt++;
        end else begin
            `uvm_info("SCB", $sformatf(
                      " Fail : a = %d, b = %d, y = %d", data.a, data.b, data.y),
                      UVM_MEDIUM)
            fail_cnt++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf(
                  " === PASS : %d === \n === FAIL : %d", pass_cnt, fail_cnt),
                  UVM_MEDIUM)
        if (!(pass_cnt + fail_cnt))
            `uvm_error("SCB", "No transaction received !!!")
        else if ((pass_cnt + fail_cnt) != `REPEAT_CNT)
            `uvm_error("SCB", $sformatf(
                       "Expected %0d transactions, got %0d", `REPEAT_CNT,
                       pass_cnt + fail_cnt))
    endfunction

endclass

class adder_agent extends uvm_agent;
    `uvm_component_utils(adder_agent)

    adder_driver    adder_drv;
    adder_monitor   adder_mon;
    uvm_sequencer   #(seq_item) adder_sqr;

    function new(string name = "ADDER_AGT", uvm_component c = null);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adder_drv = adder_driver::type_id::create("DRV", this);
        adder_mon = adder_monitor::type_id::create("MON", this);
        adder_sqr = uvm_sequencer#(seq_item)::type_id::create("SQR", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        adder_drv.seq_item_port.connect(adder_sqr.seq_item_export);
    endfunction

endclass

class adder_environment extends uvm_env;
    `uvm_component_utils(adder_environment)

    adder_agent adder_agt;
    adder_scoreboard adder_scb;

    function new(string name = "ADDER_ENV", uvm_component c = null);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adder_agt = adder_agent::type_id::create("AGT", this);
        adder_scb = adder_scoreboard::type_id::create("SCB", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        adder_agt.adder_mon.send.connect(adder_scb.recv);
    endfunction

endclass

class adder_test extends uvm_test;
    `uvm_component_utils(adder_test)

    adder_sequence    adder_seq;
    adder_environment adder_env;

    function new(string name = "ADDER_TEST", uvm_component c = null);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        adder_seq = adder_sequence::type_id::create("SEQ", this);
        adder_env = adder_environment::type_id::create("ENV", this);
    endfunction

    task run_phase(uvm_phase phase);

        phase.raise_objection(this);
        adder_seq.start(adder_env.adder_agt.adder_sqr);
        #10;  // one clock : let the monitor sample the last item

        phase.drop_objection(this);
    endtask

endclass

module tb_adder_uvm ();
    logic clk = 0;
    always #5 clk = ~clk;
    adder_if a_if (clk);

    adder dut (
        .a(a_if.a),
        .b(a_if.b),
        .y(a_if.y)
    );

    initial begin
        uvm_config_db#(virtual adder_if)::set(null, "*", "a_vif", a_if);
        run_test("adder_test");
    end

endmodule
