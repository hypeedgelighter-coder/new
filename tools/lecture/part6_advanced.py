"""Part VI - 고급 주제 (RAL / 가상 시퀀스 / VIP / callback / 성능 / DPI)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART VI",
    "title": "고급 주제와 실무 확장",
    "blurb": "블록 하나를 검증하는 환경에서 시스템 전체를 검증하는 환경으로 "
             "넘어갈 때 필요한 기법들입니다. 레지스터 추상화, 가상 시퀀스, "
             "재사용 가능한 VIP, 성능 최적화까지 실무에서 마주치는 "
             "확장 문제를 다룹니다.",
    "items": [
        "39장 가상 시퀀스와 다중 에이전트",
        "40장 RAL - 레지스터 추상화 계층",
        "41장 재사용 가능한 VIP 설계",
        "42장 UVM callback",
        "43장 시뮬레이션 성능 최적화",
        "44장 DPI-C 연동",
        "45장 검증 환경 리팩터링",
    ],
}


# ==========================================================================
CH39 = {
    "number": "CHAPTER 39",
    "title": "가상 시퀀스와 다중 에이전트",
    "goals": [
        "여러 인터페이스를 동시에 제어한다",
        "virtual sequencer 를 구성한다",
        "채널 간 동기화를 구현한다",
        "가상 시퀀스로 시스템 시나리오를 기술한다",
    ],
    "body": [
        lead("DUT 에 인터페이스가 하나뿐인 경우는 드뭅니다. "
             "AXI 마스터와 APB 슬레이브가 함께 있고, 인터럽트 라인이 "
             "따로 있습니다. 이들을 조율하는 것이 가상 시퀀스입니다."),

        h2("39.1  문제"),
        art("""
   DUT 에 인터페이스가 셋

   +-----------+
   |           |<--- axi_if   (axi_agent)
   |    DUT    |<--- apb_if   (apb_agent)
   |           |---> irq_if   (irq_agent, passive)
   +-----------+

   시나리오: "APB 로 설정하고, AXI 로 데이터를 보낸 뒤,
              IRQ 가 뜨는지 확인한다"

   -> 세 에이전트를 순서대로 조율해야 한다
   -> 각 sequence 는 자기 sequencer 만 안다
   -> 조율할 상위 주체가 필요하다
"""),

        h2("39.2  virtual sequencer"),
        p("자기 아이템을 만들지 않고, 다른 sequencer 들의 핸들만 갖는 "
          "sequencer 입니다."),
        code("virtual_sequencer.svh", """
class top_vsequencer extends uvm_sequencer;
    `uvm_component_utils(top_vsequencer)

    // 실제 sequencer 들의 핸들
    axi_sequencer axi_seqr;
    apb_sequencer apb_seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
"""),
        code("env_connect_vseqr.svh", """
class top_env extends uvm_env;
    `uvm_component_utils(top_env)

    axi_agent      axi_agt;
    apb_agent      apb_agt;
    irq_agent      irq_agt;
    top_vsequencer vseqr;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_agt = axi_agent     ::type_id::create("axi_agt", this);
        apb_agt = apb_agent     ::type_id::create("apb_agt", this);
        irq_agt = irq_agent     ::type_id::create("irq_agt", this);
        vseqr   = top_vsequencer::type_id::create("vseqr",   this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 가상 시퀀서에 실제 시퀀서 핸들을 꽂아 준다
        vseqr.axi_seqr = axi_agt.seqr;
        vseqr.apb_seqr = apb_agt.seqr;
    endfunction
endclass
"""),
        key("가상 시퀀서는 배선판이다",
            "아이템을 다루지 않고 핸들만 모아 둡니다. "
            "가상 시퀀스가 이 핸들들을 통해 각 채널에 접근합니다."),

        h2("39.3  가상 시퀀스"),
        code("virtual_sequence.svh", """
class config_and_send_vseq extends uvm_sequence;
    `uvm_object_utils(config_and_send_vseq)
    `uvm_declare_p_sequencer(top_vsequencer)   // p_sequencer 선언

    function new(string name = "config_and_send_vseq");
        super.new(name);
    endfunction

    virtual task body();
        apb_write_seq  cfg;
        axi_burst_seq  data;

        cfg  = apb_write_seq::type_id::create("cfg");
        data = axi_burst_seq::type_id::create("data");

        // 1) APB 로 설정
        cfg.addr = 32'h0000_0010;
        cfg.data = 32'h0000_0001;
        cfg.start(p_sequencer.apb_seqr);

        // 2) AXI 로 데이터 전송
        data.len = 16;
        data.start(p_sequencer.axi_seqr);

        // 3) IRQ 대기는 스코어보드가 확인
    endtask
endclass
"""),
        code("p_sequencer.sv", """
`uvm_declare_p_sequencer(top_vsequencer)

// 이 매크로가 만들어 주는 것
top_vsequencer p_sequencer;

virtual function void m_set_p_sequencer();
    super.m_set_p_sequencer();
    if (!$cast(p_sequencer, m_sequencer))
        `uvm_fatal("PSEQR", "가상 시퀀서 타입이 맞지 않습니다")
endfunction
"""),
        kv([("m_sequencer", "모든 시퀀스에 있는 기본 핸들. uvm_sequencer_base 타입"),
            ("p_sequencer", "매크로가 만든 캐스팅된 핸들. 우리 타입으로 접근 가능")], 88),
        trap("p_sequencer 가 null",
             "가상 시퀀스를 실제 sequencer 에 start 하면 $cast 가 실패해 "
             "p_sequencer 가 null 이 됩니다. 반드시 vseqr 에 start 하세요."),

        h2("39.4  병렬 실행"),
        code("parallel_vseq.svh", """
virtual task body();
    axi_burst_seq  axi_seq;
    apb_poll_seq   apb_seq;

    axi_seq = axi_burst_seq::type_id::create("axi_seq");
    apb_seq = apb_poll_seq ::type_id::create("apb_seq");

    fork
        axi_seq.start(p_sequencer.axi_seqr);   // 데이터 전송
        apb_seq.start(p_sequencer.apb_seqr);   // 동시에 상태 폴링
    join
endtask
"""),
        code("sync_vseq.svh", """
// 이벤트로 동기화
event data_sent;

virtual task body();
    fork
        begin
            axi_seq.start(p_sequencer.axi_seqr);
            -> data_sent;
        end
        begin
            wait (data_sent.triggered);
            apb_check_seq.start(p_sequencer.apb_seqr);
        end
    join
endtask
"""),

        h2("39.5  테스트에서 가상 시퀀스 시작"),
        code("vseq_test.svh", """
class system_test extends uvm_test;
    `uvm_component_utils(system_test)

    top_env env;

    virtual task run_phase(uvm_phase phase);
        config_and_send_vseq vseq;
        vseq = config_and_send_vseq::type_id::create("vseq");

        phase.raise_objection(this);
        vseq.start(env.vseqr);      // 가상 시퀀서에 start
        phase.drop_objection(this);
    endtask
endclass
"""),

        h2("39.6  언제 가상 시퀀스를 쓰는가"),
        table(["상황", "필요 여부"],
              [["인터페이스 1개", "불필요 - 일반 시퀀스로 충분"],
               ["인터페이스 여러 개, 독립 동작", "불필요 - 각각 default_sequence"],
               ["인터페이스 여러 개, 순서 의존", "필요"],
               ["채널 간 동기화 필요", "필요"],
               ["시스템 레벨 시나리오", "필요"]],
              weights=[1.4, 1.2]),
        warn("과도한 사용을 피하라",
             "인터페이스가 하나인데 가상 시퀀스를 쓰면 계층만 늘어나고 "
             "얻는 것이 없습니다. 조율이 실제로 필요할 때만 도입하세요."),

        h2("39.7  실습"),
        lab("과제 39-A",
            "가산기 에이전트와 레지스터 에이전트를 하나의 env 에 넣고, "
            "가상 시퀀서로 둘을 순서대로 구동하는 가상 시퀀스를 작성하세요."),
        quiz("p_sequencer 가 null 인 원인은?",
             ["① 매크로 누락",
              "② 가상 시퀀스를 실제 sequencer 에 start 함",
              "③ 둘 다 가능하다",
              "④ config_db 문제"],
             "③ — `uvm_declare_p_sequencer 매크로가 없어도, "
             "잘못된 sequencer 에 start 해도 null 이 됩니다. "
             "둘 다 확인하세요."),
    ],
}


# ==========================================================================
CH40 = {
    "number": "CHAPTER 40",
    "title": "RAL - 레지스터 추상화 계층",
    "goals": [
        "레지스터 모델의 구조를 이해한다",
        "read/write API 로 버스 프로토콜을 감춘다",
        "adapter 로 RAL 과 버스를 잇는다",
        "내장 레지스터 시퀀스를 활용한다",
    ],
    "body": [
        lead("SoC 하나에 레지스터가 수천 개입니다. 주소를 코드에 직접 쓰면 "
             "스펙이 바뀔 때마다 테스트를 전부 고쳐야 합니다. "
             "RAL 은 레지스터를 이름으로 접근하게 만듭니다."),

        h2("40.1  문제"),
        code("without_ral.sv", """
// 주소가 코드에 박혀 있다
apb_write(32'h4000_0010, 32'h0000_0001);   // CTRL 레지스터의 EN 비트
apb_write(32'h4000_0014, 32'h0000_00FF);   // THRESHOLD
data = apb_read(32'h4000_0018);            // STATUS

// 스펙이 바뀌어 주소가 0x4000_0020 으로 이동하면?
// -> 이 주소를 쓰는 모든 테스트를 찾아 고쳐야 한다
"""),
        code("with_ral.sv", """
// 이름으로 접근
regmodel.CTRL.EN.set(1);
regmodel.CTRL.update(status);

regmodel.THRESHOLD.write(status, 32'h0000_00FF);
regmodel.STATUS.read(status, data);

// 주소가 바뀌면 레지스터 모델 한 곳만 고치면 된다
"""),

        h2("40.2  RAL 계층 구조"),
        art("""
   uvm_reg_block          레지스터 블록 (맵 단위)
        |
        +-- uvm_reg       레지스터 하나
        |      |
        |      +-- uvm_reg_field    비트 필드
        |
        +-- uvm_reg_map   주소 맵 (base address, endianness)
"""),
        code("reg_model.svh", """
class ctrl_reg extends uvm_reg;
    `uvm_object_utils(ctrl_reg)

    rand uvm_reg_field EN;
    rand uvm_reg_field MODE;
    rand uvm_reg_field RSVD;

    function new(string name = "ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);   // 이름, 폭, 커버리지
    endfunction

    virtual function void build();
        EN   = uvm_reg_field::type_id::create("EN");
        MODE = uvm_reg_field::type_id::create("MODE");
        RSVD = uvm_reg_field::type_id::create("RSVD");

        //          parent, size, lsb, access, volatile, reset, has_reset,
        //          is_rand, individually_accessible
        EN  .configure(this, 1,  0, "RW", 0, 1'b0, 1, 1, 0);
        MODE.configure(this, 2,  1, "RW", 0, 2'b0, 1, 1, 0);
        RSVD.configure(this, 29, 3, "RO", 0, 29'b0, 1, 0, 0);
    endfunction
endclass
"""),
        table(["access", "의미"],
              [["RW", "읽기/쓰기"],
               ["RO", "읽기 전용"],
               ["WO", "쓰기 전용"],
               ["W1C", "1을 쓰면 클리어"],
               ["W1S", "1을 쓰면 셋"],
               ["RC", "읽으면 클리어"],
               ["RS", "읽으면 셋"],
               ["WRC", "쓰기 가능, 읽으면 클리어"]],
              weights=[0.8, 1.6]),

        h2("40.3  레지스터 블록"),
        code("reg_block.svh", """
class dut_reg_block extends uvm_reg_block;
    `uvm_object_utils(dut_reg_block)

    rand ctrl_reg      CTRL;
    rand threshold_reg THRESHOLD;
    rand status_reg    STATUS;

    uvm_reg_map default_map;

    function new(string name = "dut_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        CTRL = ctrl_reg::type_id::create("CTRL");
        CTRL.configure(this, null, "");
        CTRL.build();

        THRESHOLD = threshold_reg::type_id::create("THRESHOLD");
        THRESHOLD.configure(this, null, "");
        THRESHOLD.build();

        STATUS = status_reg::type_id::create("STATUS");
        STATUS.configure(this, null, "");
        STATUS.build();

        // 주소 맵 구성
        default_map = create_map("default_map", 32'h0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(CTRL,      32'h00, "RW");
        default_map.add_reg(THRESHOLD, 32'h04, "RW");
        default_map.add_reg(STATUS,    32'h08, "RO");

        lock_model();       // 주소 맵 확정
    endfunction
endclass
"""),
        key("주소는 한 곳에만",
            "add_reg 의 오프셋이 유일한 주소 정의입니다. "
            "스펙이 바뀌면 이 줄만 고치면 모든 테스트가 따라옵니다."),

        h2("40.4  adapter - RAL 과 버스 연결"),
        p("RAL 은 프로토콜을 모릅니다. adapter 가 uvm_reg_bus_op 를 "
          "실제 버스 트랜잭션으로 번역합니다."),
        code("adapter.svh", """
class apb_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(apb_reg_adapter)

    function new(string name = "apb_reg_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses   = 0;
    endfunction

    // RAL -> 버스 트랜잭션
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_item item = apb_item::type_id::create("item");
        item.addr = rw.addr;
        item.data = rw.data;
        item.we   = (rw.kind == UVM_WRITE);
        return item;
    endfunction

    // 버스 응답 -> RAL
    virtual function void bus2reg(uvm_sequence_item bus_item,
                                  ref uvm_reg_bus_op rw);
        apb_item item;
        if (!$cast(item, bus_item)) begin
            `uvm_fatal("ADAPT", "타입 불일치")
            return;
        end
        rw.kind   = item.we ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.data;
        rw.status = UVM_IS_OK;
    endfunction
endclass
"""),
        code("ral_connect.svh", """
class dut_env extends uvm_env;
    dut_reg_block    regmodel;
    apb_agent        apb_agt;
    apb_reg_adapter  adapter;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        regmodel = dut_reg_block::type_id::create("regmodel");
        regmodel.build();                    // 레지스터 모델 구성
        regmodel.lock_model();
        apb_agt = apb_agent::type_id::create("apb_agt", this);
        adapter = apb_reg_adapter::type_id::create("adapter");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        regmodel.default_map.set_sequencer(apb_agt.seqr, adapter);
        regmodel.default_map.set_auto_predict(1);
    endfunction
endclass
"""),

        h2("40.5  RAL API"),
        table(["메서드", "동작"],
              [["write(status, value)", "DUT 에 실제 쓰기"],
               ["read(status, value)", "DUT 에서 실제 읽기"],
               ["set(value)", "모델의 desired 값만 설정 (버스 접근 없음)"],
               ["get()", "모델의 desired 값 반환"],
               ["update(status)", "desired 와 mirror 가 다르면 write"],
               ["mirror(status, check)", "read 해서 mirror 갱신 (검증 가능)"],
               ["predict(value)", "mirror 를 강제로 설정"],
               ["reset()", "모델을 리셋 값으로"]],
              weights=[1.3, 1.5]),
        code("ral_usage.sv", """
uvm_status_e   status;
uvm_reg_data_t data;

// 필드 단위 조작 후 한 번에 쓰기
regmodel.CTRL.EN  .set(1'b1);
regmodel.CTRL.MODE.set(2'b10);
regmodel.CTRL.update(status);        // 실제 버스 쓰기 1회

// 읽고 모델과 비교
regmodel.STATUS.mirror(status, UVM_CHECK);
if (status != UVM_IS_OK)
    `uvm_error("RAL", "STATUS 읽기 실패")
"""),
        kv([("desired", "우리가 쓰고 싶은 값. set() 이 바꿈"),
            ("mirror", "DUT 에 있을 것으로 예상하는 값"),
            ("update", "desired != mirror 면 write 를 발생"),
            ("mirror(CHECK)", "read 후 mirror 와 비교. 스코어보드 역할")], 82),

        h2("40.6  내장 레지스터 시퀀스"),
        p("UVM 은 표준 레지스터 시험 시퀀스를 제공합니다. "
          "직접 짤 필요가 없습니다."),
        table(["시퀀스", "시험 내용"],
              [["uvm_reg_hw_reset_seq", "리셋 값이 스펙대로인가"],
               ["uvm_reg_bit_bash_seq", "모든 RW 비트가 실제로 동작하는가"],
               ["uvm_reg_access_seq", "read/write 접근이 올바른가"],
               ["uvm_mem_walk_seq", "메모리 주소 디코딩이 맞는가"],
               ["uvm_reg_mem_built_in_seq", "위 전부를 한 번에"]],
              weights=[1.5, 1.4]),
        code("builtin_seq.sv", """
class reg_test extends uvm_test;
    virtual task run_phase(uvm_phase phase);
        uvm_reg_bit_bash_seq seq;
        seq = uvm_reg_bit_bash_seq::type_id::create("seq");
        seq.model = env.regmodel;      // 모델 연결

        phase.raise_objection(this);
        seq.start(null);               // sequencer 는 map 에서 가져감
        phase.drop_objection(this);
    endtask
endclass
"""),
        tip("RAL 도입 판단 기준",
            "레지스터가 10개 미만이면 RAL 설정 비용이 더 큽니다. "
            "수십 개를 넘어가고 스펙이 계속 바뀌는 프로젝트에서 "
            "진가가 나옵니다. 학부 과제 수준에서는 개념만 알아두면 "
            "충분합니다."),

        h2("40.7  실습"),
        lab("과제 40-A",
            "레지스터 DUT 를 32비트 CTRL 레지스터 하나로 보고 "
            "uvm_reg 모델을 작성하세요."),
        quiz("regmodel.CTRL.set(1) 만 하고 update 를 안 부르면?",
             ["① DUT 에 값이 써진다",
              "② 모델의 desired 값만 바뀌고 DUT 는 그대로",
              "③ 에러가 난다",
              "④ mirror 가 바뀐다"],
             "② — set() 은 버스 접근을 하지 않습니다. "
             "실제 쓰기는 update() 나 write() 가 합니다."),
    ],
}


# ==========================================================================
CH41 = {
    "number": "CHAPTER 41",
    "title": "재사용 가능한 VIP 설계",
    "goals": [
        "VIP 의 경계를 정한다",
        "설정 객체로 동작을 파라미터화한다",
        "패키지와 인터페이스를 배포 가능하게 만든다",
        "재사용을 막는 안티패턴을 피한다",
    ],
    "body": [
        lead("VIP(Verification IP)는 다른 프로젝트에 그대로 가져다 쓸 수 있는 "
             "검증 부품입니다. 재사용은 우연히 생기지 않고 "
             "처음부터 그렇게 설계해야 얻어집니다."),

        h2("41.1  VIP 의 경계"),
        art("""
   VIP 에 포함되는 것            VIP 밖에 두는 것

   interface                     DUT
   sequence_item                 top module
   driver / monitor              스코어보드 (프로젝트마다 다름)
   sequencer / agent             테스트 시나리오
   기본 sequence 라이브러리       DUT 별 커버리지
   config 객체
   커버리지 (프로토콜 자체)
"""),
        key("판단 기준",
            "'다른 DUT 에도 그대로 쓸 수 있는가'를 물으세요. "
            "프로토콜에 속하면 VIP 안, 이 DUT 에만 해당하면 VIP 밖입니다."),

        h2("41.2  설정 객체로 파라미터화"),
        code("vip_config.svh", """
class apb_config extends uvm_object;
    `uvm_object_utils(apb_config)

    // 연결
    virtual apb_if vif;

    // 동작 모드
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit                     has_coverage = 1;
    bit                     has_checks   = 1;

    // 프로토콜 파라미터
    int unsigned addr_width = 32;
    int unsigned data_width = 32;
    int unsigned min_delay  = 0;
    int unsigned max_delay  = 5;

    function new(string name = "apb_config");
        super.new(name);
    endfunction
endclass
"""),
        code("vip_use_config.svh", """
class apb_agent extends uvm_agent;
    apb_config cfg;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(apb_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("CFG", "apb_config 를 찾을 수 없습니다")

        // 설정에 따라 구성을 바꾼다
        if (cfg.has_coverage)
            cov = apb_coverage::type_id::create("cov", this);

        mon = apb_monitor::type_id::create("mon", this);

        if (cfg.is_active == UVM_ACTIVE) begin
            seqr = apb_sequencer::type_id::create("seqr", this);
            drv  = apb_driver   ::type_id::create("drv",  this);
        end

        // 자식에게 그대로 전달
        uvm_config_db #(apb_config)::set(this, "*", "cfg", cfg);
    endfunction
endclass
"""),
        tip("get_is_active 대신 cfg 를 쓰는 이유",
            "uvm_agent 의 is_active 필드는 config_db 로 따로 설정해야 하는데, "
            "cfg 객체 하나로 통일하면 설정 지점이 한 곳으로 모입니다."),

        h2("41.3  재사용을 막는 안티패턴"),
        table(["안티패턴", "왜 문제인가", "대안"],
              [["절대 경로 하드코딩", "다른 계층에서 못 씀",
                "config_db 상대 경로"],
               ["DUT 신호 직접 참조", "DUT 가 바뀌면 깨짐",
                "interface 만 참조"],
               ["프로젝트 이름을 클래스명에", "다른 프로젝트에서 어색",
                "프로토콜 이름 사용"],
               ["스코어보드를 agent 안에", "DUT 별 로직이 섞임",
                "env 레벨로 분리"],
               ["설정을 코드에 하드코딩", "테스트마다 재컴파일",
                "config 객체"],
               ["파일 하나에 전부", "부분 재사용 불가",
                "파일 분리 + package"]],
              weights=[1.2, 1.2, 1.2]),
        code("antipattern.sv", """
// 나쁜 예: 절대 경로
uvm_config_db #(int)::get(null,
    "uvm_test_top.env.apb_agt.drv", "delay", delay);
//   ^^^^^^^^^^^^^^^^^^^^^^^ 이 계층이 아니면 못 씀

// 좋은 예: 상대 경로
uvm_config_db #(int)::get(this, "", "delay", delay);
"""),
        code("antipattern2.sv", """
// 나쁜 예: DUT 계층 직접 참조
if (tb_top.dut.internal_state == 3) ...
//  ^^^^^^^^^^^^^^^^^^^^^^^^^ DUT 구조에 의존

// 좋은 예: interface 신호만
if (vif.cb.state == 3) ...
"""),

        h2("41.4  파일 배포 구조"),
        code("vip_package.txt", """
apb_vip/
  src/
      apb_if.sv              interface (package 밖)
      apb_pkg.sv             package 진입점
      apb_item.svh
      apb_config.svh
      apb_driver.svh
      apb_monitor.svh
      apb_sequencer.svh
      apb_agent.svh
      apb_coverage.svh
      apb_seq_lib.svh        기본 시퀀스 모음
  doc/
      apb_vip_userguide.md
  examples/
      simple_tb/
  apb_vip.f                  파일 목록 (컴파일 순서)
"""),
        code("apb_vip.f", """
# 컴파일 순서를 파일로 관리
+incdir+./src
./src/apb_if.sv
./src/apb_pkg.sv
"""),
        note("-f 옵션",
             "xvlog -f apb_vip.f 처럼 파일 목록을 넘길 수 있습니다. "
             "VIP 사용자는 이 파일 하나만 포함하면 됩니다.",
             "info"),

        h2("41.5  기본 시퀀스 라이브러리"),
        code("seq_lib.svh", """
// VIP 사용자가 바로 쓸 수 있는 기본 시퀀스들
class apb_base_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_base_seq)
    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction
endclass

class apb_single_write_seq extends apb_base_seq;
    `uvm_object_utils(apb_single_write_seq)
    rand bit [31:0] addr, data;
    ...
endclass

class apb_single_read_seq extends apb_base_seq;   ... endclass
class apb_random_seq      extends apb_base_seq;   ... endclass
class apb_burst_seq       extends apb_base_seq;   ... endclass
"""),
        key("base 시퀀스를 두라",
            "사용자가 apb_base_seq 를 상속해 자기 시나리오를 만들 수 "
            "있습니다. 공통 유틸리티를 base 에 두면 모든 파생 시퀀스가 "
            "물려받습니다."),

        h2("41.6  VIP 사용자 가이드"),
        p("VIP 는 다른 사람이 씁니다. 코드가 아무리 좋아도 "
          "어떻게 쓰는지 모르면 재사용되지 않습니다. "
          "최소한 아래 다섯 가지는 문서로 남기세요."),
        code("userguide_template.md", """
# APB VIP 사용 가이드

## 1. 파일 포함
    xvlog -sv -f apb_vip/apb_vip.f

## 2. 최소 연결 (top module)
    apb_if apb_bus (clk);
    my_dut dut (.pclk(clk), .psel(apb_bus.psel), ...);

    initial begin
        apb_config cfg = new("cfg");
        cfg.vif       = apb_bus;
        cfg.is_active = UVM_ACTIVE;
        uvm_config_db #(apb_config)::set(null, "*", "cfg", cfg);
        run_test();
    end

## 3. 설정 항목
    | 필드          | 기본값     | 의미                      |
    |---------------|-----------|---------------------------|
    | is_active     | UVM_ACTIVE| 자극 생성 여부            |
    | has_coverage  | 1         | 커버리지 컬렉터 인스턴스화|
    | has_checks    | 1         | 프로토콜 assertion 활성   |
    | min/max_delay | 0 / 5     | 트랜잭션 사이 지연 범위   |

## 4. 제공 시퀀스
    apb_single_write_seq   addr, data 를 지정해 1회 쓰기
    apb_single_read_seq    addr 를 지정해 1회 읽기
    apb_random_seq         n 회 무작위 (n 은 rand)
    apb_burst_seq          연속 주소로 n 회

## 5. 확장 방법
    - 새 시퀀스: apb_base_seq 를 상속
    - 자극 변조: apb_driver_cb 의 pre_drive 훅
    - 아이템 교체: factory override (apb_item 의 자식이어야 함)

## 6. 알려진 제약
    - APB3 까지 지원. APB4 의 PSTRB 는 미지원
    - 슬레이브 모델은 포함하지 않음 (마스터 전용)
"""),
        table(["문서 항목", "없으면 생기는 질문"],
              [["파일 포함 방법", "어떤 파일을 어떤 순서로 컴파일하나"],
               ["최소 연결 예제", "config_db 에 뭘 넣어야 하나"],
               ["설정 항목 표", "어떤 옵션이 있는지 소스를 뒤져야 함"],
               ["제공 시퀀스 목록", "직접 만들어야 하나 있는 걸 쓰나"],
               ["확장 방법", "동작을 바꾸려면 소스를 고쳐야 하나"],
               ["알려진 제약", "안 되는 걸 몰라서 며칠 헤맴"]],
              weights=[1.1, 1.7]),
        key("examples 디렉터리가 최고의 문서",
            "동작하는 최소 예제 하나가 문서 열 장보다 낫습니다. "
            "사용자는 그것을 복사해서 시작합니다. "
            "그리고 예제가 컴파일되는지 CI 로 확인하면 문서가 낡지 않습니다."),

        h2("41.7  버전 관리"),
        code("vip_version.svh", """
package apb_pkg;
    // 버전을 코드에 남긴다
    localparam string APB_VIP_VERSION = "1.3.0";

    class apb_agent extends uvm_agent;
        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            `uvm_info("VIP", {"APB VIP version ", APB_VIP_VERSION}, UVM_LOW)
        endfunction
    endclass
endpackage
"""),
        p("로그에 버전이 찍히면 '어느 버전에서 난 문제인가'를 "
          "바로 알 수 있습니다. VIP 를 여러 프로젝트가 공유할 때 "
          "특히 중요합니다."),

        h2("41.8  실습"),
        lab("과제 41-A",
            "가산기 에이전트를 VIP 로 재구성하세요. "
            "config 객체를 만들고 has_coverage 옵션으로 "
            "커버리지 컬렉터를 켜고 끌 수 있게 하세요."),
        quiz("스코어보드를 agent 안에 두면 안 되는 이유는?",
             ["① 성능 문제",
              "② DUT 별 로직이라 다른 프로젝트에서 재사용 못 함",
              "③ UVM 규칙 위반",
              "④ analysis_port 연결이 안 됨"],
             "② — agent 는 프로토콜만 알아야 합니다. "
             "'이 DUT 의 정답이 무엇인가'는 프로젝트마다 다르므로 "
             "env 레벨에 두어야 재사용이 됩니다."),
    ],
}


# ==========================================================================
CH42 = {
    "number": "CHAPTER 42",
    "title": "UVM callback",
    "goals": [
        "callback 으로 확장점을 만든다",
        "factory override 와 비교해 선택한다",
        "에러 주입에 callback 을 활용한다",
        "callback 등록과 해제를 관리한다",
    ],
    "body": [
        lead("factory override 는 클래스 전체를 갈아끼웁니다. "
             "'드라이버의 한 지점에만 훅을 걸고 싶다'면 callback 이 "
             "더 알맞습니다."),

        h2("42.1  callback 클래스 정의"),
        code("callback_def.svh", """
class apb_driver_cb extends uvm_callback;
    `uvm_object_utils(apb_driver_cb)

    function new(string name = "apb_driver_cb");
        super.new(name);
    endfunction

    // 훅 지점들 - 기본은 아무것도 안 함
    virtual task pre_drive (apb_driver drv, apb_item item); endtask
    virtual task post_drive(apb_driver drv, apb_item item); endtask
endclass

// 드라이버와 callback 타입을 연결
typedef uvm_callbacks #(apb_driver, apb_driver_cb) apb_drv_cb_t;
"""),
        code("callback_hook.svh", """
class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    `uvm_register_cb(apb_driver, apb_driver_cb)   // 등록 가능 선언

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);

            `uvm_do_callbacks(apb_driver, apb_driver_cb,
                              pre_drive(this, req))

            drive_item(req);

            `uvm_do_callbacks(apb_driver, apb_driver_cb,
                              post_drive(this, req))

            seq_item_port.item_done();
        end
    endtask
endclass
"""),

        h2("42.2  callback 구현과 등록"),
        code("callback_impl.svh", """
// 에러 주입 callback
class corrupt_cb extends apb_driver_cb;
    `uvm_object_utils(corrupt_cb)

    int unsigned corrupt_rate = 10;    // 10% 확률로 손상

    function new(string name = "corrupt_cb");
        super.new(name);
    endfunction

    virtual task pre_drive(apb_driver drv, apb_item item);
        if ($urandom_range(99) < corrupt_rate) begin
            item.data ^= (1 << $urandom_range(31));   // 비트 하나 뒤집기
            `uvm_info("CB", $sformatf("데이터 손상 주입: 0x%08h",
                       item.data), UVM_LOW)
        end
    endtask
endclass
"""),
        code("callback_register.svh", """
class corrupt_test extends base_test;
    `uvm_component_utils(corrupt_test)

    virtual function void connect_phase(uvm_phase phase);
        corrupt_cb cb;
        super.connect_phase(phase);

        cb = corrupt_cb::type_id::create("cb");
        cb.corrupt_rate = 20;

        // 특정 드라이버에 등록
        apb_drv_cb_t::add(env.agt.drv, cb);

        // 모든 apb_driver 에 등록하려면 첫 인자를 null 로
        // apb_drv_cb_t::add(null, cb);
    endfunction
endclass
"""),
        table(["메서드", "동작"],
              [["add(obj, cb)", "등록 (맨 뒤)"],
               ["add(obj, cb, UVM_PREPEND)", "맨 앞에 등록"],
               ["delete(obj, cb)", "등록 해제"],
               ["add(null, cb)", "그 타입 전체에 등록"],
               ["display()", "등록된 callback 목록 출력"]],
              weights=[1.3, 1.3]),

        h2("42.3  callback vs factory override"),
        table(["기준", "callback", "factory override"],
              [["교체 단위", "메서드의 특정 지점", "클래스 전체"],
               ["여러 개 동시", "가능 (순서대로 실행)", "하나만"],
               ["런타임 추가/제거", "가능", "불가 (build 시점 고정)"],
               ["기존 코드 수정", "훅 지점을 미리 심어야 함", "불필요"],
               ["적합한 상황", "에러 주입, 로깅, 통계", "동작 자체를 바꿀 때"]],
              weights=[1.0, 1.3, 1.3]),
        key("선택 기준",
            "'기존 동작에 뭔가를 덧붙인다'면 callback, "
            "'동작을 다른 것으로 대체한다'면 factory override 입니다."),
        warn("훅 지점은 미리 설계해야 한다",
             "callback 은 VIP 작성자가 `uvm_do_callbacks 를 심어둔 곳에만 "
             "걸 수 있습니다. VIP 를 만들 때 확장 가능성이 있는 지점에 "
             "미리 훅을 넣어 두어야 합니다."),

        h2("42.4  실무에서 자주 쓰는 훅 지점"),
        ul("driver: pre_drive / post_drive - 자극 변조, 지연 삽입",
           "monitor: post_collect - 트랜잭션 필터링, 추가 검사",
           "scoreboard: pre_compare - 비교 대상 조정",
           "sequence: pre_body / post_body - 초기화, 정리",
           "sequence_item: post_randomize - 값 후처리"),

        h2("42.5  실습"),
        lab("과제 42-A",
            "가산기 드라이버에 pre_drive callback 훅을 심고, "
            "10% 확률로 a 값을 손상시키는 callback 을 등록해 "
            "스코어보드가 잡아내는지 확인하세요."),
        quiz("callback 과 factory override 를 동시에 쓸 수 있는가?",
             ["① 불가능하다",
              "② 가능하다. 서로 독립적인 메커니즘이다",
              "③ callback 이 우선한다",
              "④ override 가 callback 을 무효화한다"],
             "② — override 로 클래스를 바꾸고, 그 클래스에 callback 을 "
             "등록할 수 있습니다. 두 메커니즘은 서로 간섭하지 않습니다."),
    ],
}


# ==========================================================================
CH43 = {
    "number": "CHAPTER 43",
    "title": "시뮬레이션 성능 최적화",
    "goals": [
        "성능 병목을 측정한다",
        "uvm_field 매크로의 비용을 안다",
        "로그와 파형 덤프를 조절한다",
        "회귀 처리량을 높인다",
    ],
    "body": [
        lead("회귀 500회를 돌리는데 한 번에 30분이면 250시간입니다. "
             "성능은 검증 일정에 직접 영향을 줍니다. "
             "몇 가지 원칙만 지켜도 배 이상 빨라지는 경우가 흔합니다."),

        h2("43.1  병목 측정이 먼저"),
        code("profiling.sh", """
# Vivado xsim 프로파일링
xelab -profile tb_adder -s tb_snapshot
xsim tb_snapshot -R

# 결과에서 시간을 많이 쓰는 프로세스를 확인
"""),
        code("simple_timing.sv", """
// 간단한 구간 측정
time t_start;
virtual task run_phase(uvm_phase phase);
    t_start = $realtime;
    ...
    `uvm_info("PERF", $sformatf("소요 %0t", $realtime - t_start), UVM_NONE)
endtask
"""),
        warn("추측하지 말고 측정하라",
             "성능 문제의 원인은 대부분 예상과 다릅니다. "
             "'매크로가 느릴 것 같아서' 같은 추측으로 코드를 고치면 "
             "가독성만 잃고 성능은 그대로인 경우가 많습니다."),

        h2("43.2  uvm_field 매크로"),
        p("가장 자주 지목되는 병목입니다. field 매크로는 문자열 기반 "
          "리플렉션 코드를 생성해 print/copy/compare 를 처리합니다."),
        code("field_cost.sv", """
// 느린 쪽: 매크로가 문자열 비교로 필드를 순회
`uvm_object_utils_begin(seq_item)
    `uvm_field_int(a, UVM_DEFAULT)
    `uvm_field_int(b, UVM_DEFAULT)
    `uvm_field_int(y, UVM_DEFAULT)
`uvm_object_utils_end

// 빠른 쪽: 직접 구현
`uvm_object_utils(seq_item)

virtual function void do_copy(uvm_object rhs);
    seq_item t;
    super.do_copy(rhs);
    $cast(t, rhs);
    a = t.a;  b = t.b;  y = t.y;    // 직접 대입
endfunction
"""),
        table(["트랜잭션 수", "매크로 방식", "권장"],
              [["~1만", "차이 미미", "매크로 (편의성 우선)"],
               ["10만~100만", "10~30% 느림", "상황에 따라"],
               ["100만 이상", "2배 이상 느릴 수 있음", "do_ 메서드 직접 구현"]],
              weights=[1.0, 1.2, 1.3]),
        tip("절충안",
            "필요한 필드만 매크로로 등록하고, 자주 안 쓰는 것은 "
            "UVM_NOPRINT | UVM_NOCOMPARE 플래그로 빼세요. "
            "매크로의 편의는 유지하면서 비용을 줄일 수 있습니다."),

        h2("43.3  로그 줄이기"),
        code("log_cost.sv", """
// 나쁜 예: 출력 안 해도 문자열을 조립한다
string msg = $sformatf("a=%0d b=%0d", item.a, item.b);
`uvm_info("DRV", msg, UVM_HIGH)

// 좋은 예: 매크로 안에서 조립 -> 출력 안 하면 조립도 안 함
`uvm_info("DRV", $sformatf("a=%0d b=%0d", item.a, item.b), UVM_HIGH)
"""),
        key("매크로 안에서 조립하라",
            "23장에서 본 대로 uvm_info 매크로는 verbosity 검사를 먼저 "
            "합니다. 인자로 넘기는 $sformatf 는 출력할 때만 평가됩니다. "
            "밖에서 미리 조립하면 이 최적화가 무효가 됩니다."),
        code("regression_verbosity.sh", """
# 회귀에서는 로그를 최소로
xsim tb_snapshot -R +UVM_VERBOSITY=UVM_LOW

# 실패한 시드만 다시 상세하게
xsim tb_snapshot -R +UVM_VERBOSITY=UVM_HIGH -sv_seed 317
"""),

        h2("43.4  파형 덤프 조절"),
        code("selective_dump.sv", """
// 나쁜 예: 전체 계층을 덤프
initial begin
    $dumpvars(0, tb_adder);        // 수 GB 파일이 될 수 있다
end

// 좋은 예: 필요한 부분만
initial begin
    $dumpvars(1, tb_adder.dut);    // DUT 만, 깊이 1
    $dumpvars(0, tb_adder.a_if);   // interface 전체
end

// 더 좋은 예: 옵션으로 켜고 끄기
initial begin
    if ($test$plusargs("DUMP")) begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_adder);
    end
end
"""),
        table(["설정", "상대 속도"],
              [["덤프 없음", "1.0x (기준)"],
               ["DUT 만 덤프", "1.2~1.5x 느림"],
               ["전체 계층 덤프", "3~10x 느림"],
               ["전체 + 클래스 객체", "10x 이상"]],
              weights=[1.3, 1.0]),
        key("회귀에서는 덤프를 끈다",
            "실패한 시드만 덤프를 켜고 다시 돌리면 됩니다. "
            "회귀 전체에 덤프를 켜는 것은 가장 흔한 성능 낭비입니다."),

        h2("43.5  기타 최적화"),
        ol("불필요한 객체 생성을 줄인다 - 루프 안에서 매번 create 하는 대신 "
           "재사용 가능한 것은 재사용",
           "큐가 무한정 커지지 않게 한다 - 스코어보드 큐가 비워지는지 확인",
           "randomize 호출을 줄인다 - 제약 솔버는 비싸다. "
           "고정값으로 충분하면 고정값을 쓴다",
           "covergroup 샘플링 빈도를 줄인다 - 매 클럭 대신 트랜잭션 단위",
           "assertion 을 필요한 구간에만 켠다 - $assertoff/$asserton",
           "4-state 대신 2-state 를 쓴다 - 테스트벤치 내부 계산 변수에 한해"),
        code("randomize_cost.sv", """
// 느림: 매번 제약 솔버 호출
repeat (10000) begin
    item = seq_item::type_id::create("item");
    start_item(item);
    void'(item.randomize());
    finish_item(item);
end

// 빠름: 미리 만들어 둔 값 사용 (방향 테스트일 때)
bit [7:0] patterns[] = '{0, 1, 127, 128, 255};
foreach (patterns[i]) begin
    item = seq_item::type_id::create("item");
    start_item(item);
    item.a = patterns[i];
    finish_item(item);
end
"""),

        h2("43.6  회귀 처리량"),
        code("parallel_regression.sh", """
# 여러 시드를 병렬로 (코어 수만큼)
seq 1 100 | xargs -P 8 -I {} ./run.sh random_test {}

# 각 실행이 별도 디렉터리를 쓰도록
run_seed() {
    mkdir -p work_$1 && cd work_$1
    xsim ../tb_snapshot -R -sv_seed $1 -log run.log
}
"""),
        tip("컴파일은 한 번만",
            "xelab 으로 만든 snapshot 을 여러 xsim 이 공유할 수 있습니다. "
            "시드마다 재컴파일하면 시간의 대부분을 컴파일에 씁니다."),

        h2("43.7  실습"),
        lab("과제 43-A",
            "가산기 환경에서 트랜잭션 10만 개를 돌리고, "
            "(a) 파형 덤프 유무, (b) verbosity, (c) field 매크로 유무 "
            "각각의 실행 시간을 측정해 표로 정리하세요."),
        quiz("`uvm_info 의 메시지를 미리 변수에 조립해 넘기면?",
             ["① 더 빠르다",
              "② verbosity 최적화가 무효화되어 느려진다",
              "③ 차이 없다",
              "④ 컴파일 에러"],
             "② — 매크로 밖에서 조립하면 출력하지 않을 메시지도 "
             "무조건 조립됩니다. 매크로의 지연 평가 이점이 사라집니다."),
    ],
}


# ==========================================================================
CH44 = {
    "number": "CHAPTER 44",
    "title": "DPI-C 연동",
    "goals": [
        "DPI 로 C 함수를 호출한다",
        "레퍼런스 모델을 C 로 구현한다",
        "자료형 대응 규칙을 안다",
        "DPI 사용 시 주의점을 안다",
    ],
    "body": [
        lead("레퍼런스 모델이 복잡하면 SystemVerilog 로 다시 짜는 것이 "
             "비효율적입니다. 이미 C 로 된 모델이 있다면 그대로 "
             "가져다 쓸 수 있습니다."),

        h2("44.1  기본 사용"),
        code("model.c", """
#include <stdint.h>

// 가산기 레퍼런스 모델
uint32_t ref_add(uint8_t a, uint8_t b) {
    return (uint32_t)a + (uint32_t)b;
}

// 더 복잡한 예: CRC 계산
uint32_t ref_crc32(const uint8_t *data, int len) {
    uint32_t crc = 0xFFFFFFFF;
    for (int i = 0; i < len; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++)
            crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
    return ~crc;
}
"""),
        code("dpi_import.sv", """
// SystemVerilog 쪽 선언
import "DPI-C" function int unsigned ref_add(byte unsigned a,
                                             byte unsigned b);

// 스코어보드에서 사용
virtual function void write(seq_item t);
    bit [8:0] exp = ref_add(t.a, t.b);     // C 함수 호출
    if (t.y !== exp)
        `uvm_error("SCB", "불일치")
endfunction
"""),
        code("compile_dpi.sh", """
# Vivado
xsc model.c                              # C 를 공유 라이브러리로
xelab -L uvm -sv_lib xsc.dir/dpi tb_adder -s tb_snapshot
xsim tb_snapshot -R
"""),

        h2("44.2  자료형 대응"),
        table(["SystemVerilog", "C", "비고"],
              [["byte", "char", "8비트 signed"],
               ["byte unsigned", "unsigned char", ""],
               ["shortint", "short int", "16비트"],
               ["int", "int", "32비트"],
               ["longint", "long long", "64비트"],
               ["real", "double", ""],
               ["string", "const char*", ""],
               ["bit [N-1:0]", "svBitVecVal*", "N > 32 일 때"],
               ["logic [N-1:0]", "svLogicVecVal*", "4-state"]],
              weights=[1.2, 1.2, 1.0]),
        warn("4-state 는 전달이 번거롭다",
             "C 에는 X/Z 개념이 없습니다. logic 을 넘기면 "
             "svLogicVecVal 구조체를 직접 다뤄야 합니다. "
             "가능하면 bit(2-state)로 변환해서 넘기세요."),

        h2("44.3  export - C 에서 SV 호출"),
        code("dpi_export.sv", """
// SystemVerilog 함수를 C 에 노출
export "DPI-C" function sv_log;

function void sv_log(string msg);
    `uvm_info("DPI", msg, UVM_LOW)
endfunction
"""),
        code("call_from_c.c", """
extern void sv_log(const char *msg);

uint32_t ref_add(uint8_t a, uint8_t b) {
    char buf[128];
    sprintf(buf, "ref_add(%d, %d)", a, b);
    sv_log(buf);                    // SV 함수 호출
    return (uint32_t)a + b;
}
"""),

        h2("44.4  배열 전달"),
        code("dpi_array.sv", """
import "DPI-C" function int unsigned ref_crc32(
    input byte unsigned data[], input int len);

// 사용
byte unsigned payload[];
payload = new[64];
foreach (payload[i]) payload[i] = $urandom_range(255);
crc = ref_crc32(payload, payload.size());
"""),
        code("dpi_array.c", """
#include "svdpi.h"

uint32_t ref_crc32(const svOpenArrayHandle data, int len) {
    uint8_t *p = (uint8_t *)svGetArrayPtr(data);
    // ... p 를 len 만큼 순회
}
"""),

        h2("44.5  주의점"),
        ol("DPI 함수 안에서 시간을 소비할 수 없다 - context task 가 필요하면 "
           "import \"DPI-C\" context task 로 선언",
           "C 쪽 메모리 관리는 C 책임 - malloc 한 것은 free 해야 한다",
           "시뮬레이터마다 컴파일 방법이 다르다 - xsc / vlog -dpi / vcs -cflags",
           "디버깅이 어렵다 - C 쪽 에러는 시뮬레이터가 그냥 죽는 형태로 나온다",
           "포팅 비용을 고려하라 - 팀원이 C 를 못 다루면 유지보수가 어렵다"),
        key("언제 쓸 가치가 있나",
            "① 이미 검증된 C 모델이 있을 때 "
            "② 알고리즘이 복잡해 SV 로 다시 짜면 그 자체에 버그가 날 때 "
            "③ 성능이 중요한 대량 연산일 때. "
            "단순한 모델을 굳이 C 로 옮길 이유는 없습니다."),

        h2("44.6  실습"),
        lab("과제 44-A",
            "가산기 레퍼런스 모델을 C 로 작성하고 DPI 로 연동해 "
            "스코어보드가 그것을 쓰도록 하세요."),
        quiz("DPI import 함수 안에서 #10 처럼 시간을 소비하려면?",
             ["① 그냥 쓰면 된다",
              "② import \"DPI-C\" context task 로 선언해야 한다",
              "③ 불가능하다",
              "④ export 로 선언한다"],
             "② — function 은 시간을 못 씁니다. task 로 선언하고 "
             "context 를 붙여야 시뮬레이터 컨텍스트에 접근할 수 있습니다."),
    ],
}


# ==========================================================================
CH45 = {
    "number": "CHAPTER 45",
    "title": "검증 환경 리팩터링",
    "goals": [
        "환경의 냄새를 식별한다",
        "안전하게 구조를 개선한다",
        "코드 리뷰 관점을 익힌다",
        "장기 유지보수 가능한 환경을 만든다",
    ],
    "body": [
        lead("검증 환경은 프로젝트 내내 자랍니다. 처음의 깔끔한 구조가 "
             "6개월 뒤에는 알아볼 수 없게 되는 일이 흔합니다. "
             "이 장은 그것을 되돌리는 방법입니다."),

        h2("45.1  환경의 냄새"),
        table(["냄새", "무엇을 뜻하나", "대응"],
              [["테스트마다 env 를 새로 구성", "base_test 가 없거나 부실",
                "공통 구성을 base_test 로"],
               ["시퀀스에 if (test_name == ...)", "시나리오와 제어가 섞임",
                "시퀀스를 분리"],
               ["드라이버에 DUT 지식", "추상화 경계 붕괴",
                "레퍼런스 로직을 스코어보드로"],
               ["동일 코드가 여러 시퀀스에", "공통 base 시퀀스 부재",
                "상속으로 추출"],
               ["config_db 호출이 산재", "설정 지점이 흩어짐",
                "config 객체로 통합"],
               ["매직 넘버가 코드 곳곳에", "파라미터화 부족",
                "parameter 또는 config"],
               ["주석으로 켜고 끄는 코드", "설정 메커니즘 부재",
                "config 플래그로"]],
              weights=[1.2, 1.2, 1.2]),

        h2("45.2  안전한 리팩터링 순서"),
        ol("현재 회귀가 모두 통과하는지 확인한다 - 기준선 확보",
           "커버리지 리포트를 저장한다 - 리팩터링 후 비교용",
           "한 번에 하나만 바꾼다",
           "매 단계마다 회귀를 돌린다",
           "커버리지가 떨어지지 않았는지 확인한다",
           "커밋을 작게 나눈다 - 되돌리기 쉽게"),
        key("기준선 없이 리팩터링하지 마라",
            "리팩터링 후 실패가 나면 '원래 실패였는가 내가 깬 것인가'를 "
            "구분할 수 없습니다. 시작 전에 통과 상태를 기록하세요."),

        h2("45.3  흔한 리팩터링 - base_test 추출"),
        code("before_refactor.sv", """
// 각 테스트가 env 를 따로 만든다
class test_a extends uvm_test;
    my_env env;
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = my_env::type_id::create("env", this);
        uvm_config_db#(int)::set(this, "env.agt.drv", "delay", 3);
    endfunction
    virtual task run_phase(uvm_phase phase); ... endtask
endclass

class test_b extends uvm_test;
    my_env env;
    virtual function void build_phase(uvm_phase phase);   // 중복
        super.build_phase(phase);
        env = my_env::type_id::create("env", this);
        uvm_config_db#(int)::set(this, "env.agt.drv", "delay", 3);
    endfunction
    virtual task run_phase(uvm_phase phase); ... endtask
endclass
"""),
        code("after_refactor.sv", """
class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    my_env    env;
    my_config cfg;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = my_config::type_id::create("cfg");
        configure(cfg);                      // 자식이 덮어쓸 수 있는 훅
        uvm_config_db#(my_config)::set(this, "env*", "cfg", cfg);
        env = my_env::type_id::create("env", this);
    endfunction

    // 자식이 설정만 바꾸면 되는 훅
    virtual function void configure(my_config c);
        c.delay = 3;
    endfunction

    // 자식이 시퀀스만 지정하면 되는 훅
    virtual function uvm_sequence get_sequence();
        return null;
    endfunction

    virtual task run_phase(uvm_phase phase);
        uvm_sequence seq = get_sequence();
        if (seq == null) return;
        phase.raise_objection(this);
        seq.start(env.agt.seqr);
        phase.drop_objection(this);
    endtask
endclass

// 이제 테스트가 짧아진다
class test_a extends base_test;
    `uvm_component_utils(test_a)
    virtual function uvm_sequence get_sequence();
        return seq_a::type_id::create("seq");
    endfunction
endclass

class test_b extends base_test;
    `uvm_component_utils(test_b)
    virtual function void configure(my_config c);
        super.configure(c);
        c.delay = 10;                        // 이것만 다르다
    endfunction
    virtual function uvm_sequence get_sequence();
        return seq_b::type_id::create("seq");
    endfunction
endclass
"""),
        key("훅 메서드 패턴",
            "base 가 전체 흐름을 정하고, 자식은 훅만 채웁니다. "
            "테스트가 20개로 늘어나도 각각 열 줄 안쪽입니다. "
            "template method 패턴이라 부릅니다."),

        h2("45.4  코드 리뷰 관점"),
        h3("구조"),
        ul("드라이버가 DUT 의 정답을 알고 있지 않은가",
           "모니터가 신호를 구동하지 않는가",
           "스코어보드가 agent 안에 있지 않은가",
           "테스트가 env 구성을 중복하지 않는가"),
        h3("정확성"),
        ul("get_next_item 과 item_done 이 1:1 인가 (예외 경로 포함)",
           "randomize() 반환값을 검사하는가",
           "비교에 !== 를 쓰는가 (X 처리)",
           "check_phase 에서 미처리 항목을 검사하는가",
           "report_phase 에서 비교 횟수 0 을 검사하는가"),
        h3("견고성"),
        ul("config_db get 실패 시 fatal 을 내는가",
           "clone 없이 핸들을 넘기지 않는가",
           "objection 을 test 에서만 다루는가",
           "타임아웃이 설정되어 있는가"),

        h2("45.5  장기 유지보수 원칙"),
        ol("문서를 코드 옆에 둔다 - 별도 문서는 반드시 낡는다",
           "설정 지점을 한 곳으로 모은다 - config 객체",
           "이름 규칙을 정하고 지킨다 - _seq, _item, _agent 같은 접미사",
           "테스트를 작게 유지한다 - 열 줄을 넘으면 base 로 뺄 것이 있다",
           "죽은 코드를 지운다 - 주석 처리한 코드는 버전 관리에 맡긴다",
           "정기적으로 회귀 시간을 측정한다 - 느려지면 원인을 찾는다"),

        h2("45.6  실습"),
        lab("과제 45-A",
            "33장에서 만든 가산기 환경의 테스트들을 base_test + 훅 메서드 "
            "패턴으로 리팩터링하세요. 각 테스트가 열 줄 이내가 되어야 합니다."),
        lab("과제 45-B",
            "위 코드 리뷰 체크리스트로 자기 환경을 점검하고 "
            "발견한 문제를 목록으로 만드세요."),
        quiz("리팩터링 전에 반드시 해야 할 일은?",
             ["① 문서 작성",
              "② 현재 회귀 통과 상태와 커버리지를 기록 (기준선 확보)",
              "③ 코드 백업",
              "④ 팀 회의"],
             "② — 기준선이 없으면 리팩터링이 무언가를 깼는지 알 수 "
             "없습니다. 통과 상태와 커버리지를 먼저 기록하세요."),
    ],
}


CHAPTERS = [CH39, CH40, CH41, CH42, CH43, CH44, CH45]
