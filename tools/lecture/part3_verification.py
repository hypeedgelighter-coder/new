"""Part III - 검증 기법 (프로세스 통신 / 커버리지 / assertion / 스코어보드)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART III",
    "title": "검증 기법과 측정",
    "blurb": "자극을 만드는 것만으로는 검증이 아닙니다. 결과를 확인하고, "
             "무엇을 시험했는지 측정하고, 프로토콜 위반을 자동으로 잡아내야 "
             "합니다. 이 파트는 UVM 이전에 알아야 할 검증 기법을 다룹니다.",
    "items": [
        "16장 프로세스 간 통신 - mailbox · semaphore · event",
        "17장 기능 커버리지",
        "18장 SystemVerilog Assertion 기초",
        "19장 SVA 시퀀스와 프로퍼티",
        "20장 스코어보드 설계",
        "21장 검증 계획과 종료 조건",
    ],
}


# ==========================================================================
CH16 = {
    "number": "CHAPTER 16",
    "title": "프로세스 간 통신",
    "goals": [
        "mailbox 로 생산자와 소비자를 분리한다",
        "semaphore 로 자원 접근을 직렬화한다",
        "event 로 동기화 지점을 만든다",
        "UVM TLM 이 무엇을 대체했는지 이해한다",
    ],
    "body": [
        lead("계층형 테스트벤치는 여러 프로세스가 동시에 돕니다. "
             "생성기, 드라이버, 모니터, 스코어보드가 각자의 속도로 움직이면서 "
             "데이터를 주고받아야 합니다. UVM 의 TLM 포트가 이 문제를 "
             "추상화한 것인데, 그 아래에 있는 원시 도구부터 봅니다."),

        h2("16.1  mailbox"),
        p("프로세스 사이의 FIFO 입니다. 넣을 자리가 없으면 넣는 쪽이 "
          "기다리고, 꺼낼 것이 없으면 꺼내는 쪽이 기다립니다."),
        code("mailbox_basic.sv", """
mailbox #(seq_item) mbx = new(4);   // 크기 4, 0 이면 무제한

// 생산자
task generator();
    seq_item item;
    repeat (100) begin
        item = new();
        void'(item.randomize());
        mbx.put(item);        // 가득 차면 여기서 블록
    end
endtask

// 소비자
task driver();
    seq_item item;
    forever begin
        mbx.get(item);        // 비어 있으면 여기서 블록
        drive(item);
    end
endtask
"""),
        table(["메서드", "동작"],
              [["put(x)", "넣는다. 가득 차면 대기"],
               ["get(x)", "꺼낸다. 비어 있으면 대기"],
               ["peek(x)", "꺼내지 않고 본다"],
               ["try_put(x)", "즉시 시도. 실패하면 0 반환"],
               ["try_get(x)", "즉시 시도. 실패하면 0 반환"],
               ["num()", "현재 개수"]],
              weights=[1.0, 1.6]),
        key("mailbox 가 해결하는 것",
            "생성기와 드라이버가 서로의 타이밍을 몰라도 됩니다. "
            "생성기는 만들기만 하고 드라이버는 꺼내 쓰기만 합니다. "
            "속도 차이는 mailbox 가 흡수합니다."),
        note("UVM 에서는",
             "이 역할을 sequencer 와 TLM 포트가 대신합니다. "
             "직접 mailbox 를 쓸 일은 드물지만, "
             "get_next_item 이 왜 블록하는지 이해하려면 이 개념이 필요합니다.",
             "info"),

        h2("16.2  semaphore"),
        p("공유 자원의 동시 접근을 막습니다. 열쇠를 가진 프로세스만 "
          "진입할 수 있습니다."),
        code("semaphore.sv", """
semaphore bus_lock = new(1);    // 열쇠 1개

task write_bus(int addr, int data);
    bus_lock.get(1);            // 열쇠를 얻을 때까지 대기
    vif.addr <= addr;
    vif.data <= data;
    vif.we   <= 1;
    @(posedge vif.clk);
    vif.we   <= 0;
    bus_lock.put(1);            // 열쇠 반납
endtask
"""),
        trap("반납을 잊으면 교착",
             "get 후 put 을 빼먹으면 이후 모든 프로세스가 영원히 대기합니다. "
             "시뮬레이션은 멈추지 않고 아무 일도 일어나지 않는 상태가 되어 "
             "원인을 찾기 어렵습니다."),
        code("semaphore_multi.sv", """
semaphore ch = new(4);      // 채널 4개

ch.get(2);                  // 2개 점유
// ... 작업 ...
ch.put(2);                  // 정확히 같은 개수 반납
"""),

        h2("16.3  event"),
        code("event_basic.sv", """
event reset_done;
event config_done;

// 알리는 쪽
initial begin
    apply_reset();
    -> reset_done;             // 트리거
end

// 기다리는 쪽
initial begin
    @(reset_done);             // 트리거를 기다림
    start_traffic();
end
"""),
        warn("@ 와 wait 의 차이",
             "@(ev) 는 '이 시점 이후의 트리거'를 기다립니다. "
             "이미 트리거된 이벤트는 놓칩니다. "
             "wait (ev.triggered) 는 같은 시각에 이미 트리거되었어도 통과합니다."),
        code("event_race.sv", """
// 위험: 트리거가 먼저 일어나면 영원히 대기
initial begin
    #10 -> ev;
end
initial begin
    #10 @(ev);          // 같은 시각 - 놓칠 수 있다
end

// 안전
initial begin
    #10 wait (ev.triggered);
end
"""),
        table(["구문", "이미 트리거된 이벤트"],
              [["@(ev)", "놓친다"],
               ["wait (ev.triggered)", "통과한다"],
               ["ev.wait_ptrigger()", "통과한다 (persistent)"]],
              weights=[1.1, 1.3]),

        h2("16.4  세 도구의 선택 기준"),
        kv([("mailbox", "데이터를 넘겨야 할 때. 순서와 개수가 중요"),
            ("semaphore", "자원을 독점해야 할 때. 데이터는 안 넘김"),
            ("event", "시점만 알리면 될 때. 데이터도 자원도 아님")], 84),

        h2("16.5  실습"),
        lab("과제 16-A",
            "mailbox 로 생성기와 드라이버를 연결하고, mailbox 크기를 "
            "1 과 100 으로 바꿔가며 시뮬레이션 동작을 비교하세요."),
        lab("과제 16-B",
            "semaphore 로 두 프로세스가 같은 버스를 쓰도록 만들고, "
            "semaphore 를 뺐을 때 신호가 어떻게 깨지는지 파형으로 확인하세요."),
        quiz("mailbox #(seq_item) mbx = new(); 에서 인자를 생략하면?",
             ["① 크기 1", "② 크기 0 = 무제한", "③ 컴파일 에러", "④ 크기 16"],
             "② — 인자를 생략하면 크기가 0 이고, 이는 무제한을 뜻합니다. "
             "put 이 절대 블록하지 않으므로 생성기가 폭주할 수 있습니다."),
    ],
}


# ==========================================================================
CH17 = {
    "number": "CHAPTER 17",
    "title": "기능 커버리지",
    "goals": [
        "코드 커버리지와 기능 커버리지를 구분한다",
        "covergroup 과 coverpoint 를 작성한다",
        "cross 로 조합 커버리지를 측정한다",
        "커버리지 결과로 자극을 조정한다",
    ],
    "body": [
        lead("'테스트를 10000번 돌렸다'는 검증의 진척이 아닙니다. "
             "'무엇을 시험했는가'가 진척입니다. 커버리지는 그 질문에 "
             "숫자로 답하는 도구입니다."),

        h2("17.1  두 가지 커버리지"),
        table(["구분", "코드 커버리지", "기능 커버리지"],
              [["측정 대상", "RTL 코드 실행 여부", "설계 의도의 시나리오"],
               ["생성", "도구가 자동", "사람이 정의"],
               ["예", "라인, 브랜치, 토글, FSM", "'캐리 발생', '리셋 중 쓰기'"],
               ["100% 의미", "코드를 다 밟았다", "계획한 기능을 다 봤다"],
               ["누락 위험", "설계에 없는 기능", "정의하지 않은 시나리오"]],
              weights=[0.9, 1.2, 1.5]),
        key("둘 다 필요하다",
            "코드 커버리지 100% 여도 기능 커버리지가 낮으면 "
            "'코드는 다 실행했지만 의미 있는 조합은 안 봤다'는 뜻입니다. "
            "반대도 마찬가지입니다."),

        h2("17.2  covergroup 기본"),
        code("covergroup_basic.sv", """
class adder_coverage;
    bit [7:0] a, b;
    bit [8:0] y;

    covergroup cg;
        cp_a : coverpoint a {
            bins low    = {[0:63]};
            bins mid    = {[64:191]};
            bins high   = {[192:255]};
        }
        cp_carry : coverpoint y[8] {
            bins no_carry = {0};
            bins carry    = {1};
        }
    endgroup

    function new();
        cg = new();               // covergroup 은 반드시 new
    endfunction

    function void sample(bit [7:0] aa, bb, bit [8:0] yy);
        a = aa; b = bb; y = yy;
        cg.sample();              // 표본 수집
    endfunction
endclass
"""),
        trap("cg = new() 를 빼먹으면",
             "covergroup 은 클래스 안에서 자동 생성되지 않습니다. "
             "생성자에서 명시적으로 new 해야 합니다. "
             "빼먹으면 커버리지가 항상 0% 로 나오는데 에러는 안 납니다."),

        h2("17.3  bins 의 종류"),
        code("bins_kinds.sv", """
coverpoint addr {
    bins zero      = {0};                   // 단일 값
    bins low[]     = {[1:15]};              // 각 값마다 별개 bin (15개)
    bins group[4]  = {[16:255]};            // 4개로 자동 분할
    bins special   = {32, 64, 128};         // 값 목록
    bins others    = default;               // 나머지 전부

    ignore_bins rsvd = {[240:255]};         // 커버리지에서 제외
    illegal_bins bad = {[250:255]};         // 나오면 에러
}
"""),
        table(["선언", "의미"],
              [["bins x = {v}", "값 하나에 bin 하나"],
               ["bins x[] = {range}", "범위의 각 값마다 bin"],
               ["bins x[N] = {range}", "범위를 N 개 bin 으로 분할"],
               ["ignore_bins", "측정에서 제외 (분모에서 빠짐)"],
               ["illegal_bins", "관측되면 런타임 에러"]],
              weights=[1.1, 1.5]),
        tip("illegal_bins 의 활용",
             "'예약 주소는 절대 접근하면 안 된다' 같은 규칙을 "
             "커버리지로 감시할 수 있습니다. 자극 생성 버그를 잡는 데 유용합니다."),

        h2("17.4  cross 커버리지"),
        p("개별 항목이 아니라 조합을 봅니다. 실제 버그는 조합에서 나옵니다."),
        code("cross_coverage.sv", """
covergroup cg;
    cp_en   : coverpoint en   { bins on = {1}; bins off = {0}; }
    cp_rst  : coverpoint rstn { bins act = {0}; bins rel = {1}; }

    // en x rstn = 4가지 조합을 모두 봤는가
    x_en_rst : cross cp_en, cp_rst;
endgroup
"""),
        art("""
   cross 가 만드는 bin (2 x 2 = 4개)

              rstn=0(active)   rstn=1(released)
   en=0     |   [1]           |   [2]          |
   en=1     |   [3]           |   [4]          |
              ^
              +-- 리셋 중 쓰기 시도.  버그가 자주 숨는 자리
"""),
        code("cross_filter.sv", """
x_en_rst : cross cp_en, cp_rst {
    // 관심 없는 조합 제외
    ignore_bins idle = binsof(cp_en.off) && binsof(cp_rst.act);
}
"""),
        warn("cross 폭발",
             "coverpoint 3개를 cross 하고 각각 bin 이 10개면 1000개 bin 이 "
             "생깁니다. 100% 를 채우기가 사실상 불가능해집니다. "
             "cross 는 정말 의미 있는 조합에만 쓰고, "
             "ignore_bins 로 적극적으로 줄이세요."),

        h2("17.5  covergroup 옵션"),
        code("cg_options.sv", """
covergroup cg;
    option.per_instance = 1;      // 인스턴스별로 따로 집계
    option.name         = "adder_cg";
    option.comment      = "가산기 기능 커버리지";
    option.at_least     = 5;      // 5번은 봐야 covered 로 인정
    option.goal         = 95;     // 목표 95%

    cp_a : coverpoint a { ... }
endgroup
"""),
        kv([("per_instance", "1이면 인스턴스마다 별도 리포트. 에이전트가 여러 개일 때 필수"),
            ("at_least", "우연히 한 번 지나간 것을 covered 로 치지 않게 함"),
            ("weight", "전체 점수에서 이 항목의 비중"),
            ("goal", "100%가 비현실적일 때 현실적 목표 설정")], 92),

        h2("17.6  샘플링 시점"),
        p("언제 sample() 을 부르는가가 커버리지 품질을 결정합니다."),
        code("sample_timing.sv", """
// 방법 1: 모니터에서 트랜잭션 완료 시
function void write(seq_item t);
    cov.sample(t.a, t.b, t.y);
endfunction

// 방법 2: covergroup 에 클럭 이벤트를 직접 연결
covergroup cg @(posedge clk);
    cp_state : coverpoint state;
endgroup
"""),
        tip("트랜잭션 단위로 샘플링하라",
            "매 클럭 샘플링하면 idle 상태가 대부분을 차지해 "
            "커버리지 숫자가 왜곡됩니다. 의미 있는 트랜잭션이 "
            "완료된 시점에만 sample() 을 부르세요."),

        h2("17.7  실습"),
        lab("과제 17-A",
            "가산기에 대해 a 구간, b 구간, 캐리 발생을 각각 coverpoint 로 "
            "정의하고 cross 로 조합 커버리지를 측정하세요."),
        lab("과제 17-B",
            "랜덤 자극 100회, 1000회, 10000회를 돌려 커버리지가 "
            "어떻게 포화하는지 그래프로 그리세요."),
        quiz("커버리지가 오르지 않는 bin 을 발견했을 때 가장 먼저 할 일은?",
             ["① bin 을 ignore_bins 로 바꾼다",
              "② 그 bin 에 도달하는 자극이 제약상 생성 가능한지 확인한다",
              "③ 랜덤 시드를 바꿔 계속 돌린다",
              "④ at_least 를 1로 낮춘다"],
             "② — 제약이 그 영역을 막고 있는 경우가 대부분입니다. "
             "제약을 확인한 뒤에도 도달 불가능하면 그때 ignore_bins 를 "
             "검토합니다."),
    ],
}


# ==========================================================================
CH18 = {
    "number": "CHAPTER 18",
    "title": "SystemVerilog Assertion 기초",
    "goals": [
        "즉시 assertion 과 병행 assertion 을 구분한다",
        "샘플링 시점과 클럭 지정을 이해한다",
        "disable iff 로 리셋을 처리한다",
        "간단한 프로토콜 규칙을 assertion 으로 옮긴다",
    ],
    "body": [
        lead("스코어보드는 '결과가 맞는가'를 봅니다. assertion 은 "
             "'가는 과정이 규칙을 지키는가'를 봅니다. 프로토콜 위반은 "
             "결과가 우연히 맞아도 잡아내야 하고, 그것이 SVA 의 역할입니다."),

        h2("18.1  두 종류의 assertion"),
        table(["구분", "즉시 (immediate)", "병행 (concurrent)"],
              [["문법", "assert (expr)", "assert property (...)"],
               ["위치", "절차적 블록 안", "모듈/인터페이스 어디든"],
               ["평가", "실행되는 순간", "매 클럭 엣지"],
               ["시간", "0 시간", "여러 클럭에 걸침"],
               ["용도", "함수 인자 검사", "프로토콜 규칙"]],
              weights=[0.8, 1.2, 1.3]),
        code("immediate.sv", """
// 즉시 assertion - 그 순간의 조건만 본다
function void set_addr(int a);
    assert (a < 256)
    else `uvm_error("ADDR", $sformatf("주소 범위 초과 %0d", a));
endfunction
"""),
        code("concurrent.sv", """
// 병행 assertion - 매 클럭 감시
assert property (@(posedge clk) disable iff (!rstn)
    en |-> ##1 (q == $past(d))
) else `uvm_error("REG", "en 이후 q 가 d 를 따라가지 않음");
"""),

        h2("18.2  병행 assertion 의 구조"),
        art("""
   assert property ( @(posedge clk) disable iff (!rstn)
                     ^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^
                     클럭 지정        리셋 중 평가 중단

                     en |-> ##1 (q == $past(d))
                     ^^^ ^^^ ^^^ ^^^^^^^^^^^^^
                     선행  함축  지연   후행
   );
"""),
        kv([("@(posedge clk)", "언제 샘플링할지. 필수"),
            ("disable iff", "이 조건이면 평가를 중단. 보통 리셋"),
            ("선행 (antecedent)", "이것이 참일 때만 후행을 검사"),
            ("|-> (overlapped)", "같은 클럭에서 후행 시작"),
            ("|=> (non-overlap)", "다음 클럭에서 후행 시작")], 108),

        h2("18.3  함축 연산자"),
        code("implication.sv", """
// |-> 같은 클럭
assert property (@(posedge clk) req |-> gnt);
// req 가 1인 그 클럭에 gnt 도 1이어야 함

// |=> 다음 클럭
assert property (@(posedge clk) req |=> gnt);
// req 가 1이면 다음 클럭에 gnt 가 1이어야 함
// (req |-> ##1 gnt 와 같음)
"""),
        art("""
   clk    _|~|_|~|_|~|_|~|_

   req    __|~~~|__________

   |-> :  gnt 는 여기서 1이어야
             |
          __|~~~|__________

   |=> :  gnt 는 여기서 1이어야
                   |
          ______|~~~|______
"""),
        key("vacuous success",
            "선행이 거짓이면 assertion 은 '통과'로 집계됩니다. "
            "req 가 한 번도 1이 안 되면 이 assertion 은 무의미하게 "
            "100% 통과합니다. cover property 로 선행이 실제로 "
            "발생했는지 함께 확인하세요."),
        code("cover_property.sv", """
// 선행이 실제로 일어났는지 측정
cover property (@(posedge clk) req);
"""),

        h2("18.4  disable iff - 리셋 처리"),
        code("disable_iff.sv", """
// 리셋 중에는 프로토콜 규칙을 따질 필요가 없다
property p_reg_update;
    @(posedge clk) disable iff (!rstn)
    en |=> (q == $past(d));
endproperty

a_reg_update : assert property (p_reg_update)
    else `uvm_error("REG", $sformatf(
        "기대 %0h 실제 %0h", $past(d), q));
"""),
        trap("disable iff 를 빼먹으면",
             "리셋이 걸리는 순간 진행 중이던 모든 assertion 이 "
             "실패로 보고됩니다. 로그가 에러로 뒤덮여 진짜 버그를 "
             "찾을 수 없게 됩니다."),

        h2("18.5  유용한 시스템 함수"),
        table(["함수", "의미"],
              [["$past(x, N)", "N 클럭 전의 x 값 (기본 N=1)"],
               ["$rose(x)", "이번 클럭에 0->1 로 바뀜"],
               ["$fell(x)", "이번 클럭에 1->0 으로 바뀜"],
               ["$stable(x)", "이전 클럭과 값이 같음"],
               ["$changed(x)", "이전 클럭과 값이 다름"],
               ["$onehot(x)", "정확히 한 비트만 1"],
               ["$isunknown(x)", "X 나 Z 가 섞임"],
               ["$countones(x)", "1인 비트 개수"]],
              weights=[1.0, 1.6]),
        code("system_funcs.sv", """
// 리셋 해제 후 q 는 반드시 0
assert property (@(posedge clk) $rose(rstn) |-> (q == 0));

// 상태 벡터는 항상 one-hot
assert property (@(posedge clk) disable iff (!rstn) $onehot(state));

// 출력에 X 가 없어야 함
assert property (@(posedge clk) disable iff (!rstn) !$isunknown(q));
"""),

        h2("18.6  레지스터 DUT 에 적용하기"),
        code("register_sva.sv", """
interface reg_interface (input logic clk);
    logic        resetn, en;
    logic [31:0] d, q;

    // 1) 리셋이 걸리면 q 는 0
    a_reset : assert property (
        @(posedge clk) !resetn |=> (q == 32'h0)
    ) else $error("리셋 후 q 가 0 이 아님");

    // 2) en 이면 다음 클럭에 q 는 d
    a_load : assert property (
        @(posedge clk) disable iff (!resetn)
        en |=> (q == $past(d))
    ) else $error("en 이후 로드 실패");

    // 3) en 이 0 이면 q 유지
    a_hold : assert property (
        @(posedge clk) disable iff (!resetn)
        !en |=> $stable(q)
    ) else $error("en=0 인데 q 가 변함");
endinterface
"""),
        tip("assertion 을 interface 에 두는 이유",
            "DUT 를 수정하지 않고 검증만 추가할 수 있습니다. "
            "인터페이스는 이미 모든 신호를 보고 있으므로 "
            "assertion 을 넣기에 가장 자연스러운 자리입니다."),

        h2("18.7  실습"),
        lab("과제 18-A",
            "위 세 개의 assertion 을 reg_interface 에 넣고, "
            "DUT 의 en 조건을 일부러 반대로 바꿔 assertion 이 "
            "실패하는지 확인하세요."),
        quiz("assert property (@(posedge clk) req |-> gnt); 에서 req 가 한 번도 1이 아니면?",
             ["① 실패로 보고된다",
              "② vacuous success 로 통과 처리된다",
              "③ 컴파일 에러",
              "④ 평가되지 않고 무시된다"],
             "② — 선행이 거짓이면 함축은 참입니다. 통과로 집계되지만 "
             "실제로는 아무것도 검증하지 않은 상태입니다. "
             "cover property 로 선행 발생을 따로 확인해야 합니다."),
    ],
}


# ==========================================================================
CH19 = {
    "number": "CHAPTER 19",
    "title": "SVA 시퀀스와 프로퍼티",
    "goals": [
        "sequence 로 다중 클럭 패턴을 기술한다",
        "반복 연산자를 활용한다",
        "sequence 를 조합해 복잡한 규칙을 만든다",
        "재사용 가능한 프로퍼티 라이브러리를 설계한다",
    ],
    "body": [
        lead("한 클럭짜리 규칙은 앞 장으로 충분합니다. 하지만 실제 프로토콜은 "
             "'요청 후 2~5 클럭 안에 응답' 같은 시간 구간을 다룹니다. "
             "SVA sequence 가 그것을 표현합니다."),

        h2("19.1  지연 연산자"),
        code("delay_ops.sv", """
sequence s_basic;
    a ##1 b ##1 c;          // a, 1클럭 후 b, 1클럭 후 c
endsequence

sequence s_range;
    req ##[1:5] ack;        // req 후 1~5 클럭 사이에 ack
endsequence

sequence s_open;
    req ##[1:$] ack;        // req 후 언젠가 ack (무한 대기)
endsequence

sequence s_same;
    a ##0 b;                // 같은 클럭 (a && b 와 유사)
endsequence
"""),
        art("""
   req ##[1:5] ack

   clk   _|~|_|~|_|~|_|~|_|~|_|~|_|~|_
   req   __|~|________________________
                |<--- 이 구간 안에 --->|
                +1  +2  +3  +4  +5
   ack   ____________|~|______________   <- 통과
"""),
        warn("##[1:$] 의 위험",
             "무한 대기는 시뮬레이션이 끝날 때까지 미결 상태로 남습니다. "
             "끝나지 않은 assertion 은 실패로도 성공으로도 집계되지 않아 "
             "버그를 놓칩니다. 반드시 상한을 두세요."),

        h2("19.2  반복 연산자"),
        table(["연산자", "의미", "예"],
              [["[*N]", "연속 N번", "a[*3] = a ##1 a ##1 a"],
               ["[*M:N]", "연속 M~N번", "a[*1:3]"],
               ["[->N]", "비연속 N번째 발생", "a[->2] = 두 번째 a 까지"],
               ["[=N]", "비연속 N번 발생 후 자유", "a[=2]"]],
              weights=[0.8, 1.2, 1.4]),
        code("repetition.sv", """
// busy 가 3클럭 연속 유지되어야 함
sequence s_busy;
    $rose(start) ##1 busy[*3] ##1 done;
endsequence

// req 후 두 번째 ack 가 오면 완료
sequence s_two_ack;
    req ##1 ack[->2] ##1 done;
endsequence
"""),

        h2("19.3  sequence 조합"),
        code("sequence_ops.sv", """
sequence s_a;  req ##1 gnt;  endsequence
sequence s_b;  busy ##2 done; endsequence

// and : 둘 다 성립 (끝나는 시점은 다를 수 있음)
sequence s_and;  s_a and s_b;  endsequence

// intersect : 둘 다 성립하고 길이도 같음
sequence s_int;  s_a intersect s_b;  endsequence

// or : 둘 중 하나
sequence s_or;   s_a or s_b;   endsequence

// throughout : 전 구간에서 조건 유지
sequence s_thru; (!abort) throughout s_a;  endsequence

// within : 포함 관계
sequence s_within; s_a within s_b; endsequence
"""),
        kv([("and", "두 시퀀스 모두 만족. 종료 시점은 늦은 쪽"),
            ("intersect", "and 에 더해 시작과 끝이 같아야 함"),
            ("or", "둘 중 하나만 만족하면 됨"),
            ("throughout", "왼쪽 조건이 오른쪽 시퀀스 전 구간 유지"),
            ("within", "왼쪽 시퀀스가 오른쪽 안에 포함")], 86),

        h2("19.4  파라미터화된 프로퍼티"),
        p("같은 규칙을 여러 신호에 적용할 때 인자를 받는 프로퍼티를 만듭니다."),
        code("param_property.sv", """
// 재사용 가능한 handshake 규칙
property p_req_ack(req, ack, int min_d, int max_d);
    @(posedge clk) disable iff (!rstn)
    $rose(req) |-> ##[min_d:max_d] $rose(ack);
endproperty

// 여러 채널에 같은 규칙 적용
a_ch0 : assert property (p_req_ack(req0, ack0, 1, 5));
a_ch1 : assert property (p_req_ack(req1, ack1, 1, 5));
a_ch2 : assert property (p_req_ack(req2, ack2, 2, 10));
"""),
        tip("assertion 라이브러리",
            "handshake, one-hot, stable-during, no-x 같은 공통 규칙을 "
            "파라미터화된 프로퍼티로 모아 두면 프로젝트 전체에서 "
            "재사용할 수 있습니다. 실무 팀은 대부분 이런 패키지를 갖고 있습니다."),

        h2("19.5  local variable"),
        p("시퀀스 안에서 값을 기억해 두었다가 나중에 비교합니다."),
        code("local_var.sv", """
property p_data_match;
    int saved;
    @(posedge clk) disable iff (!rstn)
    ($rose(wr), saved = wdata) |-> ##3 (rdata == saved);
endproperty
"""),
        p("(expr, action) 형태를 로컬 변수 대입이라고 합니다. "
          "wr 이 올라가는 순간 wdata 를 saved 에 저장하고, "
          "3클럭 뒤 rdata 와 비교합니다."),

        h2("19.6  assertion 제어"),
        code("assert_control.sv", """
initial begin
    $assertoff(0, tb.dut);      // 전부 끄기
    #1000;
    $asserton(0, tb.dut);       // 다시 켜기
    // $assertkill : 진행 중인 것까지 강제 종료
end
"""),
        note("언제 쓰나",
             "초기화 구간처럼 규칙이 성립하지 않는 시기에 임시로 끕니다. "
             "다만 disable iff 로 처리할 수 있으면 그쪽이 더 명확합니다.",
             "info"),

        h2("19.7  실습"),
        lab("과제 19-A",
            "레지스터 DUT 에 대해 'en 이 3클럭 연속 1이면 q 가 매 클럭 "
            "d 를 따라간다'는 규칙을 sequence 로 작성하세요."),
        lab("과제 19-B",
            "파라미터화된 handshake 프로퍼티를 만들고 두 개 이상의 "
            "신호쌍에 적용하세요."),
        quiz("req ##[1:$] ack 의 문제점은?",
             ["① 문법 에러",
              "② 끝나지 않은 assertion 이 남아 버그를 놓칠 수 있다",
              "③ 시뮬레이션 속도가 느려진다",
              "④ 리셋 처리가 안 된다"],
             "② — 무한 상한은 시뮬레이션 종료 시 미결 상태로 남습니다. "
             "성공도 실패도 아니어서 집계되지 않습니다. 상한을 두세요."),
    ],
}


# ==========================================================================
CH20 = {
    "number": "CHAPTER 20",
    "title": "스코어보드 설계",
    "goals": [
        "레퍼런스 모델과 비교기를 분리한다",
        "순서가 뒤바뀌는 트랜잭션을 처리한다",
        "비교 실패 메시지를 진단 가능하게 만든다",
        "종료 시 미처리 항목을 검사한다",
    ],
    "body": [
        lead("스코어보드는 '이 결과가 맞는가'를 판정합니다. 검증 환경에서 "
             "PASS/FAIL 을 실제로 결정하는 유일한 부품이며, "
             "여기가 틀리면 나머지가 아무리 정교해도 소용이 없습니다."),

        h2("20.1  구조"),
        art("""
   sequence -> sequencer -> driver ---> [ DUT ] ---> monitor
                              |                          |
                              v                          v
                        [ 입력 관측 ]              [ 출력 관측 ]
                              |                          |
                              +--------> scoreboard <-----+
                                          |      |
                                    reference   compare
                                      model
"""),
        p("입력을 관측해 레퍼런스 모델에 넣고, 그 결과를 실제 출력과 "
          "비교합니다. 입력 관측을 드라이버에서 직접 받지 않고 "
          "모니터로 하는 것이 중요합니다."),
        key("왜 드라이버가 아니라 모니터인가",
            "드라이버가 '보냈다고 생각한 것'과 DUT 핀에 '실제로 인가된 것'이 "
            "다를 수 있습니다. 드라이버 버그를 잡으려면 "
            "실제 핀을 관측해야 합니다."),

        h2("20.2  기본 스코어보드"),
        code("scoreboard.sv", """
class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard)

    uvm_analysis_imp #(seq_item, adder_scoreboard) item_export;

    int unsigned match_cnt, mismatch_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    // 레퍼런스 모델
    function bit [8:0] predict(bit [7:0] a, b);
        return a + b;
    endfunction

    // 모니터가 트랜잭션을 보낼 때마다 호출된다
    virtual function void write(seq_item t);
        bit [8:0] exp = predict(t.a, t.b);
        if (t.y !== exp) begin
            mismatch_cnt++;
            `uvm_error("SCB", $sformatf(
                "불일치  a=%0d(0x%02h) b=%0d(0x%02h) 기대=%0d(0x%03h) 실제=%0d(0x%03h)",
                t.a, t.a, t.b, t.b, exp, exp, t.y, t.y))
        end else begin
            match_cnt++;
            `uvm_info("SCB", $sformatf("일치 a=%0d b=%0d y=%0d",
                       t.a, t.b, t.y), UVM_HIGH)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("일치 %0d / 불일치 %0d",
                   match_cnt, mismatch_cnt), UVM_NONE)
        if (match_cnt == 0)
            `uvm_error("SCB", "비교가 한 번도 수행되지 않았습니다")
    endfunction
endclass
"""),
        trap("비교 횟수 0 검사",
             "연결이 끊겼거나 모니터가 아무것도 못 잡으면 "
             "불일치가 0 이라 테스트가 PASS 로 끝납니다. "
             "report_phase 에서 '비교를 실제로 했는가'를 반드시 확인하세요."),

        h2("20.3  파이프라인 - 순서는 맞지만 지연이 있을 때"),
        code("pipelined_scb.sv", """
class pipe_scoreboard extends uvm_scoreboard;
    seq_item expect_q[$];

    // 입력 모니터에서
    virtual function void write_in(seq_item t);
        seq_item e;
        $cast(e, t.clone());
        e.y = predict(t.a, t.b);
        expect_q.push_back(e);
    endfunction

    // 출력 모니터에서
    virtual function void write_out(seq_item t);
        seq_item e;
        if (expect_q.size() == 0) begin
            `uvm_error("SCB", "기대값 없이 출력이 관측됨")
            return;
        end
        e = expect_q.pop_front();
        if (t.y !== e.y)
            `uvm_error("SCB", $sformatf("기대 %0d 실제 %0d", e.y, t.y))
    endfunction

    virtual function void check_phase(uvm_phase phase);
        if (expect_q.size() != 0)
            `uvm_error("SCB", $sformatf(
                "처리되지 않은 기대값 %0d개 남음", expect_q.size()))
    endfunction
endclass
"""),
        key("check_phase 를 반드시 쓰라",
            "큐에 남은 항목은 'DUT 가 응답하지 않은 트랜잭션'입니다. "
            "이것을 검사하지 않으면 DUT 가 마지막 몇 개를 삼켜도 "
            "테스트가 통과합니다."),

        h2("20.4  순서가 뒤바뀌는 경우"),
        p("태그 기반 프로토콜(AXI 등)은 응답 순서가 요청 순서와 다를 수 있습니다."),
        code("out_of_order.sv", """
class ooo_scoreboard extends uvm_scoreboard;
    seq_item expect_map[int];      // 연관배열: tag -> 기대값

    virtual function void write_in(seq_item t);
        seq_item e;
        $cast(e, t.clone());
        e.y = predict(t.a, t.b);
        if (expect_map.exists(t.tag))
            `uvm_error("SCB", $sformatf("태그 %0d 중복 발급", t.tag))
        expect_map[t.tag] = e;
    endfunction

    virtual function void write_out(seq_item t);
        seq_item e;
        if (!expect_map.exists(t.tag)) begin
            `uvm_error("SCB", $sformatf("알 수 없는 태그 %0d", t.tag))
            return;
        end
        e = expect_map[t.tag];
        expect_map.delete(t.tag);
        if (t.y !== e.y) `uvm_error("SCB", "...")
    endfunction
endclass
"""),
        table(["프로토콜 특성", "자료구조"],
              [["순서 보장 (in-order)", "큐 (queue)"],
               ["태그 기반 순서 바뀜", "연관배열 (tag -> 기대값)"],
               ["여러 채널 독립", "채널별 큐 배열"],
               ["집합 비교 (순서 무관)", "정렬 후 비교 또는 멀티셋"]],
              weights=[1.2, 1.3]),

        h2("20.5  진단 가능한 에러 메시지"),
        code("good_message.sv", """
// 나쁜 예: 무슨 일이 있었는지 알 수 없다
`uvm_error("SCB", "mismatch")

// 좋은 예: 재현에 필요한 정보가 다 있다
`uvm_error("SCB", $sformatf(
    "[#%0d @%0t] 불일치\\n"
    "  입력  a=%0d b=%0d\\n"
    "  기대  y=%0d (0x%03h)\\n"
    "  실제  y=%0d (0x%03h)\\n"
    "  차이  %0d",
    txn_id, $time, t.a, t.b, exp, exp, t.y, t.y,
    $signed(t.y) - $signed(exp)))
"""),
        ol("몇 번째 트랜잭션인가 (재현용 번호)",
           "언제 일어났는가 (파형에서 찾을 시각)",
           "입력이 무엇이었는가 (재현 조건)",
           "기대와 실제를 나란히 (10진과 16진 둘 다)",
           "차이가 얼마인가 (패턴 파악용)"),
        tip("차이값이 힌트가 된다",
            "차이가 항상 256의 배수면 폭 문제, 항상 1이면 오프바이원, "
            "부호가 반대면 signed/unsigned 문제입니다. "
            "차이를 찍어두면 원인 추정 시간이 크게 줄어듭니다."),

        h2("20.6  타이밍 윈도우가 있는 비교"),
        p("DUT 응답이 '3~10 클럭 안에 온다' 같은 경우입니다. "
          "정확한 시각을 모르므로 윈도우로 판정해야 합니다."),
        code("timing_window_scb.svh", """
class window_scoreboard extends uvm_scoreboard;
    typedef struct {
        seq_item item;
        time     deadline;
    } pending_t;

    pending_t pending[$];
    int unsigned max_latency = 10;      // 클럭 수

    virtual function void write_in(seq_item t);
        pending_t e;
        $cast(e.item, t.clone());
        e.item.y  = predict(t);
        e.deadline = $time + max_latency * CLK_PERIOD;
        pending.push_back(e);
    endfunction

    virtual function void write_out(seq_item t);
        foreach (pending[i]) begin
            if (pending[i].item.y === t.y) begin
                pending.delete(i);       // 짝을 찾았다
                n_match++;
                return;
            end
        end
        `uvm_error("SCB", $sformatf("짝을 찾을 수 없는 출력 y=%0d", t.y))
    endfunction

    // 주기적으로 시한 초과 검사
    virtual task run_phase(uvm_phase phase);
        forever begin
            #(CLK_PERIOD);
            while (pending.size() > 0 && pending[0].deadline < $time) begin
                `uvm_error("SCB", $sformatf(
                    "응답 시한 초과: 입력 a=%0d b=%0d 가 %0d클럭 내에 "
                    "응답하지 않음", pending[0].item.a,
                    pending[0].item.b, max_latency))
                void'(pending.pop_front());
            end
        end
    endtask
endclass
"""),
        trap("값으로만 짝짓기의 위험",
             "같은 값의 트랜잭션이 여러 개 미결이면 잘못 짝지어집니다. "
             "가능하면 태그나 ID 를 붙이세요. 없다면 "
             "'가장 오래된 것부터' 같은 규칙을 명시적으로 정해야 합니다."),

        h2("20.7  스코어보드 활성화 제어"),
        code("scb_enable.svh", """
class cfg_scoreboard extends uvm_scoreboard;
    bit enable_check = 1;
    bit enable_latency_check = 1;

    virtual function void write(seq_item t);
        if (!enable_check) return;         // 설정으로 끌 수 있게
        ...
    endfunction
endclass
"""),
        p("에러 주입 테스트나 초기화 구간처럼 비교가 무의미한 시기에 "
          "잠시 끄기 위한 장치입니다. 다만 끄는 구간을 로그에 남기세요."),
        code("scb_disable_log.sv", """
function void set_check(bit en);
    if (enable_check != en)
        `uvm_info("SCB", $sformatf("비교 %s @%0t",
                   en ? "활성" : "비활성", $time), UVM_LOW)
    enable_check = en;
endfunction
"""),
        warn("끈 채로 잊으면",
             "테스트가 전부 통과하는데 실제로는 아무것도 검사하지 않는 "
             "상태가 됩니다. report_phase 에서 비교 횟수를 확인하는 것이 "
             "이 사고를 막는 안전장치입니다."),

        h2("20.8  실습"),
        lab("과제 20-A",
            "가산기 스코어보드를 작성하고 DUT 의 출력 폭을 [7:0] 로 "
            "되돌려 스코어보드가 캐리 절단을 잡아내는지 확인하세요."),
        lab("과제 20-B",
            "check_phase 에 미처리 큐 검사를 넣고, 모니터를 일부러 "
            "비활성화해 에러가 나는지 확인하세요."),
        quiz("스코어보드가 입력을 드라이버가 아니라 모니터에서 받아야 하는 이유는?",
             ["① 성능이 좋아서",
              "② 드라이버 버그로 실제 인가된 값이 다를 수 있어서",
              "③ UVM 규칙이라서",
              "④ 드라이버는 analysis_port 가 없어서"],
             "② — 드라이버가 '보내려던 값'과 핀에 '실제 인가된 값'이 "
             "다를 수 있습니다. 실제 핀을 관측해야 드라이버 버그도 잡힙니다."),
    ],
}


# ==========================================================================
CH21 = {
    "number": "CHAPTER 21",
    "title": "검증 계획과 종료 조건",
    "goals": [
        "검증 계획서의 구성 요소를 안다",
        "기능을 커버리지 항목으로 번역한다",
        "언제 검증을 끝낼지 판단한다",
        "회귀 시험을 구성한다",
    ],
    "body": [
        lead("'버그가 안 나오면 끝'은 종료 조건이 아닙니다. "
             "무엇을 시험할지 미리 정하고, 그것을 다 봤는지 측정해야 "
             "끝났다고 말할 수 있습니다."),

        h2("21.1  검증 계획서"),
        table(["항목", "내용"],
              [["기능 목록", "스펙에서 뽑아낸 검증 대상 기능"],
               ["시험 시나리오", "각 기능을 어떻게 자극할 것인가"],
               ["커버리지 항목", "무엇을 측정해 '봤다'고 할 것인가"],
               ["체크 방법", "스코어보드 / assertion / 수동 검토"],
               ["종료 조건", "커버리지 목표, 회귀 통과율, 미해결 버그 수"]],
              weights=[0.9, 1.8]),

        h2("21.2  기능을 커버리지로 번역하기"),
        p("레지스터 DUT 를 예로 들어 봅니다."),
        code("spec_to_cov.txt", """
스펙 문장                          커버리지 항목
--------------------------------  -----------------------------
resetn=0 이면 q 는 0 이 된다       cp_reset: {active, released}
en=1 이면 다음 클럭에 q<=d         cp_en:    {0, 1}
en=0 이면 q 유지                   x_en_data: cross(en, d 구간)
d 는 32비트 전 범위                cp_d: 8개 구간 bins
리셋 중 en=1 은 무시된다           x_rst_en: cross(reset, en)
"""),
        key("체크와 커버리지는 다르다",
            "체크는 '틀렸는가'를 보고, 커버리지는 '봤는가'를 봅니다. "
            "체크만 있으면 안 본 경우를 모르고, "
            "커버리지만 있으면 틀린 것을 모릅니다. 둘 다 필요합니다."),

        h2("21.3  종료 조건의 예"),
        ol("기능 커버리지 100% (ignore_bins 제외)",
           "코드 커버리지 라인/브랜치 95% 이상, 미달 사유 문서화",
           "회귀 시험 500 시드 전부 통과",
           "모든 assertion 이 최소 1회 이상 non-vacuous 하게 성공",
           "미해결 심각도 1-2 버그 0건",
           "리뷰 완료 (검증 계획, 스코어보드 로직, 커버리지 모델)"),
        note("현실적인 목표",
             "코드 커버리지 100% 는 대개 불가능합니다. "
             "합성으로 제거되는 로직, 도달 불가능한 상태가 있기 때문입니다. "
             "중요한 것은 '미달 항목마다 이유를 설명할 수 있는가' 입니다.",
             "info"),

        h2("21.4  회귀 시험"),
        code("regression.sh", """
# 시드를 바꿔가며 반복 실행
for seed in $(seq 1 500); do
    xsim tb_snapshot -R -testplusarg "UVM_TESTNAME=random_test" \\
                        -sv_seed $seed \\
                        -log run_$seed.log
done

# 실패 수집
grep -l "UVM_ERROR :  *[1-9]" run_*.log
"""),
        p("같은 테스트라도 시드가 다르면 다른 자극이 생성됩니다. "
          "회귀는 그 다양성을 활용해 드문 조합을 찾습니다."),
        tip("실패 재현",
            "UVM 로그 첫머리에 시드가 찍힙니다. 실패한 시드를 그대로 "
            "다시 넣으면 동일하게 재현됩니다. "
            "재현 안 되는 실패는 테스트벤치의 경쟁 조건을 의심하세요."),

        h2("21.5  커버리지 수렴 곡선"),
        art("""
   커버리지
    100% |                    _________________
         |                _.-'
     80% |            _.-'
         |         .-'
     60% |      .-'
         |    ,'
     40% |  ,'
         | /
     20% |/
         +---------------------------------------> 시뮬레이션 횟수
         0   100   1K    10K   100K

   초반은 빠르게 오르고 후반은 정체한다.
   정체 구간에서 랜덤을 더 돌리는 것은 낭비.
   -> 제약을 조정하거나 방향 자극(directed test)을 추가한다.
"""),
        key("정체를 만나면",
            "랜덤 횟수를 늘리는 것이 아니라 자극의 분포를 바꿔야 합니다. "
            "안 채워진 bin 을 보고 그 영역을 겨냥한 제약이나 "
            "방향 테스트를 추가하는 것이 정석입니다."),

        h2("21.6  검증 계획서 템플릿"),
        p("레지스터 DUT 를 예로 실제 형태를 보입니다. "
          "과제 제출용으로 그대로 써도 됩니다."),
        code("verification_plan.md", """
# 검증 계획서 - uvm_register

## 1. 대상
  DUT      : uvm_register (32비트 동기 로드 레지스터)
  인터페이스: clk, resetn(비동기 active-low), en, d[31:0], q[31:0]
  참조 문서 : spec_register_v1.2.pdf

## 2. 기능 목록과 검증 항목

  F1. 비동기 리셋
      동작   : resetn=0 이면 clk 무관하게 q <- 0
      자극   : 랜덤 시점에 resetn 인가
      체크   : a_reset (SVA), 스코어보드 모델 초기화
      커버리지: cp_reset {active, released}
                x_rst_en cross(reset, en)   <- 리셋 중 en=1

  F2. 동기 로드
      동작   : en=1 이면 다음 posedge clk 에 q <- d
      자극   : en dist{1:=70, 0:=30}, d 는 전 범위 랜덤
      체크   : a_load (SVA), 스코어보드 비교
      커버리지: cp_en{0,1}, cp_d 8구간, x_en_d cross

  F3. 유지
      동작   : en=0 이면 q 값 유지
      자극   : hold_sequence (en=0 을 10회 연속)
      체크   : a_hold (SVA), 스코어보드 상태 모델
      커버리지: cp_hold_len {1, 2, [3:10]}

  F4. 데이터 경계값
      동작   : d 가 0, 최대값, 모든 비트 패턴에서 정상 동작
      자극   : corner_sequence (0, 1, 0xAAAA_AAAA, 0x5555_5555, 0xFFFF_FFFF)
      체크   : 스코어보드 비교
      커버리지: cp_d 에 zero, max, alt 패턴 bin

  F5. X 전파 없음
      동작   : 리셋 해제 후 q 에 X 가 없어야 함
      자극   : 모든 테스트
      체크   : a_no_x (SVA), $isunknown

## 3. 테스트 목록

  | 테스트         | 시퀀스              | 목적                |
  |----------------|---------------------|---------------------|
  | random_test    | reg_sequence        | 전반적 랜덤 검증    |
  | hold_test      | hold_sequence       | F3 집중             |
  | corner_test    | corner_sequence     | F4 집중             |
  | reset_test     | reset_stress_seq    | F1 집중             |
  | err_test       | reg_sequence + override | 에러 주입 검증  |

## 4. 종료 조건

  - 기능 커버리지 100% (ignore_bins 제외, 사유 문서화)
  - 코드 커버리지 라인/브랜치 95% 이상
  - 회귀 100 시드 전부 통과
  - 모든 assertion 이 non-vacuous 하게 1회 이상 성공
  - mutation test 5종 전부 검출

## 5. 위험 요소

  - 비동기 리셋과 클럭 엣지가 겹치는 경우: 시뮬레이션으로 완전 검증 불가.
    별도로 STA/CDC 검토 필요
"""),
        key("계획서가 곧 커버리지 모델",
            "기능 목록의 '커버리지' 열이 그대로 covergroup 이 됩니다. "
            "계획서를 먼저 쓰면 커버리지 모델을 따로 고민할 필요가 "
            "없습니다."),

        h2("21.7  커버리지 병합과 해석"),
        p("회귀 500회를 돌리면 커버리지 DB 가 500개 나옵니다. "
          "이를 합쳐야 전체 그림이 보입니다."),
        code("coverage_merge.sh", """
# Vivado
xcrg -merge_dir ./cov_db_all -dir ./cov_db_run1 -dir ./cov_db_run2 ...
xcrg -report_format html -dir ./cov_db_all -report_dir ./report

# 실무에서는 보통 와일드카드로
xcrg -merge_dir ./merged $(ls -d cov_db_*/ | sed 's/^/-dir /')
"""),
        table(["리포트에서 볼 것", "의미"],
              [["전체 % 만 본다", "가장 흔한 실수. 아무것도 알 수 없음"],
               ["미달 bin 목록", "여기가 진짜 정보"],
               ["시드별 기여도", "어떤 테스트가 새 bin 을 여는가"],
               ["수렴 곡선", "언제부터 랜덤이 무의미해지는가"],
               ["illegal_bins 적중", "자극 생성 버그의 증거"]],
              weights=[1.2, 1.5]),
        code("coverage_analysis.txt", """
전형적인 진행

  시드   1 : 42%   (첫 실행이 절반 가까이 채움)
  시드  10 : 71%
  시드  50 : 88%
  시드 100 : 91%
  시드 300 : 92%   <- 여기서 정체
  시드 500 : 92%

  -> 300회 이후 400회는 낭비.
     미달 8% 의 bin 목록을 보고 방향 테스트를 만드는 것이
     시드 1000회보다 효율적이다.
"""),
        tip("새 bin 을 여는 시드를 기록하라",
            "회귀에서 커버리지를 올린 시드만 따로 모아두면 "
            "'최소 회귀 세트'가 됩니다. 매일 도는 스모크 회귀에 "
            "그 시드들을 쓰면 짧은 시간에 넓은 영역을 확인할 수 있습니다."),

        h2("21.8  실습"),
        lab("과제 21-A",
            "레지스터 DUT 의 검증 계획서를 작성하세요. "
            "기능 5개 이상, 각각에 대응하는 커버리지 항목과 체크 방법을 "
            "표로 정리하면 됩니다."),
        lab("과제 21-B",
            "시드 20개로 회귀를 돌리고 커버리지 수렴 곡선을 그리세요."),
        quiz("기능 커버리지 100%, 코드 커버리지 70% 인 상태의 해석은?",
             ["① 검증 완료",
              "② 계획한 기능은 다 봤지만 RTL 에 시험되지 않은 코드가 있다",
              "③ 커버리지 모델이 잘못됐다",
              "④ 코드 커버리지는 무시해도 된다"],
             "② — 검증 계획에 없던 기능이 RTL 에 있거나, 죽은 코드이거나, "
             "예외 처리 경로일 수 있습니다. 미실행 코드를 하나씩 확인해 "
             "계획을 보완하거나 코드를 제거해야 합니다."),
    ],
}


CHAPTERS = [CH16, CH17, CH18, CH19, CH20, CH21]
