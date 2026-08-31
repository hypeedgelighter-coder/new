"""Part V - 실습 프로젝트 (adder / register UVM 환경 전체 구축)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART V",
    "title": "실습 프로젝트",
    "blurb": "지금까지의 문법과 개념을 하나의 동작하는 환경으로 조립합니다. "
             "가산기로 전체 흐름을 익힌 뒤 레지스터로 시간 개념을 더하고, "
             "마지막에 커버리지와 assertion 까지 붙여 완성합니다. "
             "모든 코드는 Vivado 2020.2 에서 그대로 동작합니다.",
    "items": [
        "32장 프로젝트 준비와 파일 구성",
        "33장 실습 1 - 가산기 UVM 환경 (조합 논리)",
        "34장 실습 2 - 레지스터 UVM 환경 (순차 논리)",
        "35장 실습 3 - 스코어보드와 커버리지 추가",
        "36장 실습 4 - assertion 과 에러 주입",
        "37장 Vivado 실행과 파형 분석",
        "38장 디버깅 실전",
    ],
}


# ==========================================================================
CH32 = {
    "number": "CHAPTER 32",
    "title": "프로젝트 준비와 파일 구성",
    "goals": [
        "UVM 프로젝트의 표준 파일 구조를 안다",
        "package 로 클래스를 묶는다",
        "컴파일 순서 문제를 해결한다",
        "Vivado 에서 UVM 을 활성화한다",
    ],
    "body": [
        lead("UVM 환경은 파일이 열 개를 쉽게 넘습니다. 처음부터 구조를 "
             "잡아두지 않으면 컴파일 순서 문제로 며칠을 낭비하게 됩니다."),

        h2("32.1  표준 파일 구조"),
        code("directory.txt", """
project.srcs/
  sources_1/new/
      adder_uvm.sv           DUT
  sim_1/new/
      adder_if.sv            interface
      adder_pkg.sv           클래스 전부를 담은 package
      tb_adder.sv            top module

  또는 클래스를 파일로 나눌 때:
  sim_1/new/
      adder_pkg.sv           `include 만 모아놓은 package
      seq_item.svh
      sequence.svh
      driver.svh
      monitor.svh
      agent.svh
      scoreboard.svh
      env.svh
      test.svh
"""),
        key("interface 는 package 밖에",
            "interface 는 정적 계층에 속하므로 package 안에 넣을 수 없습니다. "
            "별도 파일에 두고 package 보다 먼저 컴파일해야 합니다."),

        h2("32.2  package 구성"),
        code("adder_pkg.sv", """
package adder_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 순서가 중요하다: 참조되는 것이 먼저
    `include "seq_item.svh"
    `include "sequence.svh"
    `include "driver.svh"
    `include "monitor.svh"
    `include "sequencer.svh"
    `include "agent.svh"
    `include "scoreboard.svh"
    `include "coverage.svh"
    `include "env.svh"
    `include "test.svh"

endpackage
"""),
        code("include_order.txt", """
컴파일 순서 규칙

  1. seq_item      아무것도 참조하지 않음
  2. sequence      seq_item 참조
  3. driver        seq_item 참조
  4. monitor       seq_item 참조
  5. agent         driver, monitor, sequencer 참조
  6. scoreboard    seq_item 참조
  7. env           agent, scoreboard 참조
  8. test          env, sequence 참조

  -> 참조 그래프의 위상 정렬 순서
"""),
        trap("전방 참조 문제",
             "env 가 agent 를 참조하는데 agent 가 나중에 include 되면 "
             "'type not found' 에러가 납니다. UVM 은 typedef 로 "
             "전방 선언을 할 수 있지만, include 순서를 맞추는 것이 "
             "훨씬 간단합니다."),

        h2("32.3  top module"),
        code("tb_adder.sv", """
`timescale 1ns / 1ps

module tb_adder;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import adder_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;           // 100MHz

    adder_if a_if (clk);            // interface 인스턴스

    adder_uvm dut (                 // DUT 연결
        .a(a_if.a),
        .b(a_if.b),
        .y(a_if.y)
    );

    initial begin
        // vif 를 config_db 에 넣고 테스트 시작
        uvm_config_db #(virtual adder_if)::set(null, "*", "vif", a_if);
        run_test();                 // +UVM_TESTNAME 으로 지정
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_adder);
    end

endmodule
"""),
        note("run_test() 인자",
             "인자를 비우면 명령행의 +UVM_TESTNAME=... 을 씁니다. "
             "run_test(\"random_test\") 로 못 박으면 테스트를 바꿀 때마다 "
             "재컴파일해야 하므로, 인자를 비우는 편이 낫습니다.",
             "info"),

        h2("32.4  Vivado 에서 UVM 활성화"),
        ol("Simulation Settings 를 연다 (Flow Navigator > Simulation)",
           "xsim.compile.xvlog.more_options 에 -L uvm 추가",
           "xsim.elaborate.xelab.more_options 에 -L uvm 추가",
           "시뮬레이션 top 을 tb_adder 로 지정",
           "Run Simulation 실행"),
        code("vivado_tcl.tcl", """
# Tcl 콘솔에서 설정
set_property -name {xsim.compile.xvlog.more_options} \\
             -value {-L uvm} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} \\
             -value {-L uvm} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} \\
             -value {-testplusarg UVM_TESTNAME=random_test} \\
             -objects [get_filesets sim_1]

set_property top tb_adder [get_filesets sim_1]
launch_simulation
"""),
        code("commandline.sh", """
# 명령행에서 직접 (xvlog/xelab/xsim)
xvlog -sv -L uvm adder_if.sv adder_pkg.sv tb_adder.sv
xelab -L uvm -debug typical tb_adder -s tb_snapshot
xsim tb_snapshot -R -testplusarg UVM_TESTNAME=random_test \\
                    -testplusarg UVM_VERBOSITY=UVM_MEDIUM
"""),
        trap("-L uvm 을 빼먹으면",
             "'uvm_pkg not found' 또는 'uvm_macros.svh not found' 에러가 "
             "납니다. compile 과 elaborate 양쪽에 모두 넣어야 합니다."),

        h2("32.5  최소 동작 확인"),
        p("본격적으로 만들기 전에, 껍데기만으로 컴파일과 실행이 되는지 "
          "확인하는 것이 시간을 아낍니다."),
        code("smoke_test.sv", """
class smoke_test extends uvm_test;
    `uvm_component_utils(smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("SMOKE", "UVM 환경이 동작합니다", UVM_NONE)
        #100;
        phase.drop_objection(this);
    endtask
endclass
"""),
        p("이것만 돌려서 UVM_INFO 가 찍히면 툴 설정은 끝난 것입니다. "
          "이제 내용을 채우면 됩니다."),

        h2("32.6  실습"),
        lab("과제 32-A",
            "위 구조로 프로젝트를 만들고 smoke_test 를 실행해 "
            "UVM 배너와 메시지가 출력되는지 확인하세요."),
        quiz("interface 를 package 안에 넣으면?",
             ["① 잘 동작한다",
              "② 컴파일 에러 - interface 는 정적 계층이라 package 에 못 들어간다",
              "③ 경고만 나온다",
              "④ virtual 을 붙이면 된다"],
             "② — package 는 클래스와 typedef 같은 것만 담습니다. "
             "interface, module 은 별도 파일에 두어야 합니다."),
    ],
}


# ==========================================================================
CH33 = {
    "number": "CHAPTER 33",
    "title": "실습 1 - 가산기 UVM 환경",
    "goals": [
        "조합 논리 DUT 의 전체 환경을 구축한다",
        "각 파일의 역할을 코드로 확인한다",
        "시뮬레이션을 돌려 로그를 읽는다",
        "환경이 실제로 버그를 잡는지 확인한다",
    ],
    "body": [
        lead("가장 단순한 DUT 로 UVM 전체를 한 바퀴 돕니다. "
             "조합 논리라 타이밍 고민이 없어 구조에 집중할 수 있습니다."),

        h2("33.1  DUT"),
        code("adder_uvm.sv", """
`timescale 1ns / 1ps

module adder_uvm (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [8:0] y      // 9비트: 255+255=510
);
    assign y = a + b;
endmodule
"""),

        h2("33.2  interface"),
        code("adder_if.sv", """
interface adder_if (input logic clk);
    logic [7:0] a;
    logic [7:0] b;
    logic [8:0] y;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output a, b;
        input  y;
    endclocking

    modport tb (clocking cb);
endinterface
"""),

        h2("33.3  sequence_item"),
        code("seq_item.svh", """
class seq_item extends uvm_sequence_item;

    rand bit [7:0] a;
    rand bit [7:0] b;
    bit [8:0]      y;          // DUT 응답 - rand 아님
    bit [8:0]      expected;

    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(a, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(b, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(y, UVM_DEFAULT | UVM_DEC | UVM_NOCOMPARE)
    `uvm_object_utils_end

    function new(string name = "seq_item");
        super.new(name);
    endfunction

    function void post_randomize();
        expected = a + b;      // 기대값을 스스로 계산
    endfunction

    function string convert2string();
        return $sformatf("a=%3d b=%3d y=%3d exp=%3d", a, b, y, expected);
    endfunction
endclass
"""),

        h2("33.4  sequence"),
        code("sequence.svh", """
class adder_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(adder_sequence)

    rand int unsigned n = 20;
    constraint c_n { n inside {[10:100]}; }

    function new(string name = "adder_sequence");
        super.new(name);
    endfunction

    virtual task body();
        seq_item item;
        `uvm_info("SEQ", $sformatf("%0d개 아이템 생성 시작", n), UVM_LOW)
        repeat (n) begin
            item = seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_error("SEQ", "randomize 실패")
            finish_item(item);
        end
    endtask
endclass

// 캐리 경로를 집중 시험하는 시퀀스
class carry_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(carry_sequence)

    function new(string name = "carry_sequence");
        super.new(name);
    endfunction

    virtual task body();
        seq_item item;
        repeat (20) begin
            item = seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize() with { a + b > 255; })
                `uvm_error("SEQ", "randomize 실패")
            finish_item(item);
        end
    endtask
endclass
"""),

        h2("33.5  driver"),
        code("driver.svh", """
class adder_driver extends uvm_driver #(seq_item);
    `uvm_component_utils(adder_driver)

    virtual adder_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual adder_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 없음: ", get_full_name()})
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.cb.a <= '0;
        vif.cb.b <= '0;
        forever begin
            seq_item_port.get_next_item(req);
            @(vif.cb);
            vif.cb.a <= req.a;
            vif.cb.b <= req.b;
            `uvm_info("DRV", req.convert2string(), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask
endclass
"""),

        h2("33.6  monitor"),
        code("monitor.svh", """
class adder_monitor extends uvm_monitor;
    `uvm_component_utils(adder_monitor)

    virtual adder_if vif;
    uvm_analysis_port #(seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual adder_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 없음: ", get_full_name()})
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            @(vif.cb);
            item = seq_item::type_id::create("mon_item");
            item.a        = vif.cb.a;      // 읽기만 한다
            item.b        = vif.cb.b;
            item.y        = vif.cb.y;
            item.expected = vif.cb.a + vif.cb.b;
            ap.write(item);
            `uvm_info("MON", item.convert2string(), UVM_HIGH)
        end
    endtask
endclass
"""),
        note("모니터의 expected",
             "여기서는 모니터가 기대값을 직접 계산했습니다. "
             "레퍼런스 모델이 단순해서 가능한 것이고, 복잡한 DUT 라면 "
             "스코어보드에 두는 편이 맞습니다.",
             "info"),

        h2("33.7  scoreboard"),
        code("scoreboard.svh", """
class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard)

    uvm_analysis_imp #(seq_item, adder_scoreboard) item_export;

    int unsigned n_match, n_mismatch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    virtual function void write(seq_item t);
        bit [8:0] exp = t.a + t.b;
        if (t.y !== exp) begin
            n_mismatch++;
            `uvm_error("SCB", $sformatf(
                "불일치  a=%0d b=%0d  기대=%0d(0x%03h)  실제=%0d(0x%03h)  차이=%0d",
                t.a, t.b, exp, exp, t.y, t.y, $signed(t.y) - $signed(exp)))
        end else begin
            n_match++;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", $sformatf("일치 %0d / 불일치 %0d",
                   n_match, n_mismatch), UVM_NONE)
        if (n_match + n_mismatch == 0)
            `uvm_error("SCB", "비교가 한 번도 수행되지 않았습니다")
    endfunction
endclass
"""),

        h2("33.8  agent · env · test"),
        code("agent.svh", """
class adder_agent extends uvm_agent;
    `uvm_component_utils(adder_agent)

    uvm_sequencer #(seq_item) seqr;
    adder_driver              drv;
    adder_monitor             mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = adder_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            seqr = uvm_sequencer#(seq_item)::type_id::create("seqr", this);
            drv  = adder_driver::type_id::create("drv", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
"""),
        code("env.svh", """
class adder_env extends uvm_env;
    `uvm_component_utils(adder_env)

    adder_agent      agt;
    adder_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = adder_agent     ::type_id::create("agt", this);
        scb = adder_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.item_export);
    endfunction
endclass
"""),
        code("test.svh", """
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    adder_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = adder_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();       // 계층 확인
    endfunction
endclass

class random_test extends base_test;
    `uvm_component_utils(random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        adder_sequence seq;
        seq = adder_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.seqr);
        #100;                            // 마지막 트랜잭션 관측 여유
        phase.drop_objection(this);
    endtask
endclass

class carry_test extends base_test;
    `uvm_component_utils(carry_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        carry_sequence seq;
        seq = carry_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.seqr);
        #100;
        phase.drop_objection(this);
    endtask
endclass
"""),
        tip("#100 을 넣는 이유",
            "마지막 아이템을 driver 가 인가한 직후 objection 을 내리면 "
            "monitor 가 그 결과를 관측하기 전에 시뮬레이션이 끝납니다. "
            "여유 시간을 두거나, 더 정확하게는 scoreboard 가 "
            "objection 을 들도록 만듭니다."),

        h2("33.9  실행과 로그"),
        code("expected_log.txt", """
UVM_INFO @ 0: reporter [RNTST] Running test random_test...
------------------------------------------------------
Name              Type                    Size  Value
------------------------------------------------------
uvm_test_top      random_test             -     @335
  env             adder_env               -     @346
    agt           adder_agent             -     @357
      mon         adder_monitor           -     @441
      seqr        uvm_sequencer           -     @375
      drv         adder_driver            -     @408
    scb           adder_scoreboard        -     @368
------------------------------------------------------

UVM_INFO @ 0: uvm_test_top.env.agt.seqr@@seq [SEQ] 20개 아이템 생성 시작
UVM_INFO @ 315: uvm_test_top.env.scb [SCB] 일치 20 / 불일치 0

--- UVM Report Summary ---
UVM_INFO :   23
UVM_ERROR:    0
UVM_FATAL:    0
"""),
        key("print_topology 를 꼭 켜라",
            "계층이 예상대로 만들어졌는지 한눈에 보입니다. "
            "컴포넌트가 빠졌거나 이름이 틀렸으면 여기서 바로 드러납니다."),

        h2("33.10  환경이 버그를 잡는지 확인"),
        lab("과제 33-A",
            "DUT 의 출력 폭을 [8:0] 에서 [7:0] 로 되돌린 뒤 carry_test 를 "
            "실행하세요. 스코어보드가 불일치를 몇 건 잡는지, "
            "그리고 차이값이 항상 256 인지 확인하세요."),
        lab("과제 33-B",
            "DUT 의 assign y = a + b; 를 a - b; 로 바꿔 스코어보드가 "
            "전부 불일치로 잡는지 확인하세요."),
        lab("과제 33-C",
            "monitor 의 ap.write(item) 을 주석 처리하고 "
            "report_phase 의 '비교 0회' 검사가 동작하는지 확인하세요."),
    ],
}


# ==========================================================================
CH34 = {
    "number": "CHAPTER 34",
    "title": "실습 2 - 레지스터 UVM 환경",
    "goals": [
        "순차 논리 DUT 의 타이밍을 다룬다",
        "리셋 시퀀스를 구현한다",
        "파이프라인 지연을 스코어보드로 처리한다",
        "clocking block 의 효과를 확인한다",
    ],
    "body": [
        lead("가산기와 달리 레지스터는 클럭과 리셋이 있습니다. "
             "'언제 인가하고 언제 읽는가'가 문제가 되며, "
             "이것이 실제 검증에서 시간을 가장 많이 잡아먹는 부분입니다."),

        h2("34.1  DUT"),
        code("uvm_register.sv", """
`timescale 1ns / 1ps

module uvm_register (
    input  logic        clk,
    input  logic        resetn,
    input  logic        en,
    input  logic [31:0] d,
    output logic [31:0] q
);
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)   q <= 32'h0;
        else if (en)   q <= d;
    end
endmodule
"""),

        h2("34.2  interface"),
        code("reg_if.sv", """
interface reg_if (input logic clk);
    logic        resetn;
    logic        en;
    logic [31:0] d;
    logic [31:0] q;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output en, d;
        input  q;
    endclocking

    modport dut (input clk, resetn, en, d, output q);
    modport tb  (clocking cb, output resetn);
endinterface
"""),
        key("clocking block 이 해결하는 것",
            "input #1step 은 클럭 엣지 직전의 안정된 값을 읽습니다. "
            "NBA 영역에서 q 가 갱신되기 전 값이 아니라, "
            "'이 엣지에서 DUT 가 본 것과 같은 값'을 봅니다. "
            "#1 같은 임시방편이 필요 없어집니다."),

        h2("34.3  sequence_item 과 시퀀스"),
        code("reg_seq_item.svh", """
class reg_item extends uvm_sequence_item;
    rand bit        en;
    rand bit [31:0] d;
    bit [31:0]      q;

    `uvm_object_utils_begin(reg_item)
        `uvm_field_int(en, UVM_DEFAULT)
        `uvm_field_int(d,  UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(q,  UVM_DEFAULT | UVM_HEX | UVM_NOCOMPARE)
    `uvm_object_utils_end

    function new(string name = "reg_item");
        super.new(name);
    endfunction

    // en=1 이 자주 나오도록
    constraint c_en { en dist {1 := 70, 0 := 30}; }

    function string convert2string();
        return $sformatf("en=%0b d=0x%08h q=0x%08h", en, d, q);
    endfunction
endclass
"""),
        code("reg_sequences.svh", """
class reset_sequence extends uvm_sequence #(reg_item);
    `uvm_object_utils(reset_sequence)
    function new(string name = "reset_sequence");
        super.new(name);
    endfunction

    virtual task body();
        reg_item item;
        item = reg_item::type_id::create("rst_item");
        start_item(item);
        item.en = 1'b0;              // 랜덤 대신 고정
        item.d  = 32'h0;
        finish_item(item);
    endtask
endclass

class reg_sequence extends uvm_sequence #(reg_item);
    `uvm_object_utils(reg_sequence)
    rand int unsigned n = 20;
    constraint c_n { n inside {[10:50]}; }

    function new(string name = "reg_sequence");
        super.new(name);
    endfunction

    virtual task body();
        reg_item item;
        repeat (n) begin
            item = reg_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_error("SEQ", "randomize 실패")
            finish_item(item);
        end
    endtask
endclass

// 유지 동작 집중 시험: en=0 을 연속으로
class hold_sequence extends uvm_sequence #(reg_item);
    `uvm_object_utils(hold_sequence)
    function new(string name = "hold_sequence");
        super.new(name);
    endfunction

    virtual task body();
        reg_item item;
        // 먼저 값을 하나 써넣는다
        item = reg_item::type_id::create("wr");
        start_item(item);
        item.en = 1; item.d = 32'hDEAD_BEEF;
        finish_item(item);
        // 그 다음 en=0 으로 유지
        repeat (10) begin
            item = reg_item::type_id::create("hold");
            start_item(item);
            item.en = 0;
            if (!item.randomize(d)) `uvm_error("SEQ", "실패")
            finish_item(item);
        end
    endtask
endclass
"""),

        h2("34.4  driver - 리셋 처리 포함"),
        code("reg_driver.svh", """
class reg_driver extends uvm_driver #(reg_item);
    `uvm_component_utils(reg_driver)

    virtual reg_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual reg_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 없음: ", get_full_name()})
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            reset_handler();
            drive_loop();
        join
    endtask

    task reset_handler();
        forever begin
            @(negedge vif.resetn);
            `uvm_info("DRV", "리셋 감지", UVM_LOW)
            vif.cb.en <= 1'b0;
            vif.cb.d  <= 32'h0;
            @(posedge vif.resetn);
        end
    endtask

    task drive_loop();
        wait (vif.resetn === 1'b1);     // 리셋 해제 대기
        forever begin
            seq_item_port.get_next_item(req);
            @(vif.cb);
            vif.cb.en <= req.en;
            vif.cb.d  <= req.d;
            `uvm_info("DRV", req.convert2string(), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask
endclass
"""),
        trap("리셋 해제를 기다리지 않으면",
             "리셋 중에 자극을 인가하면 DUT 가 무시하는데, "
             "스코어보드는 그것을 유효한 트랜잭션으로 취급해 "
             "불일치가 무더기로 납니다."),

        h2("34.5  monitor - 파이프라인 관측"),
        code("reg_monitor.svh", """
class reg_monitor extends uvm_monitor;
    `uvm_component_utils(reg_monitor)

    virtual reg_if vif;
    uvm_analysis_port #(reg_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual reg_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 없음: ", get_full_name()})
    endfunction

    virtual task run_phase(uvm_phase phase);
        reg_item item;
        forever begin
            @(vif.cb);
            if (vif.resetn !== 1'b1) continue;   // 리셋 중은 건너뜀

            item = reg_item::type_id::create("mon_item");
            item.en = vif.cb.en;      // 이번 엣지의 입력
            item.d  = vif.cb.d;

            @(vif.cb);                // 다음 엣지
            item.q = vif.cb.q;        // 그때의 출력

            ap.write(item);
        end
    endtask
endclass
"""),
        art("""
   레지스터의 1클럭 지연 관측

   clk    _|~|_|~|_|~|_|~|_
                ^       ^
                |       +-- 여기서 q 를 읽는다
                +-- 여기서 en, d 를 읽는다

   en/d 를 본 엣지의 '다음' 엣지에서 q 가 그 값을 반영한다.
   monitor 는 두 엣지에 걸쳐 하나의 트랜잭션을 조립한다.
"""),

        h2("34.6  scoreboard - 상태를 가진 레퍼런스 모델"),
        code("reg_scoreboard.svh", """
class reg_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(reg_scoreboard)

    uvm_analysis_imp #(reg_item, reg_scoreboard) item_export;

    bit [31:0]   model_q;        // 레퍼런스 모델의 상태
    int unsigned n_match, n_mismatch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
        model_q = 32'h0;         // 리셋 후 상태
    endfunction

    virtual function void write(reg_item t);
        bit [31:0] exp;

        // 레퍼런스 모델: en 이면 갱신, 아니면 유지
        if (t.en) model_q = t.d;
        exp = model_q;

        if (t.q !== exp) begin
            n_mismatch++;
            `uvm_error("SCB", $sformatf(
                "불일치  en=%0b d=0x%08h  기대=0x%08h  실제=0x%08h",
                t.en, t.d, exp, t.q))
        end else begin
            n_match++;
            `uvm_info("SCB", $sformatf("일치 %s", t.convert2string()),
                       UVM_HIGH)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", $sformatf("일치 %0d / 불일치 %0d",
                   n_match, n_mismatch), UVM_NONE)
        if (n_match + n_mismatch == 0)
            `uvm_error("SCB", "비교가 수행되지 않았습니다")
    endfunction
endclass
"""),
        key("상태 있는 레퍼런스 모델",
            "가산기와 달리 레지스터는 이전 값을 기억해야 합니다. "
            "model_q 가 그 상태이고, en=0 일 때 유지되는 동작을 "
            "그대로 흉내냅니다. 이것이 레퍼런스 모델의 본질입니다."),

        h2("34.7  top module 의 리셋 인가"),
        code("tb_register.sv", """
module tb_register;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import reg_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    reg_if r_if (clk);

    uvm_register dut (
        .clk   (clk),
        .resetn(r_if.resetn),
        .en    (r_if.en),
        .d     (r_if.d),
        .q     (r_if.q)
    );

    // 리셋은 top 에서 인가 (드라이버가 아님)
    initial begin
        r_if.resetn = 1'b0;
        repeat (3) @(posedge clk);
        r_if.resetn = 1'b1;
    end

    initial begin
        uvm_config_db #(virtual reg_if)::set(null, "*", "vif", r_if);
        run_test();
    end
endmodule
"""),
        note("리셋을 어디서 인가하나",
             "top 에서 하는 방식과 전용 reset_agent 를 두는 방식이 있습니다. "
             "학습 단계에서는 top 이 간단하고, 리셋 시나리오를 테스트별로 "
             "바꿔야 하면 agent 로 만드는 편이 낫습니다.",
             "info"),

        h2("34.8  실습"),
        lab("과제 34-A",
            "위 환경을 완성하고 random_test 를 실행해 "
            "일치 건수가 나오는지 확인하세요."),
        lab("과제 34-B",
            "DUT 의 else if (en) 을 else if (!en) 로 바꿔 "
            "스코어보드가 전부 불일치로 잡는지 확인하세요."),
        lab("과제 34-C",
            "monitor 에서 두 번째 @(vif.cb) 를 지우고 같은 엣지에서 "
            "q 를 읽으면 어떻게 되는지 확인하세요."),
        quiz("레지스터 스코어보드가 가산기와 다른 점은?",
             ["① 큐를 써야 한다",
              "② 레퍼런스 모델이 상태(이전 q)를 기억해야 한다",
              "③ analysis_port 를 두 개 써야 한다",
              "④ 차이 없다"],
             "② — 순차 논리는 이전 상태에 따라 출력이 달라집니다. "
             "en=0 일 때 값을 유지하는 동작을 모델도 흉내내야 합니다."),
    ],
}


# ==========================================================================
CH35 = {
    "number": "CHAPTER 35",
    "title": "실습 3 - 커버리지 추가",
    "goals": [
        "커버리지 컬렉터를 별도 컴포넌트로 만든다",
        "모니터 하나에 구독자 둘을 연결한다",
        "커버리지 리포트를 읽는다",
        "미달 항목을 겨냥한 시퀀스를 만든다",
    ],
    "body": [
        lead("스코어보드는 '틀렸는가'를 봅니다. 이제 '무엇을 봤는가'를 "
             "측정하는 부품을 추가합니다."),

        h2("35.1  커버리지 컬렉터"),
        code("coverage.svh", """
class adder_coverage extends uvm_subscriber #(seq_item);
    `uvm_component_utils(adder_coverage)

    seq_item item;

    covergroup cg;
        option.per_instance = 1;
        option.name = "adder_cg";

        cp_a : coverpoint item.a {
            bins zero   = {0};
            bins low    = {[1:63]};
            bins mid    = {[64:191]};
            bins high   = {[192:254]};
            bins max    = {255};
        }
        cp_b : coverpoint item.b {
            bins zero   = {0};
            bins low    = {[1:63]};
            bins mid    = {[64:191]};
            bins high   = {[192:254]};
            bins max    = {255};
        }
        cp_carry : coverpoint item.y[8] {
            bins no_carry = {0};
            bins carry    = {1};
        }

        x_ab    : cross cp_a, cp_b;
        x_carry : cross cp_a, cp_carry;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();                  // 반드시 생성자에서
    endfunction

    // uvm_subscriber 가 write 를 pure virtual 로 요구한다
    virtual function void write(seq_item t);
        item = t;
        cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("기능 커버리지 %.2f%%",
                   cg.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
"""),
        key("uvm_subscriber 를 쓰면 편하다",
            "uvm_analysis_imp 를 직접 선언할 필요 없이 "
            "analysis_export 가 이미 들어 있습니다. "
            "write() 만 구현하면 됩니다."),
        trap("cg = new() 누락",
             "covergroup 은 자동 생성되지 않습니다. "
             "빼먹으면 커버리지가 항상 0% 인데 에러는 안 납니다. "
             "'커버리지가 안 오른다'의 첫 번째 원인입니다."),

        h2("35.2  env 에 연결"),
        code("env_with_cov.svh", """
class adder_env extends uvm_env;
    `uvm_component_utils(adder_env)

    adder_agent      agt;
    adder_scoreboard scb;
    adder_coverage   cov;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = adder_agent     ::type_id::create("agt", this);
        scb = adder_scoreboard::type_id::create("scb", this);
        cov = adder_coverage  ::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.item_export);
        agt.mon.ap.connect(cov.analysis_export);   // 둘째 구독자
    endfunction
endclass
"""),

        h2("35.3  커버리지 리포트 읽기"),
        code("coverage_report.txt", """
Covergroup           Hits  Goal  Status
------------------------------------------
adder_cg             -     100   72.50%
  cp_a               5/5   100   100.00%
  cp_b               5/5   100   100.00%
  cp_carry           2/2   100   100.00%
  x_ab              18/25  100    72.00%     <- 미달
  x_carry            7/10  100    70.00%     <- 미달

미달 bin:
  x_ab: <zero,max> <max,zero> <zero,high> ...
  x_carry: <zero,carry> <low,carry> ...
"""),
        p("cp_a 와 cp_b 는 100% 인데 cross 가 낮습니다. "
          "각 값은 다 봤지만 특정 조합은 못 봤다는 뜻입니다."),
        p("x_carry 의 <zero,carry> 가 안 채워진 것은 당연합니다. "
          "a=0 이면 캐리가 날 수 없기 때문입니다. "
          "이런 것은 ignore_bins 로 제외해야 합니다."),
        code("ignore_impossible.sv", """
x_carry : cross cp_a, cp_carry {
    // a 가 작으면 캐리가 불가능하다
    ignore_bins impossible =
        (binsof(cp_a.zero) || binsof(cp_a.low)) && binsof(cp_carry.carry);
}
"""),
        key("미달 bin 을 만나면 순서",
            "① 물리적으로 도달 가능한가 → 불가능하면 ignore_bins. "
            "② 제약이 막고 있는가 → 제약을 조정. "
            "③ 확률이 낮을 뿐인가 → 겨냥한 시퀀스를 추가. "
            "무작정 시뮬레이션 횟수를 늘리는 것은 마지막 수단입니다."),

        h2("35.4  미달을 겨냥한 시퀀스"),
        code("targeted_sequence.svh", """
// x_ab 의 <max,zero>, <zero,max> 같은 극단 조합을 겨냥
class corner_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(corner_sequence)

    function new(string name = "corner_sequence");
        super.new(name);
    endfunction

    virtual task body();
        seq_item item;
        bit [7:0] corners[] = '{0, 1, 127, 128, 254, 255};

        foreach (corners[i])
            foreach (corners[j]) begin
                item = seq_item::type_id::create("item");
                start_item(item);
                item.a = corners[i];
                item.b = corners[j];
                finish_item(item);
            end
    endtask
endclass
"""),
        tip("랜덤 + 방향 조합",
            "실무 회귀는 랜덤 테스트로 넓게 훑고, 커버리지 구멍을 "
            "방향 테스트(directed test)로 메웁니다. "
            "둘 중 하나만으로는 효율이 나쁩니다."),

        h2("35.5  Vivado 에서 커버리지 수집"),
        code("vivado_coverage.sh", """
# elaborate 에 커버리지 옵션 추가
xelab -L uvm -cov_db_name adder_cov \\
      -cov_db_dir ./cov_db tb_adder -s tb_snapshot

# 실행
xsim tb_snapshot -R -testplusarg UVM_TESTNAME=random_test

# 리포트 생성
xcrg -report_format html -dir ./cov_db -report_dir ./cov_report
"""),
        note("시뮬레이터별 차이",
             "커버리지 수집과 리포트 방법은 시뮬레이터마다 다릅니다. "
             "Questa 는 vcover, VCS 는 urg 를 씁니다. "
             "SystemVerilog 문법 자체는 동일합니다.",
             "info"),

        h2("35.6  실습"),
        lab("과제 35-A",
            "가산기 환경에 커버리지 컬렉터를 추가하고 "
            "20회, 200회, 2000회 실행 시 커버리지 변화를 기록하세요."),
        lab("과제 35-B",
            "미달 bin 을 확인하고 그것을 겨냥한 corner_sequence 를 "
            "만들어 커버리지를 100% 로 만드세요."),
        lab("과제 35-C",
            "레지스터 환경에도 커버리지를 추가하되, "
            "en 과 리셋 상태의 cross 를 포함하세요."),
    ],
}


# ==========================================================================
CH36 = {
    "number": "CHAPTER 36",
    "title": "실습 4 - assertion 과 에러 주입",
    "goals": [
        "interface 에 assertion 을 추가한다",
        "factory override 로 에러를 주입한다",
        "환경이 실제로 버그를 잡는지 검증한다",
        "음성 테스트를 구성한다",
    ],
    "body": [
        lead("검증 환경도 코드입니다. 버그가 있을 수 있습니다. "
             "'이 환경이 정말 버그를 잡는가'를 확인하는 것이 "
             "에러 주입 테스트의 목적입니다."),

        h2("36.1  interface 에 assertion 추가"),
        code("reg_if_sva.sv", """
interface reg_if (input logic clk);
    logic        resetn, en;
    logic [31:0] d, q;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output en, d;
        input  q;
    endclocking

    // ---------- assertion ----------
    a_reset : assert property (
        @(posedge clk) !resetn |=> (q == 32'h0)
    ) else `uvm_error("SVA", "리셋 후 q 가 0 이 아님")

    a_load : assert property (
        @(posedge clk) disable iff (!resetn)
        en |=> (q == $past(d))
    ) else `uvm_error("SVA", $sformatf(
        "로드 실패: 기대 0x%08h 실제 0x%08h", $past(d), q))

    a_hold : assert property (
        @(posedge clk) disable iff (!resetn)
        !en |=> $stable(q)
    ) else `uvm_error("SVA", "en=0 인데 q 가 변함")

    a_no_x : assert property (
        @(posedge clk) disable iff (!resetn) !$isunknown(q)
    ) else `uvm_error("SVA", "q 에 X 가 있음")

    // ---------- cover ----------
    c_load  : cover property (@(posedge clk) disable iff (!resetn) en);
    c_hold  : cover property (@(posedge clk) disable iff (!resetn) !en);
    c_reset : cover property (@(posedge clk) $fell(resetn));
endinterface
"""),
        key("cover property 를 함께 두라",
            "assertion 만 있으면 '한 번도 조건이 성립하지 않아서 "
            "통과한' 상태를 알 수 없습니다. cover 로 선행 조건이 "
            "실제로 발생했는지 확인해야 합니다."),
        note("`uvm_error 를 interface 에서 쓰려면",
             "interface 파일 상단에 import uvm_pkg::*; 와 "
             "`include \"uvm_macros.svh\" 가 필요합니다. "
             "번거로우면 $error 를 쓰되, UVM 집계에 안 잡힌다는 점을 "
             "감안하세요.",
             "warn"),

        h2("36.2  에러 주입 - factory override"),
        p("DUT 를 고치지 않고 '잘못된 자극'을 넣어 환경 반응을 봅니다."),
        code("err_item.svh", """
// seq_item 을 상속 - 반드시 자식이어야 한다
class err_item extends reg_item;
    `uvm_object_utils(err_item)

    function new(string name = "err_item");
        super.new(name);
    endfunction

    // 부모 제약을 무시하고 극단값만 생성
    constraint c_extreme {
        d inside {32'h0, 32'hFFFF_FFFF, 32'hAAAA_AAAA, 32'h5555_5555};
    }
endclass
"""),
        code("err_test.svh", """
class err_test extends base_test;
    `uvm_component_utils(err_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        // super 보다 먼저! 컴포넌트가 만들어지기 전에 걸어야 한다
        set_type_override_by_type(reg_item::get_type(),
                                  err_item::get_type());
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        reg_sequence seq = reg_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.seqr);      // 시퀀스 코드는 그대로
        #100;
        phase.drop_objection(this);
    endtask
endclass
"""),
        key("시퀀스는 한 글자도 안 바뀐다",
            "reg_sequence 안의 reg_item::type_id::create(...) 가 "
            "err_item 을 반환합니다. 이것이 factory 를 쓰는 이유의 "
            "전부입니다."),

        h2("36.3  DUT 에 버그 심기 - 환경 검증"),
        p("검증 환경이 제대로 동작하는지 확인하는 가장 확실한 방법입니다."),
        table(["심을 버그", "예상 반응"],
              [["y 폭을 [7:0] 로 축소", "SCB 불일치 (차이 256의 배수)"],
               ["en 조건 반전", "SCB 불일치 + a_load 실패"],
               ["리셋 값을 1 로", "a_reset 실패"],
               ["q <= d 를 q <= d+1 로", "SCB 불일치 (차이 1)"],
               ["always_ff 를 always_comb 로", "a_load 실패 (타이밍)"]],
              weights=[1.2, 1.4]),
        code("mutation_test.sv", """
// 버그 버전 DUT - 파일을 복사해서 만든다
module uvm_register_bug1 (
    input  logic clk, resetn, en,
    input  logic [31:0] d,
    output logic [31:0] q
);
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)    q <= 32'h0;
        else if (!en)   q <= d;      // 버그: en 조건 반전
    end
endmodule
"""),
        key("이것을 mutation testing 이라 한다",
            "일부러 버그를 심어 검증 환경이 잡아내는지 확인합니다. "
            "잡히지 않는 버그가 있다면 그 부분의 검증이 부족한 것입니다. "
            "환경의 품질을 정량적으로 평가하는 실무 기법입니다."),

        h2("36.4  음성 테스트"),
        p("'에러가 나야 정상'인 테스트입니다. 회귀에서 이것이 통과하면 "
          "오히려 문제입니다."),
        code("negative_test.svh", """
class negative_test extends base_test;
    `uvm_component_utils(negative_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        int n_err = svr.get_severity_count(UVM_ERROR);

        if (n_err == 0)
            `uvm_fatal("NEG", "에러가 나야 하는 테스트인데 통과했습니다. "
                              "검증 환경을 점검하세요.")
        else begin
            `uvm_info("NEG", $sformatf(
                "예상대로 %0d건의 에러를 잡았습니다", n_err), UVM_NONE)
            svr.set_severity_count(UVM_ERROR, 0);   // 카운터 초기화
        end
    endfunction
endclass
"""),
        tip("severity count 조작",
             "음성 테스트는 에러가 나야 정상이므로, report_phase 에서 "
             "카운터를 0 으로 되돌려 회귀 스크립트가 PASS 로 판정하게 "
             "합니다. 다만 이 조작을 명확히 문서화하세요."),

        h2("36.5  실습"),
        lab("과제 36-A",
            "reg_if 에 네 개의 assertion 을 추가하고, "
            "DUT 의 리셋 값을 1 로 바꿔 a_reset 이 실패하는지 확인하세요."),
        lab("과제 36-B",
            "err_item 을 만들고 factory override 로 주입해 "
            "시퀀스 수정 없이 다른 자극이 나오는지 확인하세요."),
        lab("과제 36-C",
            "위 표의 버그 5개를 하나씩 심고, 각각 어떤 검사가 "
            "잡아내는지 표로 정리하세요. 안 잡히는 것이 있으면 "
            "그 이유를 분석하세요."),
        quiz("factory override 를 super.build_phase() 뒤에 걸면?",
             ["① 정상 동작한다",
              "② 컴포넌트는 이미 생성되어 override 가 안 먹는다",
              "③ 컴파일 에러",
              "④ sequence_item 도 override 가 안 된다"],
             "② — 컴포넌트는 super.build_phase 에서 만들어집니다. "
             "그 뒤에 걸면 늦습니다. sequence_item 은 run_phase 에서 "
             "만들어지므로 영향이 없습니다."),
    ],
}


# ==========================================================================
CH37 = {
    "number": "CHAPTER 37",
    "title": "Vivado 실행과 파형 분석",
    "goals": [
        "Vivado xsim 으로 UVM 을 실행한다",
        "명령행 옵션으로 테스트를 전환한다",
        "파형에서 트랜잭션을 추적한다",
        "로그와 파형을 연결해 읽는다",
    ],
    "body": [
        lead("환경을 만들었으면 이제 돌려야 합니다. Vivado 2020.2 는 "
             "UVM 1.2 를 내장하고 있어 별도 설치 없이 쓸 수 있습니다."),

        h2("37.1  UVM 라이브러리 위치"),
        code("uvm_path.txt", """
C:\\Xilinx\\Vivado\\2020.2\\data\\system_verilog\\uvm_1.2\\
    uvm_macros.svh          매크로 정의 (`uvm_info, `uvm_object_utils 등)
    xlnx_uvm_package.sv     UVM 전체가 한 파일로 합쳐져 있음

참고: 원래 UVM 배포판은 src/base/uvm_registry.svh 처럼
      파일이 잘게 나뉘어 있지만 Vivado 는 한 파일로 합쳤습니다.
      인터넷 자료에서 찾으라는 파일이 없는 이유입니다.
"""),
        table(["찾을 내용", "위치"],
              [["`uvm_info 정의", "uvm_macros.svh:104"],
               ["`uvm_error / `uvm_fatal", "uvm_macros.svh:120, 128"],
               ["`uvm_object_utils_begin", "uvm_macros.svh:484"],
               ["type_id typedef", "uvm_macros.svh:576"],
               ["type_name 문자열화", "uvm_macros.svh:568"],
               ["uvm_object_registry 본체", "xlnx_uvm_package.sv:6935"],
               ["factory 의 장부", "xlnx_uvm_package.sv:6139"],
               ["create_object_by_type", "xlnx_uvm_package.sv:6397"]],
              weights=[1.2, 1.3]),
        warn("읽기 전용",
             "Vivado 설치 파일입니다. 수정하면 다른 프로젝트까지 "
             "영향을 받습니다. 참고용으로만 여세요."),

        h2("37.2  GUI 에서 실행"),
        ol("Sources 창에서 Simulation Sources 에 파일 추가",
           "tb_adder 를 우클릭 > Set as Top",
           "Settings > Simulation > Compilation 탭에서 "
           "xsim.compile.xvlog.more_options 에 -L uvm 입력",
           "Elaboration 탭에서 xsim.elaborate.xelab.more_options 에 -L uvm 입력",
           "Simulation 탭에서 xsim.simulate.xsim.more_options 에 "
           "-testplusarg UVM_TESTNAME=random_test 입력",
           "Run Simulation > Run Behavioral Simulation"),

        h2("37.3  명령행 실행 (권장)"),
        code("run.sh", """
#!/bin/bash
# 회귀에 쓰기 좋은 형태

TEST=${1:-random_test}
SEED=${2:-1}
VERB=${3:-UVM_MEDIUM}

xvlog -sv -L uvm \\
      ../sources_1/new/adder_uvm.sv \\
      adder_if.sv \\
      adder_pkg.sv \\
      tb_adder.sv || exit 1

xelab -L uvm -debug typical -s tb_snapshot tb_adder || exit 1

xsim tb_snapshot -R \\
     -testplusarg UVM_TESTNAME=$TEST \\
     -testplusarg UVM_VERBOSITY=$VERB \\
     -sv_seed $SEED \\
     -log run_${TEST}_${SEED}.log
"""),
        code("regression.sh", """
#!/bin/bash
# 여러 테스트 x 여러 시드

PASS=0; FAIL=0
for test in random_test carry_test corner_test; do
  for seed in $(seq 1 20); do
    ./run.sh $test $seed UVM_LOW > /dev/null 2>&1
    if grep -q "UVM_ERROR :    0" run_${test}_${seed}.log && \\
       grep -q "UVM_FATAL :    0" run_${test}_${seed}.log; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL: $test seed=$seed"
    fi
  done
done
echo "PASS=$PASS FAIL=$FAIL"
"""),
        tip("시드를 로그 이름에 넣어라",
            "실패한 시드를 그대로 다시 넣으면 동일하게 재현됩니다. "
            "재현 안 되는 실패는 테스트벤치의 경쟁 조건을 의심하세요."),

        h2("37.4  유용한 명령행 옵션"),
        table(["옵션", "효과"],
              [["+UVM_TESTNAME=xxx", "실행할 테스트 지정"],
               ["+UVM_VERBOSITY=UVM_HIGH", "로그 상세도"],
               ["+UVM_MAX_QUIT_COUNT=10", "에러 10개면 중단"],
               ["+UVM_OBJECTION_TRACE", "objection 추적"],
               ["+UVM_CONFIG_DB_TRACE", "config_db set/get 추적"],
               ["+UVM_PHASE_TRACE", "phase 전이 추적"],
               ["-sv_seed N", "랜덤 시드"],
               ["-sv_seed random", "매번 다른 시드"]],
              weights=[1.4, 1.2]),
        key("TRACE 옵션이 디버깅의 절반",
            "config_db 값을 못 받거나 objection 이 안 내려가면 "
            "코드를 들여다보기 전에 TRACE 부터 켜 보세요. "
            "원인이 바로 로그에 나오는 경우가 대부분입니다."),

        h2("37.5  파형 보기"),
        code("dump_wave.sv", """
// top module 에 추가
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_adder);
end
"""),
        code("view_wave.sh", """
# 시뮬레이션 후 GUI 로 열기
xsim tb_snapshot --gui

# 또는 이미 저장된 파형
vivado -source open_wave.tcl
"""),
        art("""
   파형에서 확인할 것 (레지스터 예)

   clk     _|~|_|~|_|~|_|~|_|~|_
   resetn  ___|~~~~~~~~~~~~~~~~~
   en      _______|~~~|_________
   d       XXXXXXX| A |XXXXXXXXX
   q       0000000000000| A |___
                        ^
                        +-- en 다음 엣지에서 q 가 A 로
                            여기가 1클럭 늦으면 타이밍 버그
"""),

        h2("37.6  로그와 파형 연결하기"),
        p("에러 메시지의 시각을 파형에서 찾는 것이 디버깅의 기본입니다."),
        code("error_to_wave.txt", """
UVM_ERROR tb.sv(120) @ 145000: uvm_test_top.env.scb [SCB]
    불일치  en=1 d=0x0000ABCD  기대=0x0000ABCD  실제=0x00000000
                              ^^^^^^^
                              시각 145000 = 145ns

파형에서 145ns 로 이동
  -> en 이 그때 정말 1이었나
  -> d 가 0xABCD 였나
  -> q 가 언제 바뀌었나 (1클럭 늦었나, 아예 안 바뀌었나)
"""),
        ol("에러 메시지에서 시각을 읽는다",
           "파형에서 그 시각으로 이동한다",
           "입력 신호가 기대대로 인가되었는지 확인 (드라이버 문제인가)",
           "출력이 언제 바뀌는지 확인 (DUT 문제인가 모니터 문제인가)",
           "한 클럭 앞뒤를 함께 본다 (샘플링 시점 문제인가)"),

        h2("37.7  UVM 로그 전체 읽기"),
        p("처음 UVM 로그를 보면 정보가 너무 많아 어디를 봐야 할지 "
          "모릅니다. 순서대로 읽는 법을 정리합니다."),
        code("full_log_walkthrough.txt", """
[1] 버전 배너 - 툴 설정이 맞는지
    UVM_INFO ... [UVM/RELNOTES] (Specify +UVM_NO_RELNOTES ...)
    ----------------------------------------------------------------
    UVM-1.2
    ----------------------------------------------------------------

[2] 테스트 시작 - 의도한 테스트가 맞는지
    UVM_INFO @ 0: reporter [RNTST] Running test random_test...

[3] 계층 출력 - 컴포넌트가 다 있는지 (print_topology 를 켰다면)
    uvm_test_top      random_test    -    @335
      env             adder_env      -    @346
        agt           adder_agent    -    @357
          mon         adder_monitor  -    @441
          seqr        uvm_sequencer  -    @375
          drv         adder_driver   -    @408
        scb           adder_scoreboard -  @368

[4] 본 실행 - 시각 순서로 트랜잭션
    UVM_INFO @ 15: ...seqr@@seq [SEQ] 20개 아이템 생성 시작
    UVM_INFO @ 25: ...agt.drv [DRV] a= 173 b=  91 y=  0
    UVM_INFO @ 35: ...agt.mon [MON] a= 173 b=  91 y=264

[5] 에러가 있다면 - 시각과 계층 경로에 주목
    UVM_ERROR tb.sv(120) @ 145000: uvm_test_top.env.scb [SCB]
        불일치  a=200 b=100  기대=300  실제=44  차이=-256
                                                    ^^^^
                                          256의 배수 -> 폭 문제

[6] 사후 phase 출력
    UVM_INFO @ 315: uvm_test_top.env.scb [SCB] 일치 19 / 불일치 1
    UVM_INFO @ 315: uvm_test_top.env.cov [COV] 기능 커버리지 72.50%

[7] 최종 요약 - PASS/FAIL 판정
    --- UVM Report Summary ---
    ** Report counts by severity
    UVM_INFO    :   45
    UVM_WARNING :    0
    UVM_ERROR   :    1      <- 0이 아니면 FAIL
    UVM_FATAL   :    0
"""),
        table(["로그 위치", "확인할 것"],
              [["[1] 배너", "UVM 버전, -L uvm 설정이 먹었는가"],
               ["[2] RNTST", "의도한 테스트인가 (+UVM_TESTNAME 확인)"],
               ["[3] 계층", "컴포넌트 누락, 이름 오타"],
               ["[4] 본문", "드라이버가 인가하고 모니터가 잡는가"],
               ["[5] 에러", "시각, 계층, 차이값"],
               ["[6] 사후", "비교 횟수가 0이 아닌가"],
               ["[7] 요약", "ERROR / FATAL 카운트"]],
              weights=[1.0, 1.8]),
        key("차이값이 진단의 지름길",
            "차이가 256의 배수면 8비트 폭 문제, 1이면 오프바이원, "
            "부호가 반대면 signed/unsigned, 값이 이전 트랜잭션의 것이면 "
            "타이밍 문제입니다. 에러 메시지에 차이를 넣어두면 "
            "파형을 열기 전에 원인이 좁혀집니다."),
        code("log_grep.sh", """
# 자주 쓰는 추출

grep "UVM_ERROR"   run.log | head -20        # 첫 에러들
grep "UVM_FATAL"   run.log                   # 치명적 오류
grep "Report Summary" -A 8 run.log           # 최종 집계
grep "\\[SCB\\]"    run.log | tail -5         # 스코어보드 결론
grep -c "UVM_ERROR" run.log                  # 에러 줄 수

# 첫 실패 시각만 뽑기
grep -m1 "UVM_ERROR" run.log | grep -o "@ [0-9]*"
"""),

        h2("37.8  실습"),
        lab("과제 37-A",
            "run.sh 를 작성해 명령행에서 테스트를 전환하며 실행하세요."),
        lab("과제 37-B",
            "+UVM_PHASE_TRACE 를 켜고 phase 순서를 로그로 확인하세요."),
        lab("과제 37-C",
            "일부러 config_db 키 이름을 틀리게 하고 "
            "+UVM_CONFIG_DB_TRACE 로 원인을 찾으세요."),
    ],
}


# ==========================================================================
CH38 = {
    "number": "CHAPTER 38",
    "title": "디버깅 실전",
    "goals": [
        "증상별로 원인을 좁힌다",
        "UVM 특유의 에러 메시지를 해석한다",
        "재현 가능한 최소 사례를 만든다",
        "디버깅 순서를 체계화한다",
    ],
    "body": [
        lead("UVM 은 에러 메시지가 불친절한 편입니다. "
             "그러나 증상과 원인의 대응 관계가 비교적 정형화되어 있어 "
             "패턴을 알면 빠르게 좁힐 수 있습니다."),

        h2("38.1  증상별 원인 표"),
        table(["증상", "가장 흔한 원인", "확인 방법"],
              [["0ns 에 시뮬레이션 종료", "objection 을 안 올림",
                "+UVM_OBJECTION_TRACE"],
               ["시뮬레이션이 안 끝남", "objection 을 안 내림 / item_done 누락",
                "+UVM_OBJECTION_TRACE"],
               ["내 run_phase 가 안 불림", "virtual 누락, 시그니처 오타",
                "run_phase 첫 줄에 uvm_info"],
               ["vif 가 null", "config_db set 이 run_test 뒤",
                "+UVM_CONFIG_DB_TRACE"],
               ["설정 값을 못 받음", "타입/키/경로 불일치",
                "+UVM_CONFIG_DB_TRACE"],
               ["type_id not declared", "uvm_object_utils 누락",
                "매크로 확인"],
               ["Cannot instantiate abstract", "utils 매크로 누락",
                "매크로 확인"],
               ["FCTTYP fatal", "override 대상이 자식이 아님",
                "상속 관계 확인"],
               ["커버리지 0%", "cg = new() 누락",
                "생성자 확인"],
               ["스코어보드 비교 0회", "analysis_port 연결 누락",
                "connect_phase 확인"],
               ["null object access", "create 누락 또는 build 에서 연결",
                "print_topology"]],
              weights=[1.2, 1.3, 1.1]),

        h2("38.2  디버깅 순서"),
        ol("print_topology() 로 계층이 맞는지 본다 - 컴포넌트가 빠졌거나 "
           "이름이 틀렸으면 여기서 드러난다",
           "각 phase 에 uvm_info 를 넣어 어디까지 진행되는지 본다",
           "TRACE 옵션을 켠다 (objection / config_db / phase)",
           "드라이버가 핀을 흔드는지 파형으로 확인한다",
           "모니터가 트랜잭션을 잡는지 uvm_info 로 확인한다",
           "스코어보드가 write 를 받는지 확인한다",
           "그래도 모르면 최소 재현 사례를 만든다"),

        h2("38.3  계층 출력"),
        code("print_topology.sv", """
virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
    uvm_factory::get().print();     // factory 상태도 함께
endfunction
"""),
        code("topology_out.txt", """
-------------------------------------------------------
Name              Type                    Size  Value
-------------------------------------------------------
uvm_test_top      random_test             -     @335
  env             adder_env               -     @346
    agt           adder_agent             -     @357
      mon         adder_monitor           -     @441
        ap        uvm_analysis_port       -     @450
      seqr        uvm_sequencer           -     @375
      drv         adder_driver            -     @408
    scb           adder_scoreboard        -     @368
    cov           adder_coverage          -     @380
-------------------------------------------------------

확인 사항
  - 기대한 컴포넌트가 다 있는가
  - 이름 철자가 config_db 경로와 일치하는가
  - 계층 깊이가 맞는가 (env.agt.drv 인가 env.drv 인가)
"""),

        h2("38.4  단계별 uvm_info 심기"),
        code("trace_info.sv", """
// 드라이버
virtual task run_phase(uvm_phase phase);
    `uvm_info("DRV", "run_phase 진입", UVM_NONE)      // 1
    forever begin
        seq_item_port.get_next_item(req);
        `uvm_info("DRV", "아이템 수신", UVM_NONE)      // 2
        drive_item(req);
        `uvm_info("DRV", "구동 완료", UVM_NONE)        // 3
        seq_item_port.item_done();
    end
endtask
"""),
        p("1번이 안 나오면 virtual 이나 시그니처 문제, "
          "2번이 안 나오면 시퀀스가 시작 안 된 것, "
          "3번이 안 나오면 drive_item 안에서 블록된 것입니다."),
        tip("UVM_NONE 으로 심어라",
            "임시 디버그 메시지는 UVM_NONE 으로 심어야 verbosity 설정과 "
            "무관하게 항상 보입니다. 문제 해결 후 지우거나 UVM_HIGH 로 "
            "낮추세요."),

        h2("38.5  objection 추적"),
        code("objection_trace.txt", """
# +UVM_OBJECTION_TRACE 출력

UVM_INFO @ 0: uvm_test_top [OBJTN_TRC]
    Object uvm_test_top raised 1 objection(s): count=1 total=1

UVM_INFO @ 315000: uvm_test_top [OBJTN_TRC]
    Object uvm_test_top dropped 1 objection(s): count=0 total=0

UVM_INFO @ 315000: uvm_test_top [OBJTN_TRC]
    Object uvm_test_top all_dropped

읽는 법
  raise 가 없으면        -> 0ns 종료의 원인
  drop 이 없으면         -> 안 끝나는 원인
  total 이 안 내려가면   -> 누군가 더 들고 있음
"""),

        h2("38.6  최소 재현 사례 만들기"),
        p("문제가 좁혀지지 않으면 환경을 잘라냅니다."),
        ol("시퀀스의 반복 횟수를 1로 줄인다",
           "커버리지와 assertion 을 뺀다",
           "스코어보드를 뺀다 (드라이버만 남긴다)",
           "랜덤을 고정값으로 바꾼다",
           "그래도 재현되면 원인은 남은 부분에 있다"),
        code("minimal.sv", """
// 최소 시퀀스
virtual task body();
    seq_item item = seq_item::type_id::create("item");
    start_item(item);
    item.a = 8'd10;      // 랜덤 대신 고정
    item.b = 8'd20;
    finish_item(item);
endtask
"""),
        key("고정값의 힘",
            "랜덤을 끄면 매 실행이 동일해집니다. "
            "'가끔 실패한다'가 '항상 실패한다'로 바뀌면 "
            "디버깅 난이도가 완전히 달라집니다."),

        h2("38.7  자주 나오는 에러 메시지 해석"),
        code("common_errors.txt", """
[1] "type_id is not declared under prefix seq_item"
    -> `uvm_object_utils 매크로 누락

[2] "Cannot instantiate abstract class"
    -> 같은 원인. create/get_type_name 이 pure virtual 로 남음

[3] "Factory did not return an object of type 'seq_item'"  (FCTTYP)
    -> override 대상이 seq_item 의 자식이 아님

[4] "super.new() 인자 개수 불일치"
    -> component 인데 new(name) 만 씀. new(name, parent) 여야 함

[5] "null object access"
    -> create 누락, 또는 build_phase 에서 자식을 연결하려 함

[6] "get_next_item 이 호출되었으나 item_done 이 없음"
    -> 예외 경로에서 item_done 을 빼먹음

[7] 시뮬레이션이 0ns 에 끝남
    -> objection 누락

[8] "uvm_pkg not found"
    -> -L uvm 옵션 누락 (compile 과 elaborate 양쪽에)
"""),

        h2("38.8  실습"),
        lab("과제 38-A",
            "위 8가지 에러를 일부러 하나씩 만들어 보고 "
            "실제 메시지를 기록하세요. 시뮬레이터 버전에 따라 "
            "표현이 다를 수 있습니다."),
        lab("과제 38-B",
            "동작하는 환경에서 item_done() 을 지우고 "
            "+UVM_OBJECTION_TRACE 로 어디서 멈추는지 추적하세요."),
        quiz("드라이버의 run_phase 에 넣은 uvm_info 가 안 찍힌다면?",
             ["① verbosity 가 낮아서",
              "② virtual 누락이나 시그니처 불일치로 오버라이드가 안 됨",
              "③ objection 문제",
              "④ config_db 문제"],
             "② — UVM_NONE 으로 심었는데도 안 나오면 그 메서드 자체가 "
             "호출되지 않는 것입니다. 이름 오타나 인자 타입 불일치를 "
             "확인하세요."),
    ],
}


CHAPTERS = [CH32, CH33, CH34, CH35, CH36, CH37, CH38]
