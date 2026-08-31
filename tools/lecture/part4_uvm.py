"""Part IV - UVM 핵심 (계층 / factory / phase / config_db / sequence / TLM)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART IV",
    "title": "UVM 핵심 메커니즘",
    "blurb": "UVM 은 규칙이 많은 라이브러리입니다. 그러나 그 규칙들은 "
             "'테스트벤치를 고치지 않고 테스트를 바꾼다'는 하나의 목표에서 "
             "나왔습니다. factory, phase, config_db, sequence 를 그 목표와 "
             "연결해 이해하면 암기할 것이 크게 줄어듭니다.",
    "items": [
        "22장 UVM 계층 구조와 uvm_object / uvm_component",
        "23장 report 매크로와 verbosity",
        "24장 factory (1) - registry 와 type_id",
        "25장 factory (2) - create 흐름과 override",
        "26장 phase 메커니즘",
        "27장 config_db",
        "28장 sequence_item",
        "29장 sequence 와 sequencer",
        "30장 driver 와 handshake",
        "31장 monitor · agent · env · TLM",
    ],
}


# ==========================================================================
CH22 = {
    "number": "CHAPTER 22",
    "title": "UVM 계층 구조",
    "goals": [
        "uvm_object 와 uvm_component 를 구분한다",
        "컴포넌트 계층 트리의 의미를 안다",
        "표준 테스트벤치 구성을 그린다",
        "각 부품의 책임 경계를 설명한다",
    ],
    "body": [
        lead("UVM 클래스는 크게 두 갈래입니다. 시뮬레이션 내내 존재하며 "
             "계층 트리에 자리를 갖는 component, 그리고 필요할 때 만들어졌다 "
             "사라지는 object 입니다. 이 구분이 UVM 문법 차이의 대부분을 "
             "설명합니다."),

        h2("22.1  두 갈래"),
        art("""
   uvm_void
      |
      +-- uvm_object ------------------+
      |      |                         |
      |   uvm_transaction          uvm_sequence_base
      |      |                         |
      |   uvm_sequence_item        uvm_sequence #(REQ,RSP)
      |
      +-- uvm_report_object
             |
          uvm_component -------------------------+
             |          |         |        |     |
          uvm_driver  uvm_monitor  uvm_agent  uvm_env  uvm_test
"""),
        table(["구분", "uvm_object", "uvm_component"],
              [["수명", "필요할 때 생성/소멸", "시뮬레이션 내내"],
               ["계층 위치", "없음", "트리에 등록 (경로 있음)"],
               ["생성자", "new(name)", "new(name, parent)"],
               ["매크로", "`uvm_object_utils", "`uvm_component_utils"],
               ["phase", "없음", "있음"],
               ["예", "seq_item, sequence, config", "driver, monitor, env"]],
              weights=[0.8, 1.2, 1.3]),
        key("왜 sequence 는 object 인가",
            "sequence 는 '자극 시나리오'라는 데이터입니다. 테스트마다 다른 "
            "것을 골라 쓰고, 다 쓰면 버립니다. 계층에 고정되어야 할 이유가 "
            "없습니다. 반면 driver 는 시뮬레이션 내내 같은 자리에서 "
            "핀을 흔들어야 하므로 component 입니다."),

        h2("22.2  계층 트리"),
        art("""
   uvm_test_top                    (uvm_test)
       |
       +-- env                     (uvm_env)
             |
             +-- agt              (uvm_agent)
             |    |
             |    +-- seqr        (uvm_sequencer)
             |    +-- drv         (uvm_driver)
             |    +-- mon         (uvm_monitor)
             |
             +-- scb              (uvm_scoreboard)
"""),
        p("이 트리는 parent 인자로 만들어집니다. create(\"drv\", this) 의 "
          "this 가 부모를 가리키고, 그것이 계층 경로를 결정합니다."),
        code("hierarchy.sv", """
class reg_agent extends uvm_agent;
    reg_sequencer seqr;
    reg_driver    drv;
    reg_monitor   mon;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = reg_sequencer::type_id::create("seqr", this);
        drv  = reg_driver   ::type_id::create("drv",  this);
        mon  = reg_monitor  ::type_id::create("mon",  this);
        //                                            ^^^^
        //                                      부모 = 이 agent
    endfunction
endclass
"""),
        p("완성된 경로는 uvm_test_top.env.agt.drv 가 됩니다. "
          "이 경로가 config_db 설정과 로그 메시지에 그대로 쓰입니다."),
        code("path_api.sv", """
`uvm_info("DBG", get_name(),      UVM_LOW)  // "drv"
`uvm_info("DBG", get_full_name(), UVM_LOW)  // "uvm_test_top.env.agt.drv"
"""),

        h2("22.3  각 부품의 책임"),
        kv([("sequence", "무엇을 보낼지 결정. 핀은 모름"),
            ("sequencer", "sequence 와 driver 사이 중계. 중재도 담당"),
            ("driver", "아이템을 받아 핀을 흔든다. 유일하게 vif 를 구동"),
            ("monitor", "핀을 관측해 아이템으로 복원. 구동은 절대 안 함"),
            ("agent", "위 셋을 묶는 상자. active/passive 전환"),
            ("scoreboard", "기대값과 실제값 비교. PASS/FAIL 판정"),
            ("env", "agent 와 scoreboard 를 묶고 연결"),
            ("test", "env 를 만들고 어떤 sequence 를 돌릴지 결정")], 76),
        key("책임 분리가 재사용을 만든다",
            "driver 를 바꾸지 않고 sequence 만 바꿔 다른 시나리오를 돌릴 수 "
            "있고, agent 를 passive 로 바꿔 상위 시스템 검증에 그대로 "
            "재사용할 수 있습니다."),

        h2("22.4  active 와 passive agent"),
        code("agent_active.sv", """
class reg_agent extends uvm_agent;
    `uvm_component_utils(reg_agent)

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = reg_monitor::type_id::create("mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            seqr = reg_sequencer::type_id::create("seqr", this);
            drv  = reg_driver   ::type_id::create("drv",  this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
"""),
        table(["모드", "monitor", "driver/sequencer", "쓰는 곳"],
              [["UVM_ACTIVE", "있음", "있음", "블록 단위 검증"],
               ["UVM_PASSIVE", "있음", "없음", "시스템 검증 - 관측만"]],
              weights=[1.0, 0.8, 1.0, 1.2]),

        h2("22.5  실습"),
        lab("과제 22-A",
            "레지스터 DUT 용 agent 를 작성하고 build_phase 에서 "
            "get_full_name() 을 출력해 계층 경로를 확인하세요."),
        quiz("uvm_sequence 가 uvm_component 가 아닌 이유는?",
             ["① 코드가 짧아서",
              "② 계층에 고정될 필요가 없고 테스트마다 교체되므로",
              "③ phase 를 쓰지 않아서",
              "④ 랜덤화가 필요해서"],
             "② — sequence 는 자극 시나리오라는 데이터입니다. "
             "필요할 때 만들고 버리는 것이므로 object 가 맞습니다."),
    ],
}


# ==========================================================================
CH23 = {
    "number": "CHAPTER 23",
    "title": "report 매크로와 verbosity",
    "goals": [
        "네 가지 report 매크로를 구분해 쓴다",
        "verbosity 로 로그 양을 조절한다",
        "매크로가 함수가 아닌 이유를 안다",
        "PASS/FAIL 집계 구조를 이해한다",
    ],
    "body": [
        lead("$display 로도 로그는 찍힙니다. 하지만 회귀 500회를 돌린 뒤 "
             "무엇이 실패했는지 자동으로 판정하려면 집계되는 메시지가 "
             "필요합니다. UVM report 시스템이 그것을 제공합니다."),

        h2("23.1  네 가지 매크로"),
        code("report_macros.sv", """
`uvm_info   (ID, MSG, VERBOSITY)   // 정보 - 인자 3개
`uvm_warning(ID, MSG)              // 경고
`uvm_error  (ID, MSG)              // 에러 - 계속 진행
`uvm_fatal  (ID, MSG)              // 치명 - 즉시 종료
"""),
        table(["매크로", "카운터", "시뮬레이션", "쓰는 곳"],
              [["uvm_info", "INFO", "계속", "진행 상황, 디버그"],
               ["uvm_warning", "WARNING", "계속", "의심스럽지만 치명적 아님"],
               ["uvm_error", "ERROR", "계속", "검증 실패 - 계속 봐야 할 때"],
               ["uvm_fatal", "FATAL", "즉시 종료", "더 진행해도 의미 없을 때"]],
              weights=[1.0, 0.8, 0.8, 1.4]),
        key("info 만 인자가 3개",
            "나머지는 UVM_NONE 이 내부에 박혀 있어 끌 수 없습니다. "
            "에러를 숨길 수 있으면 안 되기 때문입니다."),

        h2("23.2  출력 형식"),
        code("log_format.txt", """
UVM_INFO tb_register.sv(48) @ 25000: uvm_test_top.env.agt.drv [DRV] d=173 en=1
   |           |         |      |              |                |     |
 종류        파일      줄번호  시각          계층 경로            ID   메시지
"""),
        p("앞의 다섯 항목이 자동으로 붙습니다. $display 로는 매번 "
          "손으로 써야 하는 것들이고, 특히 계층 경로는 "
          "$display 로는 얻기 어렵습니다."),

        h2("23.3  매크로 정의를 읽어 보자"),
        code("uvm_macros.svh:104", """
`define uvm_info(ID, MSG, VERBOSITY) \\
   begin \\
     if (uvm_report_enabled(VERBOSITY, UVM_INFO, ID)) \\
       uvm_report_info(ID, MSG, VERBOSITY, \\
                       `uvm_file, `uvm_line, "", 1); \\
   end
"""),
        p("함수가 아니라 매크로인 이유가 이 두 줄에 다 있습니다."),
        ol("`uvm_file, `uvm_line - 파일명과 줄번호는 매크로만 알 수 있다. "
           "함수로 만들면 UVM 내부 파일 이름이 찍힌다",
           "if (uvm_report_enabled(...)) - 출력하지 않을 메시지는 "
           "MSG 를 조립하지도 않고 건너뛴다. 함수라면 인자를 먼저 "
           "평가해야 하므로 불가능하다"),
        tip("성능 차이",
            "UVM_HIGH 로 찍는 디버그 메시지를 $sformatf 로 조립하면 "
            "출력하지 않아도 문자열 조립 비용이 듭니다. "
            "회귀 수천 회에서는 무시할 수 없는 차이가 됩니다."),

        h2("23.4  verbosity"),
        table(["레벨", "값", "기본 출력", "용도"],
              [["UVM_NONE", "0", "예", "반드시 보여야 할 것"],
               ["UVM_LOW", "100", "예", "중요한 진행 상황"],
               ["UVM_MEDIUM", "200", "예 (기본값)", "일반 정보"],
               ["UVM_HIGH", "300", "아니오", "디버그"],
               ["UVM_FULL", "400", "아니오", "상세 디버그"],
               ["UVM_DEBUG", "500", "아니오", "극단적 상세"]],
              weights=[1.0, 0.5, 0.9, 1.1]),
        code("verbosity_control.sh", """
# 실행 시 옵션으로 조절 - 코드 수정 불필요
xsim tb -R +UVM_VERBOSITY=UVM_HIGH

# 특정 컴포넌트만
+uvm_set_verbosity=uvm_test_top.env.agt.drv,_ALL_,UVM_HIGH,time,0
"""),
        code("verbosity_code.sv", """
// 코드에서 조절
function void start_of_simulation_phase(uvm_phase phase);
    env.agt.drv.set_report_verbosity_level(UVM_HIGH);
    // 계층 전체
    env.set_report_verbosity_level_hier(UVM_HIGH);
endfunction
"""),
        key("$display 와의 결정적 차이",
            "$display 는 끄려면 주석 처리해야 하고, 다시 켜려면 "
            "주석을 풀고 재컴파일해야 합니다. uvm_info 는 "
            "실행 옵션 하나로 조절됩니다."),

        h2("23.5  PASS/FAIL 자동 집계"),
        code("report_summary.txt", """
--- UVM Report Summary ---

** Report counts by severity
UVM_INFO    :   142
UVM_WARNING :     3
UVM_ERROR   :     0        <- 0 이면 PASS
UVM_FATAL   :     0

** Report counts by id
[DRV]       :    50
[MON]       :    50
[SCB]       :    42
"""),
        p("이 집계가 있어서 회귀 스크립트가 로그를 grep 하는 것만으로 "
          "합격 여부를 판정할 수 있습니다. $display 로 찍은 '에러!' 는 "
          "여기에 잡히지 않습니다."),
        code("regression_check.sh", """
if grep -q "UVM_ERROR :    0" run.log && \\
   grep -q "UVM_FATAL :    0" run.log; then
    echo PASS
else
    echo FAIL
fi
"""),

        h2("23.6  에러 개수 제한"),
        code("max_quit.sv", """
function void start_of_simulation_phase(uvm_phase phase);
    // 에러 10개가 쌓이면 시뮬레이션 중단
    set_report_max_quit_count(10);
endfunction
"""),
        tip("왜 필요한가",
            "버그 하나가 매 클럭 에러를 내면 로그 파일이 수 GB 가 됩니다. "
            "회귀 서버 디스크가 차고 분석도 불가능합니다. "
            "상한을 두는 것이 실무 표준입니다."),

        h2("23.7  메시지 작성 요령"),
        code("message_style.sv", """
// 나쁜 예
`uvm_info("SEQ", "", UVM_LOW)              // 빈 메시지
`uvm_info("A", "done", UVM_LOW)            // ID 가 의미 없음
`uvm_error("SCB", "mismatch")              // 정보 없음

// 좋은 예
`uvm_info("SEQ", $sformatf("아이템 %0d/%0d 전송 a=%0d b=%0d",
           i+1, total, item.a, item.b), UVM_MEDIUM)
`uvm_error("SCB", $sformatf(
           "[#%0d] 불일치 기대=%0d 실제=%0d 차이=%0d",
           id, exp, act, act - exp))
"""),
        ul("ID 는 컴포넌트나 검사 종류를 나타내는 짧은 대문자 (DRV, SCB, REG)",
           "메시지에는 재현에 필요한 값을 모두 넣는다",
           "$sformatf 로 조립한다 - uvm_info 는 문자열 하나만 받는다",
           "회귀에서 grep 할 것을 염두에 두고 형식을 일정하게 유지한다"),

        h2("23.8  실습"),
        lab("과제 23-A",
            "드라이버에 UVM_LOW, UVM_HIGH 메시지를 각각 넣고 "
            "+UVM_VERBOSITY 옵션으로 출력이 달라지는지 확인하세요."),
        lab("과제 23-B",
            "일부러 스코어보드 비교를 틀리게 만들어 Report Summary 의 "
            "UVM_ERROR 카운트가 올라가는지 확인하세요."),
        quiz("`uvm_info(\"SEQ\", \"\", UVM_LOW) 의 문제는?",
             ["① 문법 에러",
              "② 메시지가 비어 로그에 태그만 찍힌다",
              "③ verbosity 인자가 잘못됐다",
              "④ ID 가 3글자여야 한다"],
             "② — 문법은 맞지만 정보가 없습니다. "
             "$sformatf 로 실제 값을 넣어야 로그가 쓸모 있어집니다."),
    ],
}


# ==========================================================================
CH24 = {
    "number": "CHAPTER 24",
    "title": "factory (1) - registry 와 type_id",
    "goals": [
        "type_id 의 정체를 설명한다",
        "매크로가 무엇을 심어주는지 안다",
        "registry 가 왜 필요한지 이해한다",
        "등록이 언제 일어나는지 안다",
    ],
    "body": [
        lead("seq_item::type_id::create(\"SEQ_ITEM\") 이 한 줄을 완전히 "
             "이해하는 것이 이 장과 다음 장의 목표입니다. UVM 에서 가장 "
             "많이 쓰면서 가장 이해가 얕은 문법입니다."),

        h2("24.1  결론부터"),
        code("create_line.sv", """
reg_seq_item = seq_item::type_id::create("SEQ_ITEM");
"""),
        p("이 줄이 하는 일은 하나입니다 - seq_item 객체를 하나 만든다. "
          "아래 두 줄의 결과는 같습니다."),
        code("new_vs_create.sv", """
reg_seq_item = new("SEQ_ITEM");                        // 방법 A
reg_seq_item = seq_item::type_id::create("SEQ_ITEM");  // 방법 B
"""),
        p("그런데도 UVM 이 B 를 쓰는 이유는, B 만이 "
          "'나중에 다른 타입으로 바꿔치기'를 허용하기 때문입니다. "
          "그 구조를 이 장에서 봅니다."),

        h2("24.2  type_id 는 그냥 typedef 다"),
        code("type_id_typedef.sv", """
typedef uvm_object_registry #(seq_item, "seq_item") type_id;
//      +------------ 진짜 이름 ------------+       +별명+
"""),
        p("여러분이 평소 쓰는 typedef 와 문법이 같습니다."),
        code("typedef_compare.sv", """
typedef logic [7:0]                                byte_t;   // byte_t 라는 타입
typedef uvm_object_registry #(seq_item,"seq_item") type_id;  // type_id 라는 타입
"""),
        p("즉 type_id 라고 쓴 것은 사실 아래를 쓴 것입니다."),
        code("without_alias.sv", """
// 여러분이 쓰는 것
seq_item::type_id::create("SEQ_ITEM");

// 별명이 없다면
uvm_object_registry#(seq_item,"seq_item")::create("SEQ_ITEM");
"""),
        key("type_id 는 seq_item 의 별명이 아니다",
            "seq_item 은 트랜잭션 자체의 타입이고, "
            "seq_item::type_id 는 그 트랜잭션을 '만들어주는 등록소'의 "
            "타입입니다. 서로 다른 타입입니다."),
        art("""
   seq_item :: type_id :: create("SEQ_ITEM")
   +-클래스-+  +-등록소-+  +--만들어줘--+

   "seq_item 클래스 안에 있는 type_id 라는 등록소야, 하나 만들어줘"
"""),
        note("왜 . 이 아니라 :: 인가",
             "type_id 는 타입이지 객체가 아닙니다. 타입은 객체가 없어도 "
             "존재하므로 scope resolution 연산자 :: 로 접근합니다. "
             "12장의 static 멤버와 같은 이유입니다.",
             "info"),

        h2("24.3  매크로가 심어주는 것"),
        p("type_id 를 직접 선언한 적이 없죠. 매크로가 넣어준 것입니다."),
        code("uvm_macros.svh:484", """
`define uvm_object_utils_begin(T) \\
   `m_uvm_object_registry_internal(T,T)  \\   // (1) Value - 등록소
   `m_uvm_object_create_func(T) \\
   `m_uvm_get_type_name_func(T) \\           // (2) Key - 문자열
   `uvm_field_utils_begin(T)
"""),
        h3("(1) 등록소 만들기 - 576줄"),
        code("uvm_macros.svh:576", """
`define m_uvm_object_registry_internal(T,S) \\
   typedef uvm_object_registry#(T,`"S`") type_id; \\
   static function type_id get_type(); \\
     return type_id::get(); \\
   endfunction \\
   virtual function uvm_object_wrapper get_object_type(); \\
     return type_id::get(); \\
   endfunction
"""),
        h3("(2) 이름 문자열 만들기 - 568줄"),
        code("uvm_macros.svh:568", """
`define m_uvm_get_type_name_func(T) \\
   const static string type_name = `"T`"; \\
   virtual function string get_type_name (); \\
     return type_name; \\
   endfunction
"""),
        p("`\"T`\" 는 전처리기의 문자열화 연산입니다. T 자리에 seq_item 이 "
          "들어가면 \"seq_item\" 이라는 문자열이 됩니다."),
        code("expanded.sv", """
// `uvm_object_utils_begin(seq_item) 가 펼쳐진 결과 (요약)
class seq_item extends uvm_sequence_item;
    typedef uvm_object_registry#(seq_item,"seq_item") type_id;
    const static string type_name = "seq_item";
    static function type_id get_type();
        return type_id::get();
    endfunction
    ...
endclass
"""),
        trap("매크로를 빼먹으면",
             "'type_id is not declared under prefix seq_item' 또는 "
             "'Cannot instantiate abstract class' 에러가 납니다. "
             "UVM 입문자가 가장 자주 만나는 에러이고, 원인은 거의 항상 "
             "uvm_object_utils 누락입니다."),

        h2("24.4  registry - 장부"),
        p("registry 는 명부입니다. 실제로 연관배열입니다."),
        code("uvm_factory_table.sv", """
// uvm_default_factory 내부
protected bit                m_types[uvm_object_wrapper];
protected uvm_object_wrapper m_type_names[string];
"""),
        art("""
   m_type_names 장부

   +------------------+--------------------------+
   |  "seq_item"      |  [seq_item 대리인 객체]   |
   |  "reg_sequence"  |  [reg_sequence 대리인]    |
   |  "reg_driver"    |  [reg_driver 대리인]      |
   +------------------+--------------------------+
        Key                     Value
    (타입 이름)              (등록소 싱글톤)
"""),
        key("매크로 한 번 = 장부 한 줄",
            "`uvm_object_utils_begin(seq_item) 을 쓰면 "
            "\"seq_item\" -> 대리인 한 줄이 추가됩니다. "
            "매크로를 안 쓴 클래스는 장부에 없어서 factory 가 "
            "존재 자체를 모릅니다."),

        h2("24.5  왜 대리인이 필요한가"),
        p("SystemVerilog 는 타입을 변수에 담을 수 없습니다."),
        code("cannot_store_type.sv", """
m_type_names["seq_item"] = seq_item;   // 불가능! 타입은 값이 아님
"""),
        p("그래서 타입을 대신할 '객체'를 하나 만듭니다. "
          "사람은 못 옮기지만 신분증은 주고받을 수 있는 것과 같습니다."),
        table(["현실", "UVM"],
              [["사람 (직접 못 넘김)", "seq_item 클래스 타입"],
               ["신분증 (주고받기 가능)", "type_id 대리인 객체"],
               ["신분증으로 처리하는 관공서", "uvm_factory"]],
              weights=[1.1, 1.1]),

        h2("24.6  registry 본체"),
        code("uvm_object_registry", """
class uvm_object_registry #(type T=uvm_object, string Tname="<unknown>")
                                       extends uvm_object_wrapper;

  local static this_type me = get();      // (A) 자동 등록의 방아쇠

  static function this_type get();
    if (me == null) begin
      me = new;
      factory.register(me);               // (B) 장부에 등록
    end
    return me;
  endfunction

  virtual function uvm_object create_object(string name="");
    T obj;
    obj = new(name);                      // (C) 진짜 new() 는 여기 하나뿐
    return obj;
  endfunction
endclass
"""),
        kv([("(A)", "static 변수 초기화라 시뮬레이션 시작 시 자동 실행"),
            ("(B)", "여기서 장부에 한 줄이 추가됨"),
            ("(C)", "UVM 전체에서 트랜잭션 new() 가 불리는 유일한 자리")], 46),
        key("자동 등록의 원리",
            "local static this_type me = get(); 이 한 줄 때문에 "
            "사용자가 아무 코드도 쓰지 않아도 모든 타입이 "
            "시뮬레이션 시작 시 factory 에 등록됩니다."),

        h2("24.7  등록 시점 정리"),
        art("""
   [1] 컴파일 시점
       `uvm_object_utils_begin(seq_item)
              |
              v  매크로가 클래스 안에 코드를 삽입
       typedef ... type_id;      const static string type_name;
       (아직 객체는 없음 - 설계도만 완성)

   [2] 시뮬레이션 시작 (0ns 이전)
       local static me = get();  <- 자동 실행
              |
              +-- me = new              대리인 1개 생성
              +-- factory.register(me)  장부에 등록
              |
              v
       m_type_names["seq_item"] = [대리인]

   [3] 런타임 - 다음 장에서
       seq_item::type_id::create("SEQ_ITEM")
"""),

        h2("24.8  확인해 보기"),
        code("verify_registry.sv", """
// 장부 전체 출력 - override 디버깅의 첫 단계
uvm_factory::get().print();

// 개별 확인
$display("%s", seq_item::type_name);     // "seq_item"  <- Key
$display("%p", seq_item::get_type());    // 대리인       <- Value
"""),
        lab("과제 24-A",
            "seq_item 에서 uvm_object_utils 매크로를 주석 처리하고 "
            "컴파일해 어떤 에러가 나는지 확인하세요."),
        lab("과제 24-B",
            "build_phase 에서 uvm_factory::get().print() 를 호출해 "
            "등록된 타입 목록을 확인하세요."),
        quiz("type_id 는 무엇인가?",
             ["① seq_item 의 다른 이름",
              "② uvm_object_registry#(seq_item,\"seq_item\") 의 typedef 별명",
              "③ 객체의 고유 번호",
              "④ UVM 이 부여하는 정수 ID"],
             "② — 매크로가 클래스 안에 심어준 typedef 입니다. "
             "가리키는 것은 seq_item 이 아니라 seq_item 을 만들어주는 "
             "등록소입니다."),
    ],
}


# ==========================================================================
CH25 = {
    "number": "CHAPTER 25",
    "title": "factory (2) - create 흐름과 override",
    "goals": [
        "create 호출의 내부 흐름을 추적한다",
        "타입 이름과 인스턴스 이름을 구분한다",
        "type override 와 instance override 를 쓴다",
        "override 실패를 진단한다",
    ],
    "body": [
        lead("앞 장에서 장부가 만들어졌습니다. 이 장에서는 그 장부가 "
             "실제로 일하는 순간, 즉 create 가 불리는 순간을 봅니다."),

        h2("25.1  이름이 두 개다"),
        code("two_names.sv", """
reg_seq_item = seq_item::type_id::create("SEQ_ITEM");
//             +--+---+            +----+---+
//             타입 이름            인스턴스 이름
//             장부의 Key           장부와 무관
"""),
        table(["구분", "값", "사는 곳", "개수"],
              [["타입 이름", "\"seq_item\"", "장부의 Key", "클래스당 1개"],
               ["인스턴스 이름", "\"SEQ_ITEM\"", "객체의 m_name 필드", "만들 때마다"]],
              weights=[1.0, 1.0, 1.2, 1.0]),
        trap("여기서 가장 많이 헷갈린다",
             "repeat(5) 로 5개를 만들면 객체 5개 모두 이름표가 "
             "\"SEQ_ITEM\" 이 되지만, 장부에는 여전히 \"seq_item\" 행 "
             "하나뿐입니다. 장부는 '어떤 타입이 존재하는가'만 기록하지 "
             "만들어진 객체를 추적하지 않습니다."),

        h2("25.2  실행 흐름 추적"),
        h3("① 컴파일 시점 - type_id 치환"),
        code("step1.sv", """
seq_item::type_id::create("SEQ_ITEM")
        |  typedef 펼쳐짐
        v
uvm_object_registry#(seq_item,"seq_item")::create("SEQ_ITEM")
"""),
        p("여기서 이미 어느 대리인인지 결정됩니다. 런타임 조회가 아닙니다."),
        h3("② create() 진입"),
        code("step2.sv", """
static function T create (string name="", uvm_component parent=null, ...);
    factory = cs.get_factory();
    obj = factory.create_object_by_type(get(), contxt, name);
    //                                  +-+-+        +-+-+
    //                            내 대리인 넘김   "SEQ_ITEM" 넘김
"""),
        h3("③ factory 안에서 override 조회"),
        code("step3.sv", """
function uvm_object create_object_by_type(uvm_object_wrapper requested_type,
                                          string parent_inst_path="",
                                          string name="");
    requested_type = find_override_by_type(requested_type, full_inst_path);
    return requested_type.create_object(name);
endfunction
"""),
        key("factory 의 전부가 이 두 줄이다",
            "첫 줄 - 이 대리인 대신 쓸 놈이 있는지 조회. "
            "둘째 줄 - 최종 확정된 대리인에게 제작 지시. "
            "장부가 실제로 일하는 것은 첫 줄 한 순간뿐입니다."),
        h3("④ 실제 생성"),
        code("step4.sv", """
virtual function uvm_object create_object(string name="");
    T obj;
    obj = new(name);     // "SEQ_ITEM" 이 여기서 처음 쓰인다
    return obj;
endfunction
"""),
        h3("⑤ 타입 검증"),
        code("step5.sv", """
if (!$cast(create, obj)) begin
    msg = {"Factory did not return an object of type '", type_name, "'..."};
    uvm_report_fatal("FCTTYP", msg, UVM_NONE);
end
"""),
        art("""
   seq_item::type_id::create("SEQ_ITEM")
        |                      |
        | (컴파일 시 확정)      | (그냥 들고만 다님)
        v                      |
   [seq_item 대리인] ----------+--> factory
        |                      |
        v find_override_by_type|      <- 장부를 쓰는 유일한 단계
   [최종 대리인]                |
        |                      |
        v create_object() <----+
     new("SEQ_ITEM")            <- 이름표가 여기서 붙음
        |
        v $cast 검증
   reg_seq_item <-- 핸들 반환
"""),

        h2("25.3  type override"),
        code("type_override.sv", """
class err_item extends seq_item;          // 반드시 자식이어야 함
    `uvm_object_utils(err_item)
    constraint c_bad { a > 250; b > 250; }   // 캐리를 강제 발생
endclass

class error_test extends base_test;
    virtual function void build_phase(uvm_phase phase);
        // env 를 만들기 전에 override 를 걸어야 한다
        set_type_override_by_type(seq_item::get_type(),
                                  err_item::get_type());
        super.build_phase(phase);
    endfunction
endclass
"""),
        p("이 한 줄 이후로 sequence 안의 seq_item::type_id::create(...) 가 "
          "err_item 을 반환합니다. sequence 코드는 한 글자도 안 바뀝니다."),
        code("override_apis.sv", """
// 타입 기반 (권장)
set_type_override_by_type(seq_item::get_type(), err_item::get_type());

// 문자열 기반
set_type_override_by_name("seq_item", "err_item");

// 특정 인스턴스만 교체
set_inst_override_by_type("env.agt.*", seq_item::get_type(),
                                       err_item::get_type());
"""),
        table(["방식", "적용 범위", "권장"],
              [["type override", "그 타입 전부", "일반적인 경우"],
               ["instance override", "경로에 맞는 것만", "에이전트별로 다르게"],
               ["by_name", "문자열로 지정", "파라미터화 클래스에는 불가"]],
              weights=[1.0, 1.1, 1.2]),

        h2("25.4  override 는 상속 관계 안에서만"),
        trap("FCTTYP 에러",
             "override 대상이 원래 타입의 자식이 아니면 "
             "생성은 되지만 마지막 $cast 에서 걸려 시뮬레이션이 죽습니다. "
             "err_item 은 반드시 seq_item 을 extends 해야 합니다."),
        code("wrong_override.sv", """
class cmd_item extends uvm_sequence_item;   // seq_item 의 자식이 아님!
    ...
endclass

set_type_override_by_type(seq_item::get_type(), cmd_item::get_type());
// -> 런타임에 FCTTYP fatal
"""),

        h2("25.5  타이밍 - 언제 override 를 걸어야 하나"),
        warn("build_phase 시작 전에 걸어라",
             "컴포넌트는 build_phase 에서 create 됩니다. "
             "이미 만들어진 뒤에 override 를 걸면 효과가 없습니다. "
             "test 의 build_phase 맨 앞, super.build_phase() 를 "
             "부르기 전에 거는 것이 안전합니다."),
        code("override_timing.sv", """
virtual function void build_phase(uvm_phase phase);
    set_type_override_by_type(reg_driver::get_type(),
                              err_driver::get_type());   // 먼저
    super.build_phase(phase);                            // 그 다음
endfunction
"""),
        note("sequence_item 은 예외",
             "seq_item 은 run_phase 에서 create 되므로 "
             "build_phase 중 아무 때나 override 를 걸어도 됩니다. "
             "컴포넌트만 순서에 민감합니다.",
             "info"),

        h2("25.6  디버깅"),
        code("factory_debug.sv", """
// 등록된 타입과 override 규칙 전부 출력
function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory::get().print();
endfunction
"""),
        code("factory_print_out.txt", """
#### Factory Configuration (*)

  Type Overrides:
    Requested Type   Override Type
    --------------   -------------
    seq_item         err_item

  All Types:
    Type Name
    ---------
    err_item
    reg_driver
    seq_item
"""),
        ol("override 가 목록에 있는가 - 없으면 set 호출이 안 된 것",
           "override 대상이 All Types 에 있는가 - 없으면 매크로 누락",
           "타이밍이 맞는가 - 컴포넌트는 build 전에 걸어야 함",
           "상속 관계인가 - 아니면 FCTTYP"),

        h2("25.7  전체 흐름 정리"),
        table(["단계", "언제", "결과물"],
              [["매크로", "컴파일 때 한 번", "type_id, type_name 코드 생성"],
               ["등록", "시뮬레이션당 한 번", "장부 한 줄, 대리인 1개"],
               ["create", "호출할 때마다", "트랜잭션 객체 1개씩"]],
              weights=[0.8, 1.1, 1.4]),
        key("이 고생을 하는 이유 한 문장",
            "create 흐름 ③단계의 override 조회를 끼워넣기 위해서입니다. "
            "new() 를 직접 부르면 이 단계가 통째로 사라집니다."),

        h2("25.8  실습"),
        lab("과제 25-A",
            "seq_item 을 상속한 err_item 을 만들고 type override 로 "
            "sequence 코드 수정 없이 다른 자극이 생성되는지 확인하세요."),
        lab("과제 25-B",
            "override 를 super.build_phase() 뒤에 걸어 보고 "
            "컴포넌트 override 가 왜 안 먹는지 확인하세요."),
        quiz("create(\"SEQ_ITEM\") 의 \"SEQ_ITEM\" 은 어디에 쓰이는가?",
             ["① 장부에서 타입을 찾는 Key",
              "② 만들어진 객체의 이름표. 로그 출력에 쓰임",
              "③ override 규칙의 대상 지정",
              "④ 아무 데도 안 쓰인다"],
             "② — 장부의 Key 는 \"seq_item\"(타입 이름)이고, "
             "\"SEQ_ITEM\" 은 new(name) 으로 전달되어 객체의 이름표가 "
             "됩니다. 둘은 만나지 않습니다."),
    ],
}


# ==========================================================================
CH26 = {
    "number": "CHAPTER 26",
    "title": "phase 메커니즘",
    "goals": [
        "phase 순서와 각 phase 의 역할을 안다",
        "build 가 top-down, connect 가 bottom-up 인 이유를 안다",
        "objection 으로 시뮬레이션 종료를 제어한다",
        "phase 관련 흔한 실수를 피한다",
    ],
    "body": [
        lead("모든 컴포넌트가 각자 build 하고 각자 run 하면 순서가 엉킵니다. "
             "phase 는 '모두가 build 를 끝낸 뒤에 connect 를 시작한다'는 "
             "동기화 지점을 만듭니다."),

        h2("26.1  phase 목록"),
        table(["phase", "종류", "방향", "하는 일"],
              [["build_phase", "function", "top-down", "자식 컴포넌트 생성"],
               ["connect_phase", "function", "bottom-up", "포트 연결"],
               ["end_of_elaboration", "function", "bottom-up", "계층 확정 후 점검"],
               ["start_of_simulation", "function", "bottom-up", "초기 배너, 설정 출력"],
               ["run_phase", "task", "병렬", "실제 시뮬레이션"],
               ["extract_phase", "function", "bottom-up", "데이터 수집"],
               ["check_phase", "function", "bottom-up", "미처리 항목 검사"],
               ["report_phase", "function", "bottom-up", "결과 출력"],
               ["final_phase", "function", "top-down", "정리"]],
              weights=[1.2, 0.7, 0.8, 1.4]),
        key("run_phase 만 task 다",
            "나머지는 전부 function 이라 시간을 소비할 수 없습니다. "
            "'이 단계에서는 시뮬레이션 시간을 쓰지 말라'는 강제입니다."),

        h2("26.2  build 는 top-down, connect 는 bottom-up"),
        art("""
   build_phase (위에서 아래로)

   test      1  test 가 env 를 만든다
     |          |
   env       2  env 가 agent 를 만든다
     |          |
   agent     3  agent 가 driver, monitor 를 만든다
     |          |
   driver    4  (자식이 없으므로 끝)

   connect_phase (아래에서 위로)

   driver    1  자식부터 연결
     |
   agent     2  driver.port <-> sequencer.export
     |
   env       3  agent.ap <-> scoreboard.imp
     |
   test      4
"""),
        p("build 가 top-down 인 이유는 부모가 자식을 만들기 때문입니다. "
          "connect 가 bottom-up 인 이유는 연결하려면 양쪽이 이미 "
          "존재해야 하기 때문입니다."),
        code("build_connect.sv", """
class reg_env extends uvm_env;
    reg_agent      agt;
    reg_scoreboard scb;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = reg_agent     ::type_id::create("agt", this);
        scb = reg_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.item_export);   // 둘 다 존재하는 시점
    endfunction
endclass
"""),
        trap("build_phase 에서 연결하려 하면",
             "자식이 아직 안 만들어졌을 수 있어 null 참조 에러가 납니다. "
             "생성은 build, 연결은 connect - 예외 없습니다."),

        h2("26.3  super 호출"),
        warn("super.build_phase(phase) 를 빼먹으면",
             "uvm_field 매크로가 만드는 자동 설정 기능이 동작하지 않습니다. "
             "config_db 에서 값을 못 받아오는 원인이 대부분 이것입니다. "
             "모든 phase 메서드의 첫 줄에 super 호출을 넣으세요."),

        h2("26.4  run_phase 와 objection"),
        p("run_phase 는 모든 컴포넌트에서 동시에 시작됩니다. "
          "언제 끝낼지는 objection 이 결정합니다."),
        code("objection.sv", """
class random_test extends base_test;
    virtual task run_phase(uvm_phase phase);
        reg_sequence seq;
        seq = reg_sequence::type_id::create("seq");

        phase.raise_objection(this, "시퀀스 시작");
        seq.start(env.agt.seqr);
        phase.drop_objection(this, "시퀀스 완료");
    endtask
endclass
"""),
        art("""
   objection 카운터

   시작           raise            drop           종료
     |              |                |              |
     0 ---------->  1 ------------->  0 ---------> run_phase 끝
                    ^                 ^
              여기서 올리고      여기서 내리면
              시뮬레이션 유지    아무도 안 들고 있으면 종료
"""),
        trap("objection 을 안 올리면",
             "run_phase 가 시작하자마자 끝납니다. 시뮬레이션이 0ns 에 "
             "종료되고 아무 자극도 안 나갑니다. "
             "UVM 입문자가 두 번째로 많이 겪는 문제입니다."),
        trap("objection 을 안 내리면",
             "시뮬레이션이 영원히 끝나지 않습니다. "
             "타임아웃으로 강제 종료되거나 무한히 돕니다."),
        code("objection_timeout.sv", """
// 전역 타임아웃 설정 - 안전장치
function void start_of_simulation_phase(uvm_phase phase);
    uvm_top.set_timeout(1ms, 1);
endfunction
"""),
        tip("objection 은 test 에서만",
            "드라이버나 모니터의 forever 루프에서 objection 을 올리면 "
            "절대 안 끝납니다. 시뮬레이션 길이를 결정하는 것은 "
            "test 의 책임입니다."),

        h2("26.5  run_phase 안의 forever"),
        code("forever_run.sv", """
class reg_driver extends uvm_driver #(seq_item);
    virtual task run_phase(uvm_phase phase);
        forever begin                    // objection 없이 무한 루프
            seq_item_port.get_next_item(req);
            drive(req);
            seq_item_port.item_done();
        end
    endtask
endclass
"""),
        p("드라이버는 objection 을 올리지 않습니다. test 가 objection 을 "
          "내리면 UVM 이 run_phase 를 강제로 종료시키고, "
          "이 forever 루프도 함께 정리됩니다."),

        h2("26.6  extract / check / report"),
        code("post_run_phases.sv", """
virtual function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);
    total = match_cnt + mismatch_cnt;    // 데이터 정리
endfunction

virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expect_q.size() != 0)            // 미처리 항목 검사
        `uvm_error("SCB", $sformatf("%0d개 남음", expect_q.size()))
endfunction

virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf("총 %0d건, 불일치 %0d건",
               total, mismatch_cnt), UVM_NONE)
endfunction
"""),

        h2("26.7  세부 run-time phase"),
        p("run_phase 하나로 부족한 경우가 있습니다. 리셋이 끝난 뒤에 "
          "설정을 하고, 그 다음 본 트래픽을 흘리고, 마지막에 정리하는 "
          "순서를 강제하고 싶을 때입니다. UVM 은 run_phase 와 병렬로 "
          "도는 12개의 세부 phase 를 제공합니다."),
        art("""
   run_phase          (전체 구간에 걸쳐 하나로 실행)
   +---------------------------------------------------------+

   세부 phase (순서대로 실행, 각각 objection 을 따로 관리)

   pre_reset -> reset -> post_reset ->
   pre_configure -> configure -> post_configure ->
   pre_main -> main -> post_main ->
   pre_shutdown -> shutdown -> post_shutdown

   두 계열은 동시에 돈다. 섞어 쓰면 순서를 예측하기 어려우므로
   프로젝트마다 하나를 골라 쓰는 것이 원칙이다.
"""),
        code("sub_phases.sv", """
class reg_driver extends uvm_driver #(seq_item);
    virtual task reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        vif.cb.en <= 1'b0;
        vif.cb.d  <= 32'h0;
        @(posedge vif.resetn);          // 리셋 해제 대기
        phase.drop_objection(this);
    endtask

    virtual task main_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask
endclass
"""),
        table(["phase 그룹", "의도"],
              [["reset 계열", "리셋 인가와 해제, 신호 초기화"],
               ["configure 계열", "레지스터 설정, 모드 지정"],
               ["main 계열", "본 트래픽. 대부분의 시나리오가 여기"],
               ["shutdown 계열", "잔여 트랜잭션 배출, 정리"]],
              weights=[1.1, 1.7]),
        warn("run_phase 와 섞지 마라",
             "run_phase 와 main_phase 는 동시에 돕니다. "
             "둘 다 자극을 인가하면 순서가 뒤엉킵니다. "
             "프로젝트 전체에서 한 계열만 쓰기로 정하세요. "
             "학습 단계에서는 run_phase 하나로 충분합니다."),

        h2("26.8  phase domain"),
        p("여러 클럭 도메인이 있을 때, 각 도메인이 독립적으로 "
          "리셋되고 설정되어야 하는 경우가 있습니다. domain 이 "
          "그 독립성을 제공합니다."),
        code("phase_domain.sv", """
// 두 도메인을 분리
uvm_domain dom_a = new("domain_a");
uvm_domain dom_b = new("domain_b");

agent_a.set_domain(dom_a);
agent_b.set_domain(dom_b);

// 이제 agent_a 의 reset_phase 와 agent_b 의 reset_phase 가
// 서로를 기다리지 않고 각자 진행한다
"""),
        note("대부분은 필요 없다",
             "단일 클럭 도메인이면 기본 domain 하나로 충분합니다. "
             "멀티 클럭 SoC 검증에서 만나게 되는 주제입니다.",
             "info"),

        h2("26.9  자주 하는 실수 정리"),
        table(["증상", "원인"],
              [["0ns 에 시뮬레이션 종료", "objection 을 안 올림"],
               ["시뮬레이션이 안 끝남", "objection 을 안 내림"],
               ["null 참조 에러", "build 에서 연결 시도"],
               ["config 값을 못 받음", "super.build_phase 누락"],
               ["내 run_phase 가 안 불림", "virtual 누락 또는 시그니처 불일치"],
               ["자식이 null", "create 를 안 했거나 이름 오타"]],
              weights=[1.1, 1.3]),

        h2("26.10  실습"),
        lab("과제 26-A",
            "각 phase 에 uvm_info 를 하나씩 넣고 실행 순서를 로그로 "
            "확인하세요. build 와 connect 의 방향 차이가 보여야 합니다."),
        lab("과제 26-B",
            "objection 을 주석 처리하고 시뮬레이션이 어떻게 끝나는지 "
            "확인하세요."),
        quiz("connect_phase 가 bottom-up 인 이유는?",
             ["① 성능이 좋아서",
              "② 연결하려면 양쪽 컴포넌트가 이미 존재해야 해서",
              "③ UVM 이 그렇게 정해서",
              "④ build 가 top-down 이라 반대로 한 것"],
             "② — 자식이 먼저 완성되어야 부모가 자식들끼리 연결할 수 "
             "있습니다. 순서가 반대면 null 포트를 연결하게 됩니다."),
    ],
}


# ==========================================================================
CH27 = {
    "number": "CHAPTER 27",
    "title": "config_db",
    "goals": [
        "config_db 로 계층을 넘어 설정을 전달한다",
        "경로 와일드카드를 정확히 쓴다",
        "virtual interface 를 전달한다",
        "설정 전달 실패를 진단한다",
    ],
    "body": [
        lead("테스트가 드라이버의 동작을 바꾸려면 어떻게 해야 할까요. "
             "계층을 타고 내려가며 인자를 넘기는 것은 결합도가 너무 높습니다. "
             "config_db 는 '경로로 지정해 값을 꽂아 넣는' 방식으로 "
             "이 문제를 풉니다."),

        h2("27.1  기본 사용"),
        code("config_db_basic.sv", """
// 넣기 (set)
uvm_config_db #(int)::set(this, "env.agt.drv", "delay", 5);
//              +타입+       +--+  +---경로---+  +키+   +값+
//                          컨텍스트

// 꺼내기 (get)
int delay;
if (!uvm_config_db #(int)::get(this, "", "delay", delay))
    `uvm_fatal("CFG", "delay 설정을 찾을 수 없습니다")
"""),
        kv([("타입 파라미터", "set 과 get 의 타입이 정확히 같아야 함"),
            ("컨텍스트", "경로의 기준점. 보통 this 또는 null"),
            ("경로", "컨텍스트 기준 상대 경로. 와일드카드 가능"),
            ("키", "설정 이름 문자열. set 과 get 이 같아야 함"),
            ("값", "전달할 값")], 84),

        h2("27.2  경로 규칙"),
        art("""
   uvm_test_top.env.agt.drv 에 값을 넣는 방법들

   test 안에서 (this = uvm_test_top)
     set(this, "env.agt.drv", "delay", 5)      상대 경로

   어디서든
     set(null, "uvm_test_top.env.agt.drv", "delay", 5)   절대 경로

   와일드카드
     set(this, "env.agt.*",   "delay", 5)      agt 아래 전부
     set(this, "*",           "delay", 5)      전부
     set(null, "*",           "vif",   intf)   가장 흔한 형태
"""),
        code("get_context.sv", """
// 컴포넌트 자신이 받을 때는 경로를 비운다
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(int)::get(this, "", "delay", delay))
        delay = 1;      // 기본값
endfunction
"""),
        trap("get 의 두 번째 인자",
             "자기 자신이 받을 때는 반드시 빈 문자열입니다. "
             "여기에 경로를 넣으면 '내 아래의 그 경로'를 찾게 되어 "
             "값을 못 받습니다."),

        h2("27.3  virtual interface 전달"),
        p("config_db 의 가장 중요한 용도입니다. 정적 계층(module)의 "
          "interface 를 동적 계층(class)으로 넘기는 유일한 표준 방법입니다."),
        code("vif_pass.sv", """
// top 모듈에서 넣는다
module tb_register;
    reg_interface intf();
    uvm_register dut (.clk(intf.clk), ...);

    initial begin
        uvm_config_db #(virtual reg_interface)::set(
            null, "*", "vif", intf);
        run_test("random_test");
    end
endmodule
"""),
        code("vif_get.sv", """
// 드라이버에서 꺼낸다
class reg_driver extends uvm_driver #(seq_item);
    virtual reg_interface vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual reg_interface)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 를 찾을 수 없습니다: ",
                                  get_full_name()})
    endfunction
endclass
"""),
        key("run_test 앞에서 set 하라",
            "run_test 가 불리면 곧바로 build_phase 가 시작됩니다. "
            "그 전에 vif 를 넣어두지 않으면 드라이버가 못 받습니다."),

        h2("27.4  설정 객체 전달"),
        p("설정 항목이 여러 개면 개별 전달보다 객체 하나로 묶는 편이 낫습니다."),
        code("config_object.sv", """
class reg_config extends uvm_object;
    `uvm_object_utils(reg_config)

    virtual reg_interface vif;
    int  delay      = 1;
    bit  check_en   = 1;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "reg_config");
        super.new(name);
    endfunction
endclass
"""),
        code("config_object_use.sv", """
// test 에서
virtual function void build_phase(uvm_phase phase);
    reg_config cfg = reg_config::type_id::create("cfg");
    cfg.delay = 3;
    if (!uvm_config_db #(virtual reg_interface)::get(
            this, "", "vif", cfg.vif))
        `uvm_fatal("CFG", "vif 없음")

    uvm_config_db #(reg_config)::set(this, "env.agt*", "cfg", cfg);
    super.build_phase(phase);
endfunction

// agent 에서
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(reg_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "cfg 없음")
    // 자식에게 그대로 전달
    uvm_config_db #(reg_config)::set(this, "*", "cfg", cfg);
endfunction
"""),
        tip("설정 객체 패턴의 이점",
            "항목이 늘어나도 set/get 코드는 그대로입니다. "
            "그리고 config 객체 하나만 보면 이 에이전트가 "
            "무엇을 설정할 수 있는지 한눈에 알 수 있습니다."),

        h2("27.5  우선순위"),
        p("같은 키에 여러 set 이 있으면 규칙에 따라 하나가 이깁니다."),
        ol("계층이 더 위(상위 컴포넌트)에서 한 set 이 이긴다",
           "같은 계층이면 나중에 한 set 이 이긴다",
           "구체적인 경로가 와일드카드보다 우선하지는 않는다"),
        code("priority.sv", """
// test(위) 에서
uvm_config_db #(int)::set(this, "env.agt.drv", "delay", 10);

// env(아래) 에서
uvm_config_db #(int)::set(this, "agt.drv", "delay", 5);

// 결과: 10  <- 상위에서 한 set 이 이긴다
"""),
        key("왜 상위 우선인가",
            "테스트가 환경의 기본 설정을 덮어쓸 수 있어야 하기 때문입니다. "
            "'테스트가 최종 결정권을 갖는다'는 원칙입니다."),

        h2("27.6  디버깅"),
        code("config_debug.sv", """
// 이 컴포넌트에 적용된 설정 전부 출력
function void end_of_elaboration_phase(uvm_phase phase);
    print_config(1);       // 1 = 재귀적으로 자식까지
endfunction
"""),
        code("config_debug_opt.sh", """
# 명령행 옵션
+UVM_CONFIG_DB_TRACE      # set/get 을 전부 추적
"""),
        table(["증상", "확인할 것"],
              [["get 이 항상 실패", "타입 파라미터가 set 과 같은가"],
               ["", "키 문자열 철자가 같은가"],
               ["", "경로가 실제 계층과 맞는가"],
               ["", "set 이 get 보다 먼저 실행되는가"],
               ["일부만 받음", "와일드카드 범위 확인"],
               ["값이 예상과 다름", "다른 곳의 set 이 이기고 있는가"]],
              weights=[1.0, 1.6]),

        h2("27.7  실습"),
        lab("과제 27-A",
            "config_db 로 드라이버에 delay 값을 전달하고, "
            "test 마다 다른 값을 넣어 동작이 달라지는지 확인하세요."),
        lab("과제 27-B",
            "reg_config 객체를 만들어 vif 와 delay 를 한 번에 전달하세요."),
        quiz("uvm_config_db#(int)::set(...) 한 값을 #(bit[31:0]) 으로 get 하면?",
             ["① 자동 변환되어 받아진다",
              "② 실패한다. 타입이 정확히 같아야 한다",
              "③ 컴파일 에러",
              "④ 경고와 함께 받아진다"],
             "② — config_db 는 타입별로 별개의 저장소를 씁니다. "
             "int 로 넣은 것은 int 로만 꺼낼 수 있습니다."),
    ],
}


# ==========================================================================
CH28 = {
    "number": "CHAPTER 28",
    "title": "sequence_item",
    "goals": [
        "트랜잭션 클래스를 설계한다",
        "uvm_field 매크로의 효과를 안다",
        "do_ 메서드로 직접 구현한다",
        "매크로와 수동 구현을 상황에 맞게 고른다",
    ],
    "body": [
        lead("sequence_item 은 자극 하나를 담는 데이터 묶음입니다. "
             "클럭마다 하나씩, 수천 개가 만들어졌다 사라집니다. "
             "여기에 무엇을 넣고 무엇을 빼는지가 테스트벤치 품질을 좌우합니다."),

        h2("28.1  기본 구조"),
        code("seq_item.sv", """
class seq_item extends uvm_sequence_item;

    // 입력 - 랜덤화 대상
    rand logic        en;
    rand logic [31:0] d;

    // 출력 - DUT 가 채워줌
    logic [31:0] q;

    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(en, UVM_DEFAULT)
        `uvm_field_int(d,  UVM_DEFAULT)
        `uvm_field_int(q,  UVM_DEFAULT)
    `uvm_object_utils_end

    function new(input string name = "seq_item");
        super.new(name);
    endfunction

    constraint c_d { d inside {[0:32'hFFFF]}; }
endclass
"""),
        key("입력과 출력을 나눠라",
            "rand 가 붙은 것이 자극(입력), 안 붙은 것이 응답(출력)입니다. "
            "q 에 rand 를 붙이면 랜덤화 때 덮어써져서 "
            "모니터가 채운 값이 사라집니다."),

        h2("28.2  uvm_field 매크로가 해주는 일"),
        table(["기능", "매크로 없이", "매크로 있으면"],
              [["print()", "do_print 직접 구현", "자동"],
               ["copy()", "do_copy 직접 구현", "자동"],
               ["compare()", "do_compare 직접 구현", "자동"],
               ["clone()", "직접 구현", "자동"],
               ["pack/unpack", "직접 구현", "자동"],
               ["config_db 자동 설정", "불가", "가능"]],
              weights=[1.0, 1.2, 0.9]),
        code("field_macros.sv", """
`uvm_field_int   (name, FLAG)      // 정수형
`uvm_field_object(name, FLAG)      // uvm_object 핸들
`uvm_field_string(name, FLAG)      // 문자열
`uvm_field_enum  (type, name, FLAG)// enum
`uvm_field_array_int (name, FLAG)  // 배열
`uvm_field_queue_int (name, FLAG)  // 큐
"""),
        code("field_flags.sv", """
UVM_DEFAULT      // 전부 활성 (가장 흔함)
UVM_ALL_ON       // 동일
UVM_NOCOMPARE    // compare 에서 제외
UVM_NOPRINT      // print 에서 제외
UVM_NOPACK       // pack 에서 제외
UVM_HEX          // 16진 출력
UVM_DEC          // 10진 출력
"""),
        code("flag_combine.sv", """
`uvm_object_utils_begin(seq_item)
    `uvm_field_int(d, UVM_DEFAULT | UVM_HEX)
    // q 는 DUT 응답이라 비교 대상에서 제외
    `uvm_field_int(q, UVM_DEFAULT | UVM_NOCOMPARE)
`uvm_object_utils_end
"""),
        warn("매크로의 비용",
             "field 매크로는 리플렉션 비슷한 코드를 생성해 "
             "런타임 문자열 비교를 합니다. 트랜잭션이 수백만 개면 "
             "시뮬레이션 속도에 눈에 띄는 영향을 줍니다. "
             "성능이 중요한 프로젝트는 do_ 메서드를 직접 씁니다."),

        h2("28.3  do_ 메서드 직접 구현"),
        code("do_methods.sv", """
class seq_item extends uvm_sequence_item;
    `uvm_object_utils(seq_item)      // field 매크로 없이

    rand logic        en;
    rand logic [31:0] d;
    logic [31:0]      q;

    function new(string name = "seq_item");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        seq_item t;
        super.do_copy(rhs);
        if (!$cast(t, rhs)) `uvm_fatal("COPY", "타입 불일치")
        en = t.en;  d = t.d;  q = t.q;
    endfunction

    virtual function bit do_compare(uvm_object rhs,
                                    uvm_comparer comparer);
        seq_item t;
        if (!$cast(t, rhs)) return 0;
        return super.do_compare(rhs, comparer)
               && (en === t.en) && (d === t.d);
    endfunction

    virtual function string convert2string();
        return $sformatf("en=%0b d=0x%08h q=0x%08h", en, d, q);
    endfunction
endclass
"""),
        tip("convert2string 을 꼭 만들어라",
            "매크로를 쓰든 안 쓰든 이건 직접 만드는 편이 좋습니다. "
            "print() 의 표 형식 출력보다 한 줄 요약이 로그에서 훨씬 읽기 "
            "쉽습니다. `uvm_info(\"DRV\", item.convert2string(), UVM_HIGH) "
            "형태로 씁니다."),

        h2("28.4  기대값을 아이템이 갖게 하기"),
        code("self_predict.sv", """
class adder_item extends uvm_sequence_item;
    rand bit [7:0] a, b;
    bit [8:0]      y;          // DUT 응답
    bit [8:0]      expected;   // 기대값

    function void post_randomize();
        expected = a + b;      // 랜덤 직후 기대값 계산
    endfunction

    function bit check();
        return (y === expected);
    endfunction
endclass
"""),
        p("이렇게 하면 스코어보드가 얇아집니다. "
          "아이템이 스스로 자기 정답을 알기 때문입니다. "
          "다만 레퍼런스 모델이 복잡하면 스코어보드로 분리하는 편이 낫습니다."),

        h2("28.5  트랜잭션 설계 원칙"),
        ol("추상화 수준을 맞춘다 - 핀 레벨 신호가 아니라 '읽기/쓰기' 같은 "
           "의미 단위로 만든다",
           "입력과 출력을 명확히 구분한다 - rand 유무로 표현",
           "제약을 아이템에 둔다 - 시퀀스마다 반복하지 않도록",
           "convert2string 을 만든다 - 디버깅 시간이 절반이 된다",
           "필요 없는 필드는 넣지 않는다 - 수천 개가 만들어진다"),

        h2("28.6  트랜잭션 레코딩"),
        p("파형 뷰어에 신호가 아니라 트랜잭션을 띄울 수 있습니다. "
          "'0x00A5 가 25ns 에 인가됨'을 파형에서 블록 하나로 보는 것입니다."),
        code("recording.svh", """
class reg_monitor extends uvm_monitor;
    virtual task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            @(vif.cb);
            item = seq_item::type_id::create("mon_item");
            void'(begin_tr(item, "reg_txn"));    // 트랜잭션 시작 기록
            item.en = vif.cb.en;
            item.d  = vif.cb.d;
            @(vif.cb);
            item.q  = vif.cb.q;
            end_tr(item);                        // 종료 기록
            ap.write(item);
        end
    endtask
endclass
"""),
        table(["메서드", "역할"],
              [["begin_tr(item, name)", "트랜잭션 시작 시각 기록"],
               ["end_tr(item)", "종료 시각 기록"],
               ["item.enable_recording(name)", "이 아이템의 레코딩 활성"],
               ["+UVM_TR_RECORD", "레코딩 전역 활성 옵션"]],
              weights=[1.4, 1.4]),
        note("도구 지원",
             "Questa 나 VCS 는 파형에 트랜잭션 스트림을 그려 줍니다. "
             "Vivado xsim 은 지원이 제한적이라 효과를 보기 어렵습니다. "
             "개념만 알아두고, 상용 도구를 쓸 때 활용하세요.",
             "warn"),

        h2("28.7  트랜잭션 비교 커스터마이즈"),
        code("custom_compare.sv", """
virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    seq_item t;
    bit ok = 1;
    if (!$cast(t, rhs)) return 0;

    ok &= comparer.compare_field("en", en, t.en, 1);
    ok &= comparer.compare_field("d",  d,  t.d, 32);
    // q 는 DUT 응답이라 비교에서 제외
    return ok;
endfunction
"""),
        p("comparer 를 쓰면 어느 필드가 왜 달랐는지 UVM 이 "
          "메시지를 만들어 줍니다. 직접 if 로 비교하는 것보다 "
          "실패 메시지가 훨씬 친절합니다."),
        code("comparer_output.txt", """
UVM_INFO: Miscompare for item.d: lhs = 'h0000ABCD : rhs = 'h0000ABCE
UVM_INFO: 1 Miscompare(s) for object item@1234 vs. item@5678
"""),

        h2("28.8  실습"),
        lab("과제 28-A",
            "가산기용 seq_item 을 만들고 post_randomize 에서 기대값을 "
            "계산하도록 하세요."),
        lab("과제 28-B",
            "field 매크로 버전과 do_ 메서드 버전을 각각 만들어 "
            "print() 출력이 어떻게 다른지 비교하세요."),
        quiz("DUT 응답 필드 q 에 rand 를 붙이면?",
             ["① 컴파일 에러",
              "② randomize 때 덮어써져 모니터가 넣은 값이 사라진다",
              "③ 아무 문제 없다",
              "④ 자동으로 무시된다"],
             "② — rand 필드는 randomize() 호출 때마다 값이 바뀝니다. "
             "DUT 응답은 rand 를 붙이지 않습니다."),
    ],
}


# ==========================================================================
CH29 = {
    "number": "CHAPTER 29",
    "title": "sequence 와 sequencer",
    "goals": [
        "sequence 와 sequence_item 의 차이를 설명한다",
        "start_item / finish_item 의 순서를 지킨다",
        "계층적 sequence 를 구성한다",
        "sequencer 의 중재 기능을 활용한다",
    ],
    "body": [
        lead("이 장의 첫 질문 - sequence 와 sequence_item 은 무엇이 다른가. "
             "한 줄로 답하면, item 은 자극 하나(데이터)이고 "
             "sequence 는 그 자극들을 몇 개 어떤 순서로 만들지 정하는 "
             "시나리오(행위)입니다."),

        h2("29.1  둘의 차이"),
        table(["구분", "uvm_sequence_item", "uvm_sequence"],
              [["정체", "트랜잭션 데이터 묶음", "아이템을 생성/전달하는 절차"],
               ["내용", "rand 필드, 응답 필드", "body() 안의 반복/조건/순서"],
               ["개수", "클럭마다 하나, 수천 개", "테스트당 1~몇 개"],
               ["비유", "주문서 한 장", "'아메리카노 5잔, 그다음 라떼 3잔'"],
               ["고유 메서드", "-", "start_item / finish_item"]],
              weights=[0.8, 1.3, 1.5]),
        key("sequence 는 핀을 만지지 않는다",
            "sequence 는 sequencer 를 통해 item 을 driver 에게 넘길 뿐이고, "
            "실제 핀 구동(vif.en <= ...)은 driver 만 합니다. "
            "이 분리가 재사용의 핵심입니다."),

        h2("29.2  sequence 작성"),
        code("sequence.sv", """
class reg_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(reg_sequence)

    rand int unsigned n = 10;
    constraint c_n { n inside {[5:50]}; }

    function new(input string name = "reg_sequence");
        super.new(name);
    endfunction

    virtual task body();
        seq_item item;                          // 지역 변수 권장
        repeat (n) begin
            item = seq_item::type_id::create("item");
            start_item(item);                   // (1)
            if (!item.randomize())              // (2)
                `uvm_error("SEQ", "randomize 실패")
            finish_item(item);                  // (3)
        end
    endtask
endclass
"""),
        key("순서가 핵심",
            "start_item -> randomize -> finish_item. "
            "이 순서를 지켜야 하는 이유가 다음 절입니다."),

        h2("29.3  왜 그 순서인가"),
        art("""
   (1) start_item(item)
       sequencer 에게 "보낼 준비 됐다" 요청
       driver 가 get_next_item 으로 받을 준비될 때까지 블록
                    |
                    v
   (2) randomize()
       driver 가 이미 대기 중인 이 시점에 값을 확정
       -> late randomization : 가장 늦은 시점의 상태를 반영 가능
                    |
                    v
   (3) finish_item(item)
       driver 에게 넘기고 item_done() 이 올 때까지 블록
"""),
        trap("finish_item 다음에 randomize 하면",
             "이미 driver 가 가져가서 핀에 인가한 객체를 "
             "뒤늦게 바꾸는 셈이 됩니다. driver 가 본 값과 "
             "스코어보드가 보는 값이 달라집니다."),
        code("wrong_order.sv", """
// 틀린 코드 - 실제 수업 과제에서 자주 나오는 형태
start_item(item);
finish_item(item);         // 여기서 이미 driver 에게 감
if (item.randomize()) begin
    `uvm_fatal("SEQ", "...")    // 조건도 반대
end
finish_item(item);         // 두 번째 호출 - 프로토콜 위반
"""),
        code("right_order.sv", """
// 올바른 코드
start_item(item);
if (!item.randomize())
    `uvm_error("SEQ", "randomize 실패")
finish_item(item);
"""),

        h2("29.4  간편 매크로"),
        code("seq_macros.sv", """
// `uvm_do : create + start_item + randomize + finish_item
task body();
    repeat (10) `uvm_do(req)
endtask

// 인라인 제약 포함
task body();
    `uvm_do_with(req, { a inside {[200:255]}; b > 200; })
endtask
"""),
        note("매크로 vs 수동",
             "`uvm_do 는 짧지만 무슨 일이 일어나는지 숨깁니다. "
             "학습 단계에서는 start_item/finish_item 을 직접 쓰면서 "
             "흐름을 익히고, 익숙해진 뒤 매크로를 쓰는 편이 좋습니다. "
             "실무에서도 디버깅 때문에 수동 방식을 선호하는 팀이 많습니다.",
             "info"),

        h2("29.5  계층적 sequence"),
        p("sequence 안에서 다른 sequence 를 부를 수 있습니다. "
          "시나리오를 조립하는 방식입니다."),
        code("hierarchical_seq.sv", """
class reset_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(reset_sequence)
    virtual task body();
        seq_item item;
        item = seq_item::type_id::create("rst");
        start_item(item);
        item.en = 0;  item.d = 0;      // 랜덤 대신 고정값
        finish_item(item);
    endtask
endclass

class full_test_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(full_test_sequence)
    virtual task body();
        reset_sequence  rst;
        reg_sequence    rnd;
        burst_sequence  brst;

        rst  = reset_sequence::type_id::create("rst");
        rnd  = reg_sequence  ::type_id::create("rnd");
        brst = burst_sequence::type_id::create("brst");

        rst.start(m_sequencer);        // 부모의 sequencer 재사용
        rnd.start(m_sequencer);
        brst.start(m_sequencer);
    endtask
endclass
"""),
        tip("m_sequencer",
            "uvm_sequence 안에 이미 선언된 필드로, 이 시퀀스가 실행 중인 "
            "sequencer 를 가리킵니다. 하위 시퀀스를 시작할 때 "
            "그대로 넘기면 됩니다."),

        h2("29.6  sequence 시작하기"),
        code("start_sequence.sv", """
// 방법 1: test 의 run_phase 에서 직접
virtual task run_phase(uvm_phase phase);
    reg_sequence seq = reg_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agt.seqr);
    phase.drop_objection(this);
endtask

// 방법 2: default_sequence 등록 (자동 시작)
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(uvm_object_wrapper)::set(this,
        "env.agt.seqr.main_phase", "default_sequence",
        reg_sequence::get_type());
endfunction
"""),
        p("방법 1이 명시적이고 디버깅하기 쉬워 학습 단계에 적합합니다."),

        h2("29.7  sequencer 와 중재"),
        p("여러 sequence 가 동시에 같은 sequencer 에 아이템을 보내면 "
          "sequencer 가 순서를 정합니다."),
        code("arbitration.sv", """
// 중재 방식 설정
seqr.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);

// 우선순위를 주며 시작
seq_hi.start(seqr, null, 500);    // 우선순위 500
seq_lo.start(seqr, null, 100);    // 우선순위 100
"""),
        table(["방식", "동작"],
              [["UVM_SEQ_ARB_FIFO", "도착 순서 (기본값)"],
               ["UVM_SEQ_ARB_STRICT_FIFO", "우선순위 우선, 같으면 FIFO"],
               ["UVM_SEQ_ARB_RANDOM", "무작위"],
               ["UVM_SEQ_ARB_WEIGHTED", "우선순위 가중 무작위"],
               ["UVM_SEQ_ARB_USER", "사용자 정의"]],
              weights=[1.3, 1.2]),

        h2("29.8  실습"),
        lab("과제 29-A",
            "reg_sequence 를 작성해 레지스터 DUT 에 랜덤 자극 10개를 "
            "인가하세요. start_item/finish_item 을 직접 쓰세요."),
        lab("과제 29-B",
            "reset_sequence 와 reg_sequence 를 만들고, 이 둘을 순서대로 "
            "부르는 상위 sequence 를 작성하세요."),
        quiz("start_item 과 finish_item 사이에서 randomize 를 하는 이유는?",
             ["① 문법상 그 위치에만 쓸 수 있어서",
              "② driver 가 대기 중인 가장 늦은 시점에 값을 확정하기 위해",
              "③ 성능이 좋아서",
              "④ 이유 없는 관례"],
             "② — late randomization 이라 합니다. driver 가 받을 준비가 된 "
             "시점의 최신 상태를 반영해 값을 정할 수 있습니다."),
    ],
}


# ==========================================================================
CH30 = {
    "number": "CHAPTER 30",
    "title": "driver 와 handshake",
    "goals": [
        "seq_item_port 프로토콜을 정확히 쓴다",
        "get_next_item 과 item_done 을 짝지어 쓴다",
        "응답을 시퀀스로 되돌린다",
        "핀 레벨 타이밍을 안전하게 구현한다",
    ],
    "body": [
        lead("driver 는 추상 트랜잭션을 핀 신호로 번역하는 유일한 부품입니다. "
             "여기서 타이밍이 틀리면 아무리 좋은 시나리오도 소용이 없습니다."),

        h2("30.1  기본 구조"),
        code("driver.sv", """
class reg_driver extends uvm_driver #(seq_item);
    `uvm_component_utils(reg_driver)

    virtual reg_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual reg_interface)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF", "vif 를 찾을 수 없습니다")
    endfunction

    virtual task run_phase(uvm_phase phase);
        reset_signals();
        forever begin
            seq_item_port.get_next_item(req);   // (1) 받기
            drive_item(req);                    // (2) 핀 구동
            seq_item_port.item_done();          // (3) 완료 통보
        end
    endtask

    task reset_signals();
        vif.en <= 1'b0;
        vif.d  <= 32'h0;
    endtask

    task drive_item(seq_item item);
        @(posedge vif.clk);
        vif.en <= item.en;
        vif.d  <= item.d;
        @(posedge vif.clk);
        vif.en <= 1'b0;
    endtask
endclass
"""),

        h2("30.2  핸드셰이크 프로토콜"),
        art("""
   sequence                sequencer               driver
      |                        |                     |
      | start_item(item)       |                     |
      |----------------------->|                     |
      |                        |  get_next_item(req) |
      |                        |<--------------------|
      |    (블록 해제)          |                     |
      |                        |                     |
      | randomize()            |                     |
      |                        |                     |
      | finish_item(item)      |                     |
      |----------------------->|-------------------->|
      |                        |                     | drive_item()
      |     (블록 - 대기)       |                     |   핀 구동
      |                        |    item_done()      |
      |                        |<--------------------|
      |    (블록 해제)          |                     |
      v                        |                     v
"""),
        table(["메서드", "하는 일"],
              [["get_next_item(req)", "아이템이 올 때까지 블록. 큐에서 제거 안 함"],
               ["try_next_item(req)", "즉시 확인. 없으면 req 가 null"],
               ["item_done()", "처리 완료 통보. 여기서 큐에서 제거"],
               ["item_done(rsp)", "응답을 함께 반환"],
               ["peek(req)", "보기만 하고 소비하지 않음"]],
              weights=[1.1, 1.7]),
        trap("get_next_item 과 item_done 은 반드시 1:1",
             "item_done 을 빼먹으면 시퀀스의 finish_item 이 영원히 블록되어 "
             "시뮬레이션이 멈춥니다. 두 번 부르면 프로토콜 위반 에러가 납니다. "
             "예외 경로(에러 처리, return)에서도 반드시 짝을 맞추세요."),

        h2("30.3  응답 되돌리기"),
        code("driver_response.sv", """
virtual task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(req);
        drive_item(req);

        // 응답 아이템 준비
        $cast(rsp, req.clone());
        rsp.set_id_info(req);        // 요청과 짝지음 - 필수
        rsp.q = vif.q;               // DUT 응답 담기

        seq_item_port.item_done(rsp);
    end
endtask
"""),
        code("sequence_response.sv", """
// 시퀀스에서 받기
virtual task body();
    seq_item item, rsp;
    repeat (10) begin
        item = seq_item::type_id::create("item");
        start_item(item);
        void'(item.randomize());
        finish_item(item);

        get_response(rsp);           // 응답 대기
        `uvm_info("SEQ", $sformatf("q=0x%08h", rsp.q), UVM_MEDIUM)
    end
endtask
"""),
        warn("set_id_info 를 빼먹으면",
             "어느 요청에 대한 응답인지 UVM 이 알 수 없어 "
             "get_response 가 엉뚱한 것을 받거나 블록됩니다."),
        tip("응답이 꼭 필요한가",
            "스코어보드가 모니터로 결과를 받는다면 driver 응답은 "
            "필요 없습니다. 시퀀스가 이전 결과에 따라 다음 자극을 "
            "결정해야 할 때만 쓰세요."),

        h2("30.4  타이밍 - 경쟁 조건 피하기"),
        code("timing_bad.sv", """
// 위험: NBA 갱신 전에 읽을 수 있다
task drive_item(seq_item item);
    @(posedge vif.clk);
    vif.en = item.en;        // 블로킹 대입 - 경쟁 조건
    vif.d  = item.d;
    item.q = vif.q;          // 갱신 전 값을 읽을 수 있다
endtask
"""),
        code("timing_ok.sv", """
// 개선: 논블로킹 + 안정화 지연
task drive_item(seq_item item);
    @(posedge vif.clk);
    vif.en <= item.en;       // 논블로킹
    vif.d  <= item.d;
    @(posedge vif.clk);
    #1;                      // NBA 영역 통과
    item.q = vif.q;
endtask
"""),
        code("timing_best.sv", """
// 최선: clocking block
task drive_item(seq_item item);
    @(vif.cb);
    vif.cb.en <= item.en;
    vif.cb.d  <= item.d;
    @(vif.cb);
    item.q = vif.cb.q;       // #1 불필요
endtask
"""),
        key("단계별 개선",
            "블로킹 -> 논블로킹 -> clocking block 순서로 개선합니다. "
            "clocking block 을 쓰면 타임스케일이나 클럭 주기가 바뀌어도 "
            "코드가 그대로 동작합니다."),

        h2("30.5  리셋 처리"),
        code("driver_reset.sv", """
virtual task run_phase(uvm_phase phase);
    fork
        reset_monitor();      // 리셋 감시
        drive_loop();         // 정상 구동
    join
endtask

task reset_monitor();
    forever begin
        @(negedge vif.resetn);
        `uvm_info("DRV", "리셋 감지 - 신호 초기화", UVM_LOW)
        reset_signals();
        @(posedge vif.resetn);
    end
endtask
"""),

        h2("30.6  실습"),
        lab("과제 30-A",
            "레지스터 DUT 용 driver 를 작성하고 시퀀스와 연결해 "
            "파형에서 en, d 가 인가되는지 확인하세요."),
        lab("과제 30-B",
            "item_done() 을 주석 처리하고 시뮬레이션이 어떻게 되는지 "
            "확인하세요."),
        quiz("get_next_item 후 item_done 을 부르지 않으면?",
             ["① 다음 아이템이 자동으로 온다",
              "② 시퀀스의 finish_item 이 영원히 블록된다",
              "③ 에러 메시지만 나오고 계속 진행된다",
              "④ 아이템이 큐에 쌓인다"],
             "② — finish_item 은 item_done 을 기다립니다. "
             "시뮬레이션이 그 자리에서 멈춘 것처럼 보입니다."),
    ],
}


# ==========================================================================
CH31 = {
    "number": "CHAPTER 31",
    "title": "monitor · agent · env · TLM",
    "goals": [
        "모니터를 수동적으로 유지한다",
        "analysis port 로 다중 구독을 구현한다",
        "agent 와 env 로 계층을 조립한다",
        "TLM 포트 종류를 구분해 쓴다",
    ],
    "body": [
        lead("남은 부품들을 조립합니다. 여기까지 오면 완전한 UVM 환경이 "
             "완성됩니다."),

        h2("31.1  monitor - 절대 구동하지 않는다"),
        code("monitor.sv", """
class reg_monitor extends uvm_monitor;
    `uvm_component_utils(reg_monitor)

    virtual reg_interface vif;
    uvm_analysis_port #(seq_item) ap;     // 브로드캐스트 포트

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual reg_interface)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF", "vif 없음")
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            @(posedge vif.clk);
            if (vif.resetn && vif.en) begin
                item = seq_item::type_id::create("mon_item");
                item.en = vif.en;          // 읽기만 한다
                item.d  = vif.d;
                @(posedge vif.clk);
                #1;
                item.q = vif.q;
                ap.write(item);            // 구독자 전원에게 전송
            end
        end
    endtask
endclass
"""),
        key("monitor 는 읽기 전용",
            "vif 에 <= 나 = 로 값을 쓰는 코드가 monitor 에 있으면 "
            "설계가 잘못된 것입니다. passive agent 로 재사용할 수 "
            "없게 됩니다."),

        h2("31.2  TLM 포트 종류"),
        table(["포트", "연결", "블록", "용도"],
              [["analysis_port", "1 : N", "안 함", "모니터 브로드캐스트"],
               ["analysis_imp", "수신측", "안 함", "스코어보드/커버리지 수신"],
               ["blocking_put_port", "1 : 1", "함", "생산자 -> 소비자"],
               ["blocking_get_port", "1 : 1", "함", "소비자 <- 생산자"],
               ["seq_item_port", "1 : 1", "함", "driver <- sequencer"],
               ["analysis_fifo", "버퍼", "-", "수신 버퍼링"]],
              weights=[1.3, 0.8, 0.6, 1.3]),
        code("analysis_port.sv", """
// 발신: 모니터
uvm_analysis_port #(seq_item) ap;
ap = new("ap", this);
ap.write(item);              // 논블로킹 - 구독자가 없어도 됨

// 수신: 스코어보드
uvm_analysis_imp #(seq_item, adder_scoreboard) item_export;
item_export = new("item_export", this);

virtual function void write(seq_item t);   // 이름이 write 여야 함
    compare(t);
endfunction
"""),
        note("write 라는 이름",
             "analysis_imp 는 수신 함수 이름이 반드시 write 여야 합니다. "
             "매크로가 그 이름으로 호출을 연결하기 때문입니다.",
             "info"),

        h2("31.3  구독자가 여럿일 때"),
        code("multi_subscriber.sv", """
class reg_env extends uvm_env;
    reg_agent      agt;
    reg_scoreboard scb;
    reg_coverage   cov;

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.item_export);   // 하나의 포트에
        agt.mon.ap.connect(cov.item_export);   // 둘을 연결
    endfunction
endclass
"""),
        art("""
                     +---> scoreboard.item_export
   monitor.ap -------+
                     +---> coverage.item_export

   analysis_port 는 1:N 연결이 가능하고,
   write() 하면 모든 구독자의 write() 가 순서대로 불린다.
"""),
        warn("구독자가 아이템을 고치면",
             "같은 핸들이 전달되므로 한 구독자가 고치면 다른 구독자도 "
             "영향을 받습니다. 수신측에서 값을 변경할 거면 "
             "clone() 해서 쓰세요."),

        h2("31.4  여러 종류를 수신할 때"),
        p("스코어보드가 입력 모니터와 출력 모니터에서 각각 받아야 하면 "
          "analysis_imp 를 두 개 두어야 하는데, 함수 이름이 둘 다 write 라 "
          "충돌합니다. 매크로가 이를 해결합니다."),
        code("uvm_analysis_imp_decl.sv", """
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class pipe_scoreboard extends uvm_scoreboard;
    uvm_analysis_imp_in  #(seq_item, pipe_scoreboard) in_export;
    uvm_analysis_imp_out #(seq_item, pipe_scoreboard) out_export;

    virtual function void write_in (seq_item t); ... endfunction
    virtual function void write_out(seq_item t); ... endfunction
endclass
"""),
        p("`uvm_analysis_imp_decl(_in) 이 write_in 이라는 이름의 "
          "수신 함수를 갖는 새 imp 타입을 만들어 줍니다."),

        h2("31.5  agent"),
        code("agent.sv", """
class reg_agent extends uvm_agent;
    `uvm_component_utils(reg_agent)

    reg_sequencer seqr;
    reg_driver    drv;
    reg_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = reg_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            seqr = reg_sequencer::type_id::create("seqr", this);
            drv  = reg_driver   ::type_id::create("drv",  this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
"""),
        code("sequencer.sv", """
// sequencer 는 보통 typedef 한 줄이면 끝
typedef uvm_sequencer #(seq_item) reg_sequencer;

// 중재를 커스터마이즈할 때만 클래스로 만든다
class reg_sequencer extends uvm_sequencer #(seq_item);
    `uvm_component_utils(reg_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
"""),

        h2("31.6  env"),
        code("env.sv", """
class reg_env extends uvm_env;
    `uvm_component_utils(reg_env)

    reg_agent      agt;
    reg_scoreboard scb;
    reg_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = reg_agent     ::type_id::create("agt", this);
        scb = reg_scoreboard::type_id::create("scb", this);
        cov = reg_coverage  ::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.item_export);
        agt.mon.ap.connect(cov.item_export);
    endfunction
endclass
"""),

        h2("31.7  전체 조립도"),
        art("""
   +-- tb_register (module) ---------------------------------+
   |                                                          |
   |   reg_interface intf();      uvm_register dut(...);      |
   |          |                        ^                      |
   |          | config_db              | 핀 연결               |
   |          v                        |                      |
   |   +-- uvm_test_top -----------------------------------+  |
   |   |                                                    | |
   |   |  +-- env -----------------------------------+      | |
   |   |  |                                          |      | |
   |   |  |  +- agt ----------------+                |      | |
   |   |  |  |  seq -> seqr -> drv -+---> (핀 구동)   |      | |
   |   |  |  |                mon <-+---- (핀 관측)   |      | |
   |   |  |  +----------------|-----+                |      | |
   |   |  |                   | ap                   |      | |
   |   |  |          +--------+--------+             |      | |
   |   |  |          v                 v             |      | |
   |   |  |        scb                cov            |      | |
   |   |  +------------------------------------------+      | |
   |   +----------------------------------------------------+ |
   +----------------------------------------------------------+
"""),

        h2("31.8  TLM FIFO - 버퍼가 필요할 때"),
        p("analysis_imp 의 write() 는 함수라 시간을 쓸 수 없습니다. "
          "수신측이 시간을 소비하며 처리해야 하면 FIFO 로 받아둡니다."),
        code("tlm_fifo.svh", """
class slow_checker extends uvm_component;
    `uvm_component_utils(slow_checker)

    uvm_tlm_analysis_fifo #(seq_item) fifo;

    function new(string n, uvm_component p);
        super.new(n, p);
        fifo = new("fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            fifo.get(item);          // 블로킹 - task 안이므로 가능
            @(posedge vif.clk);      // 시간 소비 가능
            check_slowly(item);
        end
    endtask
endclass

// env 에서 연결
agt.mon.ap.connect(chk.fifo.analysis_export);
"""),
        table(["수신 방식", "언제 쓰나"],
              [["uvm_analysis_imp", "즉시 처리 가능 (함수)"],
               ["uvm_subscriber", "analysis_imp 를 감싼 편의 클래스"],
               ["uvm_tlm_analysis_fifo", "시간을 소비해 처리해야 할 때"],
               ["uvm_analysis_export", "자식의 imp 로 중계할 때"]],
              weights=[1.3, 1.5]),
        trap("FIFO 가 가득 차면",
             "기본 크기는 무제한이라 넘치지는 않지만, "
             "소비가 생산보다 느리면 메모리가 계속 늘어납니다. "
             "긴 회귀에서 메모리 부족의 원인이 됩니다."),

        h2("31.9  포트 연결 규칙"),
        art("""
   연결 방향은 항상 "port -> export" 또는 "export -> imp"

   자식 -> 부모로 올릴 때 (export 로 중계)

     agent 안의 monitor.ap  --connect-->  agent.ap (analysis_export)
     env 안의 agent.ap      --connect-->  scoreboard.imp

   코드로는

     // agent 의 connect_phase
     mon.ap.connect(this.ap);            // ap 는 analysis_export

     // env 의 connect_phase
     agt.ap.connect(scb.item_export);
"""),
        code("export_relay.svh", """
class reg_agent extends uvm_agent;
    reg_monitor                   mon;
    uvm_analysis_port #(seq_item) ap;   // 밖으로 내보내는 창구

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(this.ap);        // 자식의 포트를 밖으로 중계
    endfunction
endclass
"""),
        tip("agent 에 ap 를 두는 이유",
            "env 가 agt.mon.ap 처럼 손자를 직접 참조하면 "
            "agent 내부 구조에 의존하게 됩니다. agent 가 자기 ap 를 "
            "노출하면 내부를 바꿔도 env 는 그대로입니다."),

        h2("31.10  실습"),
        lab("과제 31-A",
            "레지스터 DUT 용 monitor 를 작성하고 analysis_port 로 "
            "스코어보드에 연결하세요."),
        lab("과제 31-B",
            "커버리지 컬렉터를 추가해 모니터 하나에 구독자 둘을 "
            "연결하세요."),
        quiz("analysis_port 의 write() 가 블로킹하지 않는 이유는?",
             ["① 성능 때문",
              "② 모니터가 관측을 멈추면 안 되므로. 구독자가 없어도 진행",
              "③ UVM 버그",
              "④ 실제로는 블로킹한다"],
             "② — 모니터는 DUT 를 계속 관측해야 합니다. "
             "구독자 사정으로 관측이 멈추면 트랜잭션을 놓칩니다."),
    ],
}


CHAPTERS = [CH22, CH23, CH24, CH25, CH26, CH27, CH28, CH29, CH30, CH31]
