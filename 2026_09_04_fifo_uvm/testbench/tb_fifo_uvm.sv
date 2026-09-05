`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

//=====================================================================
// interface
//=====================================================================
interface fifo_if (
    input logic clk
);
    logic        rst_n;
    logic        push;
    logic        pop;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        full;
    logic        empty;
endinterface


//=====================================================================
// sequence item
//=====================================================================
class fifo_seq_item extends uvm_sequence_item;
    // wdata 의 corner 값(0, all-1)을 확실히 만들기 위한 종류 선택
    typedef enum bit [1:0] {WD_ZERO, WD_ONES, WD_RAND} wdata_kind_e;

    rand bit         push;
    rand bit         pop;
    rand bit  [31:0] wdata;
    rand wdata_kind_e wd_kind;

    // monitor 가 채워주는 응답 필드 (rand 아님)
    logic     [31:0] rdata;
    logic            full;
    logic            empty;

    `uvm_object_utils_begin(fifo_seq_item)
        `uvm_field_int(push,  UVM_DEFAULT)
        `uvm_field_int(pop,   UVM_DEFAULT)
        `uvm_field_int(wdata, UVM_DEFAULT)
        `uvm_field_int(rdata, UVM_DEFAULT)
        `uvm_field_int(full,  UVM_DEFAULT)
        `uvm_field_int(empty, UVM_DEFAULT)
    `uvm_object_utils_end

    // push/pop 의 비중은 sequence 쪽에서 inline constraint 로 정한다
    // (여기서 dist 를 걸어두면 sequence 의 dist 와 충돌한다)

    // wdata : 0 / all-1 을 5% 씩 강제하고 나머지는 완전 랜덤
    //  주의) wdata dist { 0 := 5, 32'hFFFF_FFFF := 5, [1:32'hFFFF_FFFE] :/ 90 }
    //        처럼 쓰면 시뮬레이터에 따라 큰 range 의 가중치가 0 으로 깔려서
    //        corner 값만 나오는 경우가 있다. kind 를 따로 뽑는 방식이 안전하다.
    constraint c_wd_kind {
        wd_kind dist {WD_ZERO := 5, WD_ONES := 5, WD_RAND := 90};
    }

    constraint c_wdata {
        (wd_kind == WD_ZERO) -> wdata == 32'h0000_0000;
        (wd_kind == WD_ONES) -> wdata == 32'hFFFF_FFFF;
        (wd_kind == WD_RAND) -> (wdata != 32'h0000_0000 && wdata != 32'hFFFF_FFFF);
    }

    function new(string name = "fifo_seq_item");
        super.new(name);        // [FIX] 세미콜론 누락
    endfunction

    function string c2string();
        return $sformatf("push=%0d, pop=%0d, wdata=%0h, rdata=%0h, full=%0d, empty=%0d",
                         push, pop, wdata, rdata, full, empty);
    endfunction
endclass


//=====================================================================
// sequences
//=====================================================================
// 1) 랜덤 mix
//    앞 절반은 push 우세(FIFO 가 차오름), 뒤 절반은 pop 우세(비워짐)
//    -> 모든 점유량(level) 에서 idle / push / pop / push+pop 이 골고루 나온다
class fifo_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_sequence)   // [FIX] _begin 만 쓰고 _end 가 없었음

    fifo_seq_item f_item;
    int unsigned  count = 300;

    function new(string name = "fifo_sequence");   // [FIX] 세미콜론 누락
        super.new(name);
    endfunction

    virtual task body();
        bit ok;

        for (int i = 0; i < count; i++) begin
            f_item = fifo_seq_item::type_id::create("f_item");

            start_item(f_item);
            if (i < (count / 2))
                ok = f_item.randomize() with {
                    push dist {1 := 70, 0 := 30};
                    pop  dist {1 := 40, 0 := 60};
                };
            else
                ok = f_item.randomize() with {
                    push dist {1 := 40, 0 := 60};
                    pop  dist {1 := 70, 0 := 30};
                };
            if (!ok) `uvm_fatal("fifo_sequence", "randomize fail")
            finish_item(f_item);

            `uvm_info("fifo_seq", f_item.c2string(), UVM_HIGH)  // [FIX] f_itme 오타
        end
    endtask
endclass

// 2) push 만 : full 까지 채우고 overflow 까지 밀어본다
class fifo_push_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_push_sequence)

    fifo_seq_item f_item;
    int unsigned  count = 40;   // DEPTH(32) 보다 크게

    function new(string name = "fifo_push_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat (count) begin
            f_item = fifo_seq_item::type_id::create("f_item");
            start_item(f_item);
            if (!f_item.randomize() with {push == 1'b1; pop == 1'b0;})
                `uvm_fatal("fifo_push_seq", "randomize fail")
            finish_item(f_item);
            `uvm_info("fifo_push_seq", f_item.c2string(), UVM_HIGH)
        end
    endtask
endclass

// 3) pop 만 : empty 까지 비우고 underflow 까지 밀어본다
class fifo_pop_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_pop_sequence)

    fifo_seq_item f_item;
    int unsigned  count = 40;

    function new(string name = "fifo_pop_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat (count) begin
            f_item = fifo_seq_item::type_id::create("f_item");
            start_item(f_item);
            if (!f_item.randomize() with {push == 1'b0; pop == 1'b1;})
                `uvm_fatal("fifo_pop_seq", "randomize fail")
            finish_item(f_item);
            `uvm_info("fifo_pop_seq", f_item.c2string(), UVM_HIGH)
        end
    endtask
endclass

// 4) push & pop 동시 : 두 포인터가 같이 움직이는 경로
class fifo_push_pop_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_push_pop_sequence)

    fifo_seq_item f_item;
    int unsigned  count = 40;

    function new(string name = "fifo_push_pop_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat (count) begin
            f_item = fifo_seq_item::type_id::create("f_item");
            start_item(f_item);
            if (!f_item.randomize() with {push == 1'b1; pop == 1'b1;})
                `uvm_fatal("fifo_push_pop_seq", "randomize fail")
            finish_item(f_item);
            `uvm_info("fifo_push_pop_seq", f_item.c2string(), UVM_HIGH)
        end
    endtask
endclass

// 5) corner walk : full / empty 상태에서 4가지 동작을 하나씩 직접 찔러본다
//    (랜덤만으로는 "full 인데 idle", "full 인데 pop" 같은 조합이 잘 안 나온다)
class fifo_corner_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_corner_sequence)

    fifo_seq_item f_item;
    localparam int DEPTH = 32;

    function new(string name = "fifo_corner_sequence");
        super.new(name);
    endfunction

    // push/pop 을 지정해서 한 cycle 구동
    protected task do_op(bit p, bit q);
        f_item = fifo_seq_item::type_id::create("f_item");
        start_item(f_item);
        if (!f_item.randomize() with {push == p; pop == q;})
            `uvm_fatal("fifo_corner_seq", "randomize fail")
        finish_item(f_item);
        `uvm_info("fifo_corner_seq", f_item.c2string(), UVM_HIGH)
    endtask

    virtual task body();
        // ---------- FULL corner ----------
        repeat (DEPTH) do_op(1'b1, 1'b0);   // 가득 채운다
        do_op(1'b0, 1'b0);                  // full + idle
        do_op(1'b1, 1'b0);                  // full + push      (overflow, 무시되어야 함)
        do_op(1'b1, 1'b1);                  // full + push&pop  (pop 만 수행)
        do_op(1'b1, 1'b0);                  // 다시 full 로
        do_op(1'b0, 1'b1);                  // full + pop

        // ---------- EMPTY corner ----------
        repeat (DEPTH) do_op(1'b0, 1'b1);   // 전부 비운다
        do_op(1'b0, 1'b0);                  // empty + idle
        do_op(1'b0, 1'b1);                  // empty + pop      (underflow, 무시되어야 함)
        do_op(1'b1, 1'b1);                  // empty + push&pop (push 만 수행)
        do_op(1'b0, 1'b1);                  // 다시 empty 로
        do_op(1'b1, 1'b0);                  // empty + push
    endtask
endclass


//=====================================================================
// driver
//=====================================================================
class fifo_driver extends uvm_driver #(fifo_seq_item);
    `uvm_component_utils(fifo_driver)

    virtual fifo_if f_if;
    fifo_seq_item   f_item;

    function new(string name = "fifo_drv", uvm_component c = null);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "f_if", f_if))
            `uvm_fatal("fifo_drv", "build_phase : cant access virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        // reset 구간 동안의 초기값
        f_if.push  <= 1'b0;
        f_if.pop   <= 1'b0;
        f_if.wdata <= 32'h0;

        wait (f_if.rst_n === 1'b1);

        forever begin
            seq_item_port.get_next_item(f_item);

            @(negedge f_if.clk);      // posedge 를 피해서 구동 -> race 방지
            f_if.push  <= f_item.push;
            f_if.pop   <= f_item.pop;
            f_if.wdata <= f_item.wdata;

            seq_item_port.item_done();
        end
    endtask
endclass


//=====================================================================
// monitor
//=====================================================================
class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)

    uvm_analysis_port #(fifo_seq_item) send;
    virtual fifo_if f_if;
    fifo_seq_item   f_item;

    function new(string name = "fifo_mon", uvm_component c = null);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_if)::get(this, "", "f_if", f_if))
            `uvm_fatal("fifo_mon", "build_phase : cant access virtual interface")
        send = new("send", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            @(posedge f_if.clk);
            // [주의] ram TB 처럼 #1 을 주면 안 된다.
            //   rdata / full / empty 는 이번 edge 에서 바뀌므로
            //   #1 뒤에 읽으면 "다음 상태" 를 보게 된다.
            //   edge 직전 값(= 이번 transaction 이 실제로 사용한 값)을 그대로 샘플한다.
            if (f_if.rst_n !== 1'b1) continue;
            if ($isunknown({f_if.push, f_if.pop})) continue;

            f_item = fifo_seq_item::type_id::create("f_item", this);

            f_item.push  = f_if.push;
            f_item.pop   = f_if.pop;
            f_item.wdata = f_if.wdata;
            f_item.rdata = f_if.rdata;   // pop 되는 head 값
            f_item.full  = f_if.full;
            f_item.empty = f_if.empty;

            send.write(f_item);
        end
    endtask
endclass


//=====================================================================
// agent
//=====================================================================
class fifo_agent extends uvm_agent;
    `uvm_component_utils(fifo_agent)

    fifo_driver                    fifo_drv;
    fifo_monitor                   fifo_mon;
    uvm_sequencer #(fifo_seq_item) fifo_sqr;

    function new(string name = "fifo_agt", uvm_component c = null);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_drv = fifo_driver::type_id::create("DRV", this);
        fifo_mon = fifo_monitor::type_id::create("MON", this);
        fifo_sqr = uvm_sequencer#(fifo_seq_item)::type_id::create("SQR", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        fifo_drv.seq_item_port.connect(fifo_sqr.seq_item_export);
    endfunction
endclass


//=====================================================================
// scoreboard : queue 로 만든 golden FIFO 모델
//=====================================================================
class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp #(fifo_seq_item, fifo_scoreboard) recv;

    localparam int DEPTH = 32;

    logic [31:0] ref_q[$];
    int          pass_cnt;
    int          fail_cnt;

    function new(string name = "fifo_scb", uvm_component p = null);
        super.new(name, p);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv = new("recv", this);
    endfunction

    virtual function void write(fifo_seq_item f_item);
        bit          exp_full, exp_empty;
        bit          do_push, do_pop;
        logic [31:0] exp_data;

        exp_empty = (ref_q.size() == 0);
        exp_full  = (ref_q.size() == DEPTH);

        // 1) flag check
        if (f_item.full !== exp_full) begin
            `uvm_error("SCB", $sformatf("\nFULL mismatch : dut=%0d exp=%0d (size=%0d)",
                                        f_item.full, exp_full, ref_q.size()))
            fail_cnt++;
        end
        if (f_item.empty !== exp_empty) begin
            `uvm_error("SCB", $sformatf("\nEMPTY mismatch : dut=%0d exp=%0d (size=%0d)",
                                        f_item.empty, exp_empty, ref_q.size()))
            fail_cnt++;
        end

        // 2) DUT 가 실제로 수행하는 동작 (full/empty 일 때는 무시됨)
        do_pop  = f_item.pop  && !exp_empty;
        do_push = f_item.push && !exp_full;

        // 3) data check : pop 되는 값은 queue 의 head 여야 한다
        if (do_pop) begin
            exp_data = ref_q[0];
            if (f_item.rdata === exp_data) begin
                `uvm_info("SCB", "\nPop Pass !!", UVM_HIGH)
                pass_cnt++;
            end else begin
                `uvm_error("SCB", $sformatf("\nPop Fail !! exp=%0h got=%0h",
                                            exp_data, f_item.rdata))
                `uvm_info("SCB", f_item.c2string(), UVM_NONE)
                fail_cnt++;
            end
            void'(ref_q.pop_front());
        end

        if (do_push) begin
            ref_q.push_back(f_item.wdata);
            pass_cnt++;
        end

        // 4) overflow / underflow 는 무시되어야 정상 (에러 아님, 로그만)
        if (f_item.push && exp_full)
            `uvm_info("SCB", "push ignored (FIFO full)", UVM_HIGH)
        if (f_item.pop && exp_empty)
            `uvm_info("SCB", "pop ignored (FIFO empty)", UVM_HIGH)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SCB", "\n*************************", UVM_NONE)
        `uvm_info("SCB", $sformatf("** pass count = %4d **", pass_cnt), UVM_NONE)
        `uvm_info("SCB", $sformatf("** fail count = %4d **", fail_cnt), UVM_NONE)
        `uvm_info("SCB", "\n*************************", UVM_NONE)
    endfunction
endclass


//=====================================================================
// functional coverage
//=====================================================================
class fifo_coverage extends uvm_subscriber #(fifo_seq_item);
    `uvm_component_utils(fifo_coverage)

    localparam int DEPTH = 32;

    fifo_seq_item f_item;
    int           level;   // scoreboard 와 같은 규칙으로 추적하는 FIFO 점유량

    covergroup fifo_cg;
        option.per_instance = 1;
        option.name         = "fifo_cg";

        cp_push: coverpoint f_item.push {
            bins no_push = {1'b0};
            bins push    = {1'b1};
        }

        cp_pop: coverpoint f_item.pop {
            bins no_pop = {1'b0};
            bins pop    = {1'b1};
        }

        // push/pop 조합 4가지 : DUT case 문의 모든 branch
        cp_op: coverpoint {f_item.push, f_item.pop} {
            bins idle      = {2'b00};
            bins pop_only  = {2'b01};
            bins push_only = {2'b10};
            bins push_pop  = {2'b11};
        }

        cp_full: coverpoint f_item.full {
            bins not_full = {1'b0};
            bins full     = {1'b1};
        }

        cp_empty: coverpoint f_item.empty {
            bins not_empty = {1'b0};
            bins empty     = {1'b1};
        }

        // 32bit 데이터는 값마다 bin 을 만들 수 없으므로 구간 + corner 로
        cp_wdata: coverpoint f_item.wdata {
            bins zero     = {32'h0000_0000};
            bins low      = {[32'h0000_0001 : 32'h3FFF_FFFF]};
            bins mid      = {[32'h4000_0000 : 32'hBFFF_FFFF]};
            bins high     = {[32'hC000_0000 : 32'hFFFF_FFFE]};
            bins all_ones = {32'hFFFF_FFFF};
        }

        // FIFO 점유량 (0 ~ DEPTH)
        cp_level: coverpoint level {
            bins empty_lvl = {0};
            bins low_lvl   = {[1:7]};
            bins mid_lvl   = {[8:23]};
            bins high_lvl  = {[24:31]};
            bins full_lvl  = {32};
        }

        // corner : full 일 때 push(overflow), empty 일 때 pop(underflow) 까지 커버
        cx_op_full  : cross cp_op, cp_full;
        cx_op_empty : cross cp_op, cp_empty;
        cx_op_level : cross cp_op, cp_level;
    endgroup

    function new(string name = "fifo_cov", uvm_component p = null);
        super.new(name, p);
        fifo_cg = new();      // covergroup 은 반드시 생성해야 sample 이 동작한다
        level   = 0;
    endfunction

    virtual function void write(fifo_seq_item t);
        bit do_push, do_pop;

        f_item = t;

        // 이번 transaction 이 적용되기 "전" 상태로 sampling
        fifo_cg.sample();

        // 다음 sample 을 위한 점유량 갱신
        // (두 판정 모두 "이전 level" 기준이어야 DUT 와 일치한다.
        //  full 상태의 push+pop 은 pop 만, empty 상태의 push+pop 은 push 만)
        do_pop  = t.pop  && (level > 0);
        do_push = t.push && (level < DEPTH);
        if (do_pop)  level--;
        if (do_push) level++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", "\n*************************", UVM_NONE)
        `uvm_info("COV", $sformatf("** functional coverage = %3.2f %% **",
                                   fifo_cg.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", "\n*************************", UVM_NONE)

        // 어느 coverpoint 에 구멍이 있는지 바로 보이도록 항목별로도 출력
        `uvm_info("COV", $sformatf("   cp_push     = %3.2f %%", fifo_cg.cp_push.get_inst_coverage()),     UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_pop      = %3.2f %%", fifo_cg.cp_pop.get_inst_coverage()),      UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_op       = %3.2f %%", fifo_cg.cp_op.get_inst_coverage()),       UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_full     = %3.2f %%", fifo_cg.cp_full.get_inst_coverage()),     UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_empty    = %3.2f %%", fifo_cg.cp_empty.get_inst_coverage()),    UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_wdata    = %3.2f %%", fifo_cg.cp_wdata.get_inst_coverage()),    UVM_NONE)
        `uvm_info("COV", $sformatf("   cp_level    = %3.2f %%", fifo_cg.cp_level.get_inst_coverage()),    UVM_NONE)
        `uvm_info("COV", $sformatf("   cx_op_full  = %3.2f %%", fifo_cg.cx_op_full.get_inst_coverage()),  UVM_NONE)
        `uvm_info("COV", $sformatf("   cx_op_empty = %3.2f %%", fifo_cg.cx_op_empty.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("   cx_op_level = %3.2f %%", fifo_cg.cx_op_level.get_inst_coverage()), UVM_NONE)
    endfunction
endclass


//=====================================================================
// environment
//=====================================================================
class fifo_environment extends uvm_env;
    `uvm_component_utils(fifo_environment)

    fifo_agent      fifo_agt;
    fifo_scoreboard fifo_scb;
    fifo_coverage   fifo_cov;

    function new(string name = "fifo_env", uvm_component p = null);
        super.new(name, p);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_agt = fifo_agent::type_id::create("AGT", this);
        fifo_scb = fifo_scoreboard::type_id::create("SCB", this);
        fifo_cov = fifo_coverage::type_id::create("COV", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        fifo_agt.fifo_mon.send.connect(fifo_scb.recv);
        fifo_agt.fifo_mon.send.connect(fifo_cov.analysis_export);
    endfunction
endclass


//=====================================================================
// test
//=====================================================================
class fifo_test extends uvm_test;
    `uvm_component_utils(fifo_test)

    fifo_environment       fifo_env;
    fifo_sequence          rand_seq;
    fifo_push_sequence     push_seq;
    fifo_pop_sequence      pop_seq;
    fifo_push_pop_sequence pushpop_seq;
    fifo_corner_sequence   corner_seq;

    function new(string name = "fifo_test", uvm_component c = null);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        fifo_env    = fifo_environment::type_id::create("ENV", this);
        rand_seq    = fifo_sequence::type_id::create("RAND_SEQ");
        push_seq    = fifo_push_sequence::type_id::create("PUSH_SEQ");
        pop_seq     = fifo_pop_sequence::type_id::create("POP_SEQ");
        pushpop_seq = fifo_push_pop_sequence::type_id::create("PUSHPOP_SEQ");
        corner_seq  = fifo_corner_sequence::type_id::create("CORNER_SEQ");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);

        // full / empty / overflow / underflow 를 순서대로 확실히 때린다
        push_seq.start(fifo_env.fifo_agt.fifo_sqr);      // 채우고 overflow
        pushpop_seq.start(fifo_env.fifo_agt.fifo_sqr);   // full 부근에서 동시 동작
        pop_seq.start(fifo_env.fifo_agt.fifo_sqr);       // 비우고 underflow
        pushpop_seq.start(fifo_env.fifo_agt.fifo_sqr);   // empty 부근에서 동시 동작
        corner_seq.start(fifo_env.fifo_agt.fifo_sqr);    // full/empty 에서 4가지 동작
        rand_seq.start(fifo_env.fifo_agt.fifo_sqr);      // 랜덤 mix

        #100;   // 마지막 transaction 이 monitor 에 잡힐 시간
        phase.drop_objection(this);
    endtask
endclass


//=====================================================================
// top
//=====================================================================
module tb_fifo_uvm ();

    logic clk;
    logic rst_n;

    fifo_if f_if (clk);

    assign f_if.rst_n = rst_n;

    fifo #(
        .DATA_WIDTH(32),
        .DEPTH     (32)
    ) dut (
        .clk  (clk),
        .rst_n(f_if.rst_n),
        .push (f_if.push),
        .pop  (f_if.pop),
        .wdata(f_if.wdata),
        .rdata(f_if.rdata),
        .full (f_if.full),
        .empty(f_if.empty)
    );

    always #5 clk = ~clk;

    // FSDB waveform dump for Verdi
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_fifo_uvm);
        $fsdbDumpMDA(0, tb_fifo_uvm);   // register_file 같은 메모리 배열까지 덤프
    end

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "f_if", f_if);
        run_test("fifo_test");
    end

endmodule
