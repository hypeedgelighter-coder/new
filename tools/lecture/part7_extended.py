"""Part VII - 확장 주제 (FSM / 파일 IO / 버스 프로토콜 / 시퀀스 심화 / FIFO 실습)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART VII",
    "title": "확장 주제",
    "blurb": "본 과정의 뼈대를 벗어나지만 실습과 실무에서 반드시 마주치는 "
             "주제들입니다. 상태 기계 검증, 파일 기반 자극, 표준 버스 "
             "프로토콜, 시퀀스 고급 제어, 그리고 난이도를 한 단계 올린 "
             "FIFO 실습을 다룹니다.",
    "items": [
        "46장 FSM 설계와 검증",
        "47장 파일 입출력과 자극 생성",
        "48장 표준 버스 프로토콜 개요",
        "49장 시퀀스 고급 제어",
        "50장 실습 5 - FIFO UVM 환경",
        "51장 형식 검증 입문",
    ],
}


# ==========================================================================
CH46 = {
    "number": "CHAPTER 46",
    "title": "FSM 설계와 검증",
    "goals": [
        "FSM 을 표준 형태로 기술한다",
        "상태 인코딩을 선택한다",
        "FSM 커버리지를 정의한다",
        "전이 규칙을 assertion 으로 옮긴다",
    ],
    "body": [
        lead("상태 기계는 디지털 설계의 기본 구조이면서 버그가 가장 잘 "
             "숨는 곳이기도 합니다. 도달 불가능한 상태, 빠진 전이, "
             "잘못된 우선순위가 전형적인 결함입니다."),

        h2("46.1  3-프로세스 형태"),
        p("상태 레지스터, 다음 상태 논리, 출력 논리를 분리하는 것이 "
          "가장 읽기 쉽고 합성 결과도 예측 가능합니다."),
        code("fsm_3process.sv", """
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    CALC  = 2'b10,
    DONE  = 2'b11
} state_t;

module fsm (
    input  logic clk, rstn, start, ready,
    output logic busy, valid
);
    state_t state, next;

    // (1) 상태 레지스터
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) state <= IDLE;
        else       state <= next;
    end

    // (2) 다음 상태 논리
    always_comb begin
        next = state;                  // 기본값: 유지 (래치 방지)
        unique case (state)
            IDLE : if (start) next = LOAD;
            LOAD :            next = CALC;
            CALC : if (ready) next = DONE;
            DONE :            next = IDLE;
        endcase
    end

    // (3) 출력 논리 (Moore)
    always_comb begin
        busy  = (state != IDLE);
        valid = (state == DONE);
    end
endmodule
"""),
        key("next = state; 를 먼저 쓰는 이유",
            "모든 분기에서 next 에 값이 할당되지 않으면 래치가 추론됩니다. "
            "맨 앞에 기본값을 두면 어떤 경로로 빠져도 안전합니다. "
            "case 에 default 를 두는 것과 같은 효과이고, 이쪽이 더 명시적입니다."),
        table(["형태", "출력이 의존하는 것", "특징"],
              [["Moore", "현재 상태만", "출력이 클럭에 정렬, 지연 1클럭"],
               ["Mealy", "현재 상태 + 입력", "빠르지만 글리치 가능"]],
              weights=[0.8, 1.2, 1.4]),

        h2("46.2  unique / priority"),
        code("unique_priority.sv", """
unique case (state)      // 중복 조건이 있으면 런타임 경고
    ...
endcase

priority case (sel)      // 위에서부터 우선순위, 하나는 반드시 맞아야 함
    ...
endcase
"""),
        table(["한정자", "검사하는 것"],
              [["unique", "조건이 정확히 하나만 맞는가 (중복/누락 모두 경고)"],
               ["unique0", "0개 또는 1개 (누락은 허용)"],
               ["priority", "적어도 하나는 맞는가 (순서대로 평가)"],
               ["(없음)", "검사 없음"]],
              weights=[0.9, 1.9]),
        tip("unique 를 습관으로",
            "상태 기계에서 두 조건이 동시에 참이 되는 버그는 "
            "파형만 봐서는 찾기 어렵습니다. unique 를 붙이면 "
            "시뮬레이터가 그 순간 경고를 냅니다."),

        h2("46.3  상태 인코딩"),
        table(["인코딩", "비트 수 (N상태)", "특징"],
              [["binary", "ceil(log2 N)", "면적 최소, 디코딩 논리 큼"],
               ["gray", "ceil(log2 N)", "인접 전이 시 1비트만 변화. CDC 유리"],
               ["one-hot", "N", "디코딩 단순, FF 많음. FPGA 에 유리"]],
              weights=[0.9, 1.1, 1.7]),
        code("encoding.sv", """
// 명시적 지정
typedef enum logic [3:0] {
    IDLE = 4'b0001,
    LOAD = 4'b0010,
    CALC = 4'b0100,
    DONE = 4'b1000
} state_t;      // one-hot

// 합성 지시자 (도구별)
(* fsm_encoding = "one_hot" *) state_t state;
"""),
        note("FPGA 에서는 one-hot 이 기본",
             "FF 는 남아돌고 LUT 는 아까운 구조라 one-hot 이 유리합니다. "
             "Vivado 는 상태 수에 따라 자동으로 고르지만, "
             "명시적으로 지정하는 편이 예측 가능합니다.",
             "info"),

        h2("46.4  FSM 커버리지"),
        code("fsm_coverage.sv", """
covergroup fsm_cg @(posedge clk);
    option.per_instance = 1;

    cp_state : coverpoint state {
        bins all_states[] = {IDLE, LOAD, CALC, DONE};
    }

    cp_trans : coverpoint state {
        // 정상 전이
        bins t_idle_load = (IDLE => LOAD);
        bins t_load_calc = (LOAD => CALC);
        bins t_calc_done = (CALC => DONE);
        bins t_done_idle = (DONE => IDLE);

        // 대기 (자기 자신으로)
        bins t_idle_wait = (IDLE => IDLE);
        bins t_calc_wait = (CALC => CALC);

        // 일어나면 안 되는 전이
        illegal_bins bad = (IDLE => CALC), (IDLE => DONE),
                           (LOAD => DONE), (LOAD => IDLE);
    }

    // 전체 시퀀스를 한 번은 돌았는가
    cp_full : coverpoint state {
        bins full_cycle = (IDLE => LOAD => CALC => DONE => IDLE);
    }
endgroup
"""),
        key("상태보다 전이가 중요하다",
            "모든 상태를 방문해도 특정 전이는 한 번도 안 일어났을 수 "
            "있습니다. 버그는 전이에 숨습니다. "
            "cp_state 는 100% 인데 cp_trans 가 60% 인 경우가 흔합니다."),

        h2("46.5  FSM assertion"),
        code("fsm_sva.sv", """
// 상태는 항상 정의된 값이어야
a_valid_state : assert property (
    @(posedge clk) disable iff (!rstn)
    state inside {IDLE, LOAD, CALC, DONE}
) else $error("정의되지 않은 상태 %0d", state);

// one-hot 인코딩이면
a_onehot : assert property (
    @(posedge clk) disable iff (!rstn) $onehot(state)
) else $error("one-hot 위반");

// start 가 들어오면 반드시 LOAD 로
a_start : assert property (
    @(posedge clk) disable iff (!rstn)
    (state == IDLE && start) |=> (state == LOAD)
) else $error("start 무시됨");

// DONE 은 정확히 1클럭만 유지
a_done_1cyc : assert property (
    @(posedge clk) disable iff (!rstn)
    (state == DONE) |=> (state != DONE)
) else $error("DONE 이 2클럭 이상 유지");

// 데드락 방지: CALC 에서 최대 100클럭 안에 빠져나옴
a_no_hang : assert property (
    @(posedge clk) disable iff (!rstn)
    (state == CALC) |-> ##[1:100] (state != CALC)
) else $error("CALC 에서 데드락");
"""),
        tip("데드락 assertion 을 꼭 넣어라",
            "상태 기계 버그 중 가장 찾기 어려운 것이 '어떤 상태에서 "
            "영원히 못 나오는' 경우입니다. 상한을 둔 assertion 이 "
            "그것을 바로 잡아냅니다."),

        h2("46.6  UVM 환경에서 FSM 관측"),
        code("fsm_monitor.svh", """
// 모니터가 상태를 함께 보고
class fsm_monitor extends uvm_monitor;
    virtual fsm_if vif;
    uvm_analysis_port #(fsm_item) ap;

    virtual task run_phase(uvm_phase phase);
        state_t prev = IDLE;
        forever begin
            @(posedge vif.clk);
            if (vif.state !== prev) begin
                fsm_item it = fsm_item::type_id::create("it");
                it.from = prev;
                it.to   = vif.state;
                ap.write(it);
                `uvm_info("FSM", $sformatf("%s -> %s",
                           prev.name(), vif.state.name()), UVM_HIGH)
                prev = vif.state;
            end
        end
    endtask
endclass
"""),
        note("enum 의 name()",
             "로그에 2'b01 대신 LOAD 가 찍힙니다. "
             "상태 기계 디버깅 속도가 눈에 띄게 달라집니다.",
             "tip"),

        h2("46.7  실습"),
        lab("과제 46-A",
            "위 4상태 FSM 을 작성하고 전이 커버리지를 100% 로 만드는 "
            "자극을 설계하세요."),
        lab("과제 46-B",
            "CALC 에서 ready 가 영원히 0인 경우를 만들어 "
            "a_no_hang assertion 이 잡아내는지 확인하세요."),
        quiz("always_comb 안 case 문에서 next 에 기본값을 안 주면?",
             ["① 컴파일 에러", "② 래치가 추론되어 always_comb 가 경고",
              "③ 상태가 IDLE 로 간다", "④ 아무 문제 없다"],
             "② — 모든 경로에서 값이 할당되지 않으면 래치입니다. "
             "always_comb 는 이를 감지해 경고합니다."),
    ],
}


# ==========================================================================
CH47 = {
    "number": "CHAPTER 47",
    "title": "파일 입출력과 자극 생성",
    "goals": [
        "파일에서 자극을 읽어 인가한다",
        "결과를 파일로 기록한다",
        "메모리 초기화 파일을 다룬다",
        "파일 기반 회귀를 구성한다",
    ],
    "body": [
        lead("설계팀이 준 테스트 벡터, 소프트웨어 팀이 만든 펌웨어 이미지, "
             "이전 회귀에서 실패한 자극 목록. 파일에서 읽어야 하는 상황은 "
             "생각보다 자주 옵니다."),

        h2("47.1  파일 읽기"),
        code("file_read.sv", """
int fd;
int a, b, expected;
string line;

initial begin
    fd = $fopen("vectors.txt", "r");
    if (fd == 0) begin
        `uvm_fatal("FILE", "vectors.txt 를 열 수 없습니다")
    end

    while (!$feof(fd)) begin
        if ($fscanf(fd, "%d %d %d\\n", a, b, expected) == 3) begin
            drive(a, b);
            check(expected);
        end
    end
    $fclose(fd);
end
"""),
        code("vectors.txt", """
# 주석은 별도 처리 필요
10  20  30
200 100 300
255 255 510
0   0   0
"""),
        table(["함수", "용도"],
              [["$fopen(name, mode)", "열기. 실패하면 0 반환"],
               ["$fclose(fd)", "닫기"],
               ["$fscanf(fd, fmt, args)", "형식 읽기. 읽은 항목 수 반환"],
               ["$fgets(str, fd)", "한 줄 읽기"],
               ["$feof(fd)", "파일 끝인가"],
               ["$sscanf(str, fmt, args)", "문자열에서 파싱"],
               ["$fdisplay(fd, fmt, args)", "파일에 쓰기"],
               ["$fwrite(fd, ...)", "개행 없이 쓰기"]],
              weights=[1.4, 1.4]),
        trap("$fopen 결과를 반드시 검사하라",
             "파일이 없어도 시뮬레이션은 계속 돕니다. "
             "fd 가 0인 채로 $fscanf 를 부르면 아무 일도 안 일어나고 "
             "'자극이 안 나간다'로 몇 시간을 보내게 됩니다."),

        h2("47.2  UVM 시퀀스에서 파일 읽기"),
        code("file_sequence.svh", """
class file_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(file_sequence)

    string filename = "vectors.txt";

    function new(string name = "file_sequence");
        super.new(name);
    endfunction

    virtual task body();
        int fd, a, b, n_read, count;
        seq_item item;

        // 파일 이름을 명령행에서 받을 수도 있다
        void'($value$plusargs("VECFILE=%s", filename));

        fd = $fopen(filename, "r");
        if (fd == 0) begin
            `uvm_fatal("FILE", {"열 수 없음: ", filename})
        end

        while (!$feof(fd)) begin
            n_read = $fscanf(fd, "%d %d\\n", a, b);
            if (n_read != 2) continue;         // 빈 줄, 주석 건너뜀

            item = seq_item::type_id::create("item");
            start_item(item);
            item.a = a[7:0];
            item.b = b[7:0];
            finish_item(item);
            count++;
        end
        $fclose(fd);

        `uvm_info("SEQ", $sformatf("%0d개 벡터 인가 완료", count), UVM_LOW)
    endtask
endclass
"""),
        tip("파일 이름을 명령행에서",
            "+VECFILE=corner.txt 처럼 넘기면 재컴파일 없이 "
            "다른 벡터 세트를 돌릴 수 있습니다. "
            "회귀 스크립트에서 특히 유용합니다."),

        h2("47.3  결과 기록"),
        code("file_write.sv", """
class csv_logger extends uvm_subscriber #(seq_item);
    `uvm_component_utils(csv_logger)
    int fd;

    virtual function void start_of_simulation_phase(uvm_phase phase);
        fd = $fopen("results.csv", "w");
        $fdisplay(fd, "time,a,b,y,expected,pass");
    endfunction

    virtual function void write(seq_item t);
        bit [8:0] exp = t.a + t.b;
        $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d,%0d",
                  $time, t.a, t.b, t.y, exp, (t.y === exp));
    endfunction

    virtual function void final_phase(uvm_phase phase);
        $fclose(fd);
    endfunction
endclass
"""),
        p("CSV 로 남기면 엑셀이나 파이썬으로 후처리할 수 있습니다. "
          "커버리지 수렴 곡선이나 실패 패턴 분석에 유용합니다."),

        h2("47.4  메모리 초기화"),
        code("readmem.sv", """
logic [31:0] mem [0:1023];

initial begin
    $readmemh("firmware.hex", mem);          // 16진
    // $readmemb("pattern.bin", mem);        // 2진
    // 범위 지정
    // $readmemh("boot.hex", mem, 0, 255);
end
"""),
        code("firmware.hex", """
// @ 로 주소 지정 가능
@00000000
DEADBEEF
CAFEBABE
12345678
@00000100
AAAA5555
"""),
        warn("$readmemh 의 조용한 실패",
             "파일이 없으면 경고만 내고 계속 진행합니다. "
             "메모리가 전부 X 인 채로 시뮬레이션이 돌아 "
             "원인 파악이 어려워집니다. 읽은 뒤 첫 워드를 확인하세요."),
        code("readmem_check.sv", """
initial begin
    $readmemh("firmware.hex", mem);
    if ($isunknown(mem[0]))
        `uvm_fatal("MEM", "firmware.hex 로드 실패")
end
"""),

        h2("47.5  실패 자극 재현 파일"),
        p("회귀에서 실패한 자극만 모아 다시 돌리는 패턴입니다."),
        code("replay_flow.txt", """
1) 정상 회귀 실행
   -> 모든 트랜잭션을 CSV 로 기록

2) 실패 로그에서 트랜잭션 번호 추출
   grep "UVM_ERROR" run.log | grep -o "#[0-9]*"

3) 해당 번호의 자극만 뽑아 replay.txt 생성
   awk -F, 'NR==1 || $1==123 || $1==456' results.csv > replay.txt

4) file_sequence 로 재현
   xsim tb -R +UVM_TESTNAME=file_test +VECFILE=replay.txt
"""),
        key("재현 가능성이 디버깅의 전부",
            "'가끔 실패한다'를 '항상 실패한다'로 바꾸면 "
            "디버깅 난이도가 완전히 달라집니다. "
            "시드 고정과 자극 기록이 그 수단입니다."),

        h2("47.6  실습"),
        lab("과제 47-A",
            "가산기 환경에 file_sequence 를 추가하고 "
            "10개 코너 케이스를 담은 벡터 파일로 실행하세요."),
        lab("과제 47-B",
            "csv_logger 를 추가해 모든 트랜잭션을 기록하고, "
            "엑셀에서 열어 실패 항목을 필터링하세요."),
        quiz("$fopen 이 반환한 fd 가 0이면?",
             ["① 파일이 비어 있다", "② 열기에 실패했다",
              "③ 첫 번째 파일이다", "④ 읽기 전용이다"],
             "② — 0은 실패입니다. 성공하면 0이 아닌 핸들이 나옵니다. "
             "반드시 검사하세요."),
    ],
}


# ==========================================================================
CH48 = {
    "number": "CHAPTER 48",
    "title": "표준 버스 프로토콜 개요",
    "goals": [
        "APB 트랜잭션을 이해한다",
        "AXI 채널 구조를 파악한다",
        "핸드셰이크 규칙을 검증한다",
        "프로토콜 VIP 의 구조를 예상한다",
    ],
    "body": [
        lead("실무 검증의 대부분은 표준 버스 프로토콜을 다룹니다. "
             "가산기와 레지스터로 배운 구조가 어떻게 확장되는지 "
             "APB 와 AXI 를 예로 봅니다."),

        h2("48.1  APB - 가장 단순한 버스"),
        art("""
   APB 쓰기 트랜잭션 (3상태)

   clk     _|~|_|~|_|~|_|~|_

   PSEL    ___|~~~~~~~|_____
   PENABLE _______|~~~|_____
   PWRITE  ___|~~~~~~~|_____
   PADDR   ---<  A   >------
   PWDATA  ---<  D   >------
   PREADY  _______|~~~|_____

           IDLE  SETUP ACCESS  IDLE
"""),
        table(["신호", "방향", "의미"],
              [["PSEL", "M->S", "이 슬레이브 선택"],
               ["PENABLE", "M->S", "ACCESS 단계 표시"],
               ["PADDR", "M->S", "주소"],
               ["PWRITE", "M->S", "1=쓰기, 0=읽기"],
               ["PWDATA", "M->S", "쓰기 데이터"],
               ["PRDATA", "S->M", "읽기 데이터"],
               ["PREADY", "S->M", "슬레이브 준비 완료"],
               ["PSLVERR", "S->M", "에러 응답"]],
              weights=[0.9, 0.8, 1.6]),
        code("apb_driver.svh", """
task drive_apb(apb_item item);
    // SETUP 단계
    @(vif.cb);
    vif.cb.psel    <= 1'b1;
    vif.cb.penable <= 1'b0;
    vif.cb.paddr   <= item.addr;
    vif.cb.pwrite  <= item.we;
    vif.cb.pwdata  <= item.data;

    // ACCESS 단계
    @(vif.cb);
    vif.cb.penable <= 1'b1;

    // PREADY 대기
    do @(vif.cb); while (vif.cb.pready !== 1'b1);

    if (!item.we) item.data = vif.cb.prdata;
    item.err = vif.cb.pslverr;

    // IDLE 복귀
    vif.cb.psel    <= 1'b0;
    vif.cb.penable <= 1'b0;
endtask
"""),
        code("apb_sva.sv", """
// PENABLE 은 PSEL 다음 클럭에 올라간다
a_setup : assert property (
    @(posedge clk) disable iff (!rstn)
    $rose(psel) |=> penable
);

// ACCESS 중에는 주소와 데이터가 안정
a_stable : assert property (
    @(posedge clk) disable iff (!rstn)
    (psel && penable && !pready) |=> $stable(paddr) && $stable(pwdata)
);
"""),
        key("APB 로 시작하라",
            "채널이 하나이고 파이프라인이 없어 가장 단순합니다. "
            "APB VIP 를 직접 만들어 보면 프로토콜 VIP 의 구조가 "
            "전부 이해됩니다."),

        h2("48.2  AXI - 5채널 구조"),
        art("""
   AXI4 의 5개 독립 채널

   Master                          Slave
     |                               |
     |--- AW (Write Address) ------->|
     |--- W  (Write Data) ---------->|
     |<-- B  (Write Response) -------|
     |                               |
     |--- AR (Read Address) -------->|
     |<-- R  (Read Data) ------------|

   각 채널은 VALID/READY 핸드셰이크로 독립 동작
"""),
        table(["채널", "주요 신호", "역할"],
              [["AW", "AWADDR, AWLEN, AWSIZE, AWBURST", "쓰기 주소/버스트 정보"],
               ["W", "WDATA, WSTRB, WLAST", "쓰기 데이터"],
               ["B", "BRESP, BID", "쓰기 응답"],
               ["AR", "ARADDR, ARLEN, ARSIZE, ARBURST", "읽기 주소/버스트"],
               ["R", "RDATA, RRESP, RLAST, RID", "읽기 데이터/응답"]],
              weights=[0.6, 1.8, 1.4]),
        code("axi_handshake_sva.sv", """
// VALID 는 READY 를 기다리는 동안 내려가면 안 된다
a_valid_stable : assert property (
    @(posedge clk) disable iff (!rstn)
    (awvalid && !awready) |=> awvalid
) else $error("AWVALID 가 READY 전에 내려감");

// VALID 중에는 페이로드가 안정
a_payload_stable : assert property (
    @(posedge clk) disable iff (!rstn)
    (awvalid && !awready) |=> $stable(awaddr) && $stable(awlen)
);

// WLAST 는 버스트의 마지막에만
a_wlast : assert property (
    @(posedge clk) disable iff (!rstn)
    (wvalid && wready && wlast) |-> (beat_count == expected_len)
);
"""),
        trap("AXI 검증의 난이도",
             "채널이 독립적이므로 순서가 뒤바뀝니다. "
             "AW 와 W 가 어느 순서로 와도 되고, ID 가 다르면 "
             "응답 순서도 바뀝니다. 스코어보드에 연관배열이 "
             "필요한 대표적 경우입니다 (20장 참고)."),

        h2("48.3  프로토콜 VIP 의 구조"),
        art("""
   APB VIP                        AXI VIP

   apb_if                         axi_if
   apb_item                       axi_item (AW/W/B/AR/R 통합)
   apb_driver                     axi_master_driver
   apb_monitor                    axi_monitor (채널별 관측 fork)
   apb_agent                      axi_master_agent
                                  axi_slave_agent (응답 생성)
   apb_seq_lib                    axi_seq_lib
   apb_coverage                   axi_coverage
                                  axi_protocol_checker (SVA 모음)
"""),
        p("구조는 같습니다. 채널이 늘어나면 모니터가 채널별로 "
          "fork 를 돌리고, 트랜잭션을 재조립하는 로직이 붙습니다."),
        code("axi_monitor_fork.svh", """
virtual task run_phase(uvm_phase phase);
    fork
        collect_aw();     // 각 채널을 독립적으로 관측
        collect_w();
        collect_b();
        collect_ar();
        collect_r();
        assemble();       // 채널 정보를 트랜잭션으로 재조립
    join
endtask
"""),

        h2("48.4  프로토콜 체커"),
        p("프로토콜 규칙만 모은 별도 모듈을 만들어 interface 에 "
          "bind 하는 것이 실무 패턴입니다."),
        code("bind_checker.sv", """
// 체커 모듈
module axi_protocol_checker (
    input logic clk, rstn,
    input logic awvalid, awready,
    input logic [31:0] awaddr
    // ...
);
    a_valid_stable : assert property (...);
    a_payload_stable : assert property (...);
    // ... 수십 개의 규칙
endmodule

// DUT 를 수정하지 않고 붙인다
bind axi_slave axi_protocol_checker chk (
    .clk(clk), .rstn(rstn),
    .awvalid(awvalid), .awready(awready), .awaddr(awaddr)
);
"""),
        key("bind 의 가치",
            "DUT 파일을 한 글자도 안 고치고 검사를 추가할 수 있습니다. "
            "설계팀과 검증팀이 파일을 공유하는 상황에서 "
            "충돌 없이 검증을 붙이는 표준 방법입니다."),

        h2("48.5  실습"),
        lab("과제 48-A",
            "APB 슬레이브(레지스터 4개)를 설계하고 APB VIP 를 만들어 "
            "읽기/쓰기를 검증하세요. 33장의 구조를 그대로 확장하면 됩니다."),
        lab("과제 48-B",
            "위 APB 인터페이스에 프로토콜 체커 모듈을 만들어 "
            "bind 로 붙이세요."),
        quiz("AXI 스코어보드에 연관배열이 필요한 이유는?",
             ["① 성능", "② ID 기반으로 응답 순서가 바뀔 수 있어서",
              "③ 주소 공간이 넓어서", "④ 채널이 5개라서"],
             "② — 순서가 보장되면 큐로 충분합니다. "
             "AXI 는 ID 별로 응답이 재배열될 수 있어 tag->기대값 매핑이 "
             "필요합니다."),
    ],
}


# ==========================================================================
CH49 = {
    "number": "CHAPTER 49",
    "title": "시퀀스 고급 제어",
    "goals": [
        "sequencer 를 독점한다 (grab/lock)",
        "인터럽트 시퀀스를 구현한다",
        "우선순위 기반 중재를 설정한다",
        "시퀀스 라이브러리를 구성한다",
    ],
    "body": [
        lead("여러 시퀀스가 하나의 sequencer 를 공유하면 순서 문제가 "
             "생깁니다. UVM 은 이를 제어하는 여러 장치를 제공합니다."),

        h2("49.1  동시 실행과 중재"),
        code("concurrent_seq.sv", """
// 두 시퀀스를 동시에 시작
fork
    seq_a.start(seqr);
    seq_b.start(seqr);
join
"""),
        p("이때 두 시퀀스의 아이템이 섞입니다. sequencer 의 중재 정책이 "
          "순서를 정합니다."),
        table(["정책", "동작"],
              [["UVM_SEQ_ARB_FIFO", "도착 순서 (기본값)"],
               ["UVM_SEQ_ARB_WEIGHTED", "우선순위 가중 무작위"],
               ["UVM_SEQ_ARB_RANDOM", "완전 무작위"],
               ["UVM_SEQ_ARB_STRICT_FIFO", "우선순위 우선, 같으면 FIFO"],
               ["UVM_SEQ_ARB_STRICT_RANDOM", "우선순위 우선, 같으면 무작위"],
               ["UVM_SEQ_ARB_USER", "user_priority_arbitration() 오버라이드"]],
              weights=[1.4, 1.4]),
        code("arbitration_setup.sv", """
// 중재 정책 설정
seqr.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);

// 우선순위를 주며 시작 (기본 100, 클수록 높음)
fork
    high_seq.start(seqr, null, 500);
    low_seq .start(seqr, null, 100);
join
"""),
        code("user_arbitration.svh", """
class my_sequencer extends uvm_sequencer #(seq_item);
    `uvm_component_utils(my_sequencer)

    // 사용자 정의 중재
    virtual function integer user_priority_arbitration(
                                        integer avail_sequences[$]);
        // 예: 항상 마지막에 도착한 것을 우선
        return avail_sequences[avail_sequences.size()-1];
    endfunction
endclass
"""),

        h2("49.2  grab 과 lock - 독점 접근"),
        p("한 시퀀스가 sequencer 를 독점해 다른 시퀀스가 끼어들지 "
          "못하게 합니다. 원자적으로 처리해야 하는 시퀀스에 씁니다."),
        code("grab_lock.sv", """
virtual task body();
    // 즉시 독점 (진행 중인 아이템 끝나면 바로)
    grab(m_sequencer);
    send_critical_sequence();
    ungrab(m_sequencer);

    // 순서를 기다렸다가 독점
    lock(m_sequencer);
    send_atomic_sequence();
    unlock(m_sequencer);
endtask
"""),
        table(["메서드", "차이"],
              [["grab / ungrab", "대기 중인 다른 시퀀스를 제치고 즉시 독점"],
               ["lock / unlock", "중재 큐에서 자기 차례를 기다린 뒤 독점"]],
              weights=[1.0, 2.0]),
        trap("ungrab 을 빼먹으면",
             "다른 시퀀스가 영원히 아이템을 못 보냅니다. "
             "시뮬레이션이 멈춘 것처럼 보이고, objection 이 안 내려가 "
             "타임아웃까지 갑니다."),

        h2("49.3  인터럽트 시퀀스"),
        p("정상 트래픽이 흐르는 도중 인터럽트가 발생하면 "
          "그것을 우선 처리하는 패턴입니다."),
        code("interrupt_seq.svh", """
class isr_sequence extends uvm_sequence #(bus_item);
    `uvm_object_utils(isr_sequence)

    virtual task body();
        grab(m_sequencer);              // 즉시 독점

        `uvm_info("ISR", "인터럽트 처리 시작", UVM_LOW)
        read_status_register();
        clear_interrupt();

        ungrab(m_sequencer);
    endtask
endclass

class main_test extends base_test;
    virtual task run_phase(uvm_phase phase);
        traffic_sequence traffic;
        isr_sequence     isr;

        phase.raise_objection(this);
        fork
            // 정상 트래픽
            traffic.start(env.agt.seqr);

            // 인터럽트 감시
            forever begin
                @(posedge env.vif.irq);
                isr = isr_sequence::type_id::create("isr");
                isr.start(env.agt.seqr);
            end
        join_any
        disable fork;
        phase.drop_objection(this);
    endtask
endclass
"""),

        h2("49.4  시퀀스 라이브러리"),
        code("seq_library.svh", """
class my_seq_lib extends uvm_sequence_library #(seq_item);
    `uvm_object_utils(my_seq_lib)
    `uvm_sequence_library_utils(my_seq_lib)

    function new(string name = "my_seq_lib");
        super.new(name);
        init_sequence_library();      // 등록된 시퀀스를 수집
    endfunction
endclass

// 라이브러리에 시퀀스 등록
class write_seq extends uvm_sequence #(seq_item);
    `uvm_object_utils(write_seq)
    `uvm_add_to_seq_lib(write_seq, my_seq_lib)
    ...
endclass

class read_seq extends uvm_sequence #(seq_item);
    `uvm_object_utils(read_seq)
    `uvm_add_to_seq_lib(read_seq, my_seq_lib)
    ...
endclass
"""),
        code("seq_lib_use.sv", """
virtual task run_phase(uvm_phase phase);
    my_seq_lib lib = my_seq_lib::type_id::create("lib");

    lib.selection_mode  = UVM_SEQ_LIB_RANDC;   // 선택 방식
    lib.min_random_count = 10;
    lib.max_random_count = 50;

    phase.raise_objection(this);
    lib.start(env.agt.seqr);      // 등록된 시퀀스를 무작위로 실행
    phase.drop_objection(this);
endtask
"""),
        table(["selection_mode", "동작"],
              [["UVM_SEQ_LIB_RAND", "무작위 선택 (중복 허용)"],
               ["UVM_SEQ_LIB_RANDC", "전부 한 번씩 돈 뒤 재순환"],
               ["UVM_SEQ_LIB_ITEM", "아이템만 직접 전송"],
               ["UVM_SEQ_LIB_USER", "select_sequence() 오버라이드"]],
              weights=[1.3, 1.5]),
        tip("언제 유용한가",
            "시퀀스가 20개쯤 되고 '아무거나 무작위로 섞어 돌려라'가 "
            "목표일 때 유용합니다. 개수가 적으면 직접 fork 하는 편이 "
            "더 명확합니다."),

        h2("49.5  시퀀스 응답 처리"),
        code("response_handling.sv", """
// 방법 1: 하나씩 대기
finish_item(item);
get_response(rsp);

// 방법 2: 응답 큐에서 꺼내기 (파이프라인)
virtual task body();
    fork
        // 요청 스트림
        repeat (10) begin
            item = seq_item::type_id::create("it");
            start_item(item);
            void'(item.randomize());
            finish_item(item);
        end
        // 응답 수집
        repeat (10) begin
            get_response(rsp);
            process(rsp);
        end
    join
endtask
"""),
        warn("응답 큐 크기",
             "기본 응답 큐 크기는 8입니다. 넘치면 경고가 나고 "
             "오래된 응답이 버려집니다. set_response_queue_depth(N) 으로 "
             "늘리거나, 응답을 제때 꺼내세요."),

        h2("49.6  실습"),
        lab("과제 49-A",
            "두 시퀀스를 동시에 시작하고 중재 정책을 바꿔가며 "
            "아이템 순서가 어떻게 달라지는지 로그로 확인하세요."),
        lab("과제 49-B",
            "grab 을 쓰는 시퀀스를 만들고 ungrab 을 빼먹었을 때 "
            "무슨 일이 일어나는지 확인하세요."),
        quiz("grab 과 lock 의 차이는?",
             ["① grab 은 읽기, lock 은 쓰기",
              "② grab 은 즉시 독점, lock 은 자기 차례를 기다린 뒤 독점",
              "③ 같은 것이다", "④ lock 은 해제가 필요 없다"],
             "② — grab 은 대기 중인 시퀀스를 제치고 바로 끼어듭니다. "
             "인터럽트 처리에 적합합니다."),
    ],
}


# ==========================================================================
CH50 = {
    "number": "CHAPTER 50",
    "title": "실습 5 - FIFO UVM 환경",
    "goals": [
        "상태를 가진 DUT 를 검증한다",
        "쓰기와 읽기 두 채널을 다룬다",
        "full/empty 경계 조건을 시험한다",
        "레퍼런스 모델로 큐를 쓴다",
    ],
    "body": [
        lead("가산기는 상태가 없고, 레지스터는 상태가 하나입니다. "
             "FIFO 는 깊이만큼의 상태를 갖고 두 채널이 독립적으로 "
             "움직입니다. 난이도가 한 단계 올라갑니다."),

        h2("50.1  DUT"),
        code("sync_fifo.sv", """
`timescale 1ns / 1ps

module sync_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 8
) (
    input  logic             clk,
    input  logic             rstn,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             full,
    output logic             empty
);
    localparam int PTR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH];
    logic [PTR_W:0]   wr_ptr, rd_ptr;      // 1비트 여유로 full/empty 구분

    assign full  = (wr_ptr[PTR_W] != rd_ptr[PTR_W]) &&
                   (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]);
    assign empty = (wr_ptr == rd_ptr);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr[PTR_W-1:0]];
            rd_ptr  <= rd_ptr + 1;
        end
    end
endmodule
"""),
        key("포인터에 1비트를 더 두는 이유",
            "wr_ptr == rd_ptr 이 empty 인지 full 인지 구분해야 합니다. "
            "MSB 를 하나 더 두면 '몇 바퀴 돌았는가'가 기록되어 "
            "두 경우를 구분할 수 있습니다."),

        h2("50.2  interface"),
        code("fifo_if.sv", """
interface fifo_if #(parameter int WIDTH = 8) (input logic clk);
    logic             rstn;
    logic             wr_en, rd_en;
    logic [WIDTH-1:0] wr_data, rd_data;
    logic             full, empty;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output wr_en, rd_en, wr_data;
        input  rd_data, full, empty;
    endclocking

    modport tb (clocking cb, output rstn);
endinterface
"""),

        h2("50.3  sequence_item"),
        code("fifo_item.svh", """
typedef enum {FIFO_WRITE, FIFO_READ, FIFO_BOTH, FIFO_IDLE} fifo_op_e;

class fifo_item extends uvm_sequence_item;
    `uvm_object_utils(fifo_item)

    rand fifo_op_e     op;
    rand bit [7:0]     wr_data;

    // DUT 응답
    bit [7:0]          rd_data;
    bit                full, empty;

    function new(string name = "fifo_item");
        super.new(name);
    endfunction

    constraint c_op { op dist {FIFO_WRITE := 40, FIFO_READ := 40,
                               FIFO_BOTH  := 15, FIFO_IDLE := 5}; }

    function string convert2string();
        return $sformatf("%-10s wr=0x%02h rd=0x%02h full=%0b empty=%0b",
                          op.name(), wr_data, rd_data, full, empty);
    endfunction
endclass
"""),

        h2("50.4  시퀀스 - 경계 조건 겨냥"),
        code("fifo_sequences.svh", """
// 무작위 혼합
class fifo_random_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_random_seq)
    rand int unsigned n = 100;
    constraint c_n { n inside {[50:200]}; }

    function new(string name = "fifo_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        fifo_item it;
        repeat (n) begin
            it = fifo_item::type_id::create("it");
            start_item(it);
            if (!it.randomize()) `uvm_error("SEQ", "rand fail")
            finish_item(it);
        end
    endtask
endclass

// full 을 만들고 그 상태에서 쓰기 시도
class fifo_overflow_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_overflow_seq)
    int unsigned depth = 8;

    function new(string name = "fifo_overflow_seq");
        super.new(name);
    endfunction

    virtual task body();
        fifo_item it;
        // 깊이 + 4 만큼 쓰기 -> 마지막 4개는 무시되어야 함
        repeat (depth + 4) begin
            it = fifo_item::type_id::create("it");
            start_item(it);
            it.op = FIFO_WRITE;
            if (!it.randomize(wr_data)) `uvm_error("SEQ", "rand fail")
            finish_item(it);
        end
    endtask
endclass

// empty 상태에서 읽기 시도
class fifo_underflow_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_underflow_seq)

    function new(string name = "fifo_underflow_seq");
        super.new(name);
    endfunction

    virtual task body();
        fifo_item it;
        repeat (4) begin
            it = fifo_item::type_id::create("it");
            start_item(it);
            it.op = FIFO_READ;
            finish_item(it);
        end
    endtask
endclass
"""),

        h2("50.5  driver"),
        code("fifo_driver.svh", """
class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)
    virtual fifo_if vif;

    function new(string n, uvm_component p); super.new(n, p); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"vif 없음: ", get_full_name()})
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.cb.wr_en <= 1'b0;
        vif.cb.rd_en <= 1'b0;
        wait (vif.rstn === 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            @(vif.cb);
            case (req.op)
                FIFO_WRITE : begin
                    vif.cb.wr_en   <= 1'b1;
                    vif.cb.rd_en   <= 1'b0;
                    vif.cb.wr_data <= req.wr_data;
                end
                FIFO_READ  : begin
                    vif.cb.wr_en <= 1'b0;
                    vif.cb.rd_en <= 1'b1;
                end
                FIFO_BOTH  : begin
                    vif.cb.wr_en   <= 1'b1;
                    vif.cb.rd_en   <= 1'b1;
                    vif.cb.wr_data <= req.wr_data;
                end
                FIFO_IDLE  : begin
                    vif.cb.wr_en <= 1'b0;
                    vif.cb.rd_en <= 1'b0;
                end
            endcase
            seq_item_port.item_done();
        end
    endtask
endclass
"""),

        h2("50.6  scoreboard - 큐가 레퍼런스 모델"),
        code("fifo_scoreboard.svh", """
class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp #(fifo_item, fifo_scoreboard) item_export;

    bit [7:0]    model[$];          // 레퍼런스 모델 = 큐
    int unsigned depth = 8;
    int unsigned n_check, n_err;

    function new(string n, uvm_component p);
        super.new(n, p);
        item_export = new("item_export", this);
    endfunction

    virtual function void write(fifo_item t);
        bit model_full  = (model.size() >= depth);
        bit model_empty = (model.size() == 0);

        // 1) 상태 플래그 확인
        if (t.full !== model_full) begin
            n_err++;
            `uvm_error("SCB", $sformatf(
                "full 불일치: 모델=%0b DUT=%0b (모델 크기 %0d)",
                model_full, t.full, model.size()))
        end
        if (t.empty !== model_empty) begin
            n_err++;
            `uvm_error("SCB", $sformatf(
                "empty 불일치: 모델=%0b DUT=%0b (모델 크기 %0d)",
                model_empty, t.empty, model.size()))
        end

        // 2) 읽기 데이터 확인
        if ((t.op == FIFO_READ || t.op == FIFO_BOTH) && !model_empty) begin
            bit [7:0] exp = model.pop_front();
            if (t.rd_data !== exp) begin
                n_err++;
                `uvm_error("SCB", $sformatf(
                    "rd_data 불일치: 기대=0x%02h 실제=0x%02h",
                    exp, t.rd_data))
            end
        end

        // 3) 쓰기 반영
        if ((t.op == FIFO_WRITE || t.op == FIFO_BOTH) && !model_full)
            model.push_back(t.wr_data);

        n_check++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", $sformatf(
            "검사 %0d건, 에러 %0d건, 모델에 %0d개 남음",
            n_check, n_err, model.size()), UVM_NONE)
        if (n_check == 0)
            `uvm_error("SCB", "검사가 수행되지 않았습니다")
    endfunction
endclass
"""),
        key("큐가 곧 FIFO 모델",
            "SystemVerilog 의 큐는 FIFO 그 자체입니다. "
            "push_back / pop_front 만으로 레퍼런스 모델이 완성됩니다. "
            "복잡한 코드가 필요 없습니다."),
        trap("순서에 주의",
             "읽기 확인을 쓰기 반영보다 먼저 해야 합니다. "
             "FIFO_BOTH 에서 순서를 바꾸면 방금 쓴 값을 "
             "바로 읽는 것으로 잘못 계산합니다."),

        h2("50.7  커버리지"),
        code("fifo_coverage.svh", """
covergroup fifo_cg;
    option.per_instance = 1;

    cp_op    : coverpoint it.op;
    cp_full  : coverpoint it.full  { bins f[] = {0, 1}; }
    cp_empty : coverpoint it.empty { bins e[] = {0, 1}; }

    // 핵심: full 상태에서 쓰기, empty 상태에서 읽기
    x_full_wr : cross cp_op, cp_full {
        bins overflow = binsof(cp_op) intersect {FIFO_WRITE, FIFO_BOTH}
                     && binsof(cp_full.f) intersect {1};
    }
    x_empty_rd : cross cp_op, cp_empty {
        bins underflow = binsof(cp_op) intersect {FIFO_READ, FIFO_BOTH}
                      && binsof(cp_empty.e) intersect {1};
    }

    // 동시 읽기/쓰기가 full/empty 에서 일어났는가
    x_both : cross cp_op, cp_full, cp_empty {
        ignore_bins impossible = binsof(cp_full.f) intersect {1}
                              && binsof(cp_empty.e) intersect {1};
    }
endgroup
"""),

        h2("50.8  실습"),
        lab("과제 50-A",
            "위 환경을 완성하고 random / overflow / underflow 세 테스트를 "
            "각각 실행해 전부 통과하는지 확인하세요."),
        lab("과제 50-B",
            "DUT 의 full 조건에서 wr_ptr[PTR_W] != rd_ptr[PTR_W] 를 "
            "== 로 바꿔 스코어보드가 잡아내는지 확인하세요."),
        lab("과제 50-C",
            "DEPTH 를 4, 8, 16 으로 바꿔가며 실행하고 "
            "스코어보드의 depth 도 함께 바뀌도록 config_db 로 전달하세요."),
        lab("과제 50-D",
            "동시 읽기/쓰기(FIFO_BOTH)가 full 상태에서 일어날 때 "
            "DUT 동작이 스펙과 맞는지 확인하고, "
            "스코어보드가 그 경우를 올바로 모델링하는지 검토하세요."),
        quiz("FIFO 스코어보드에서 읽기 확인을 쓰기 반영보다 먼저 해야 하는 이유는?",
             ["① 성능", "② 동시 읽기/쓰기에서 방금 쓴 값을 읽는 것으로 오계산",
              "③ 큐 API 제약", "④ 순서는 상관없다"],
             "② — FIFO_BOTH 에서 push 를 먼저 하면 그 값이 큐에 들어간 뒤 "
             "pop 되어, 실제 DUT 동작과 다른 기대값이 나옵니다."),
    ],
}


# ==========================================================================
CH51 = {
    "number": "CHAPTER 51",
    "title": "형식 검증 입문",
    "goals": [
        "시뮬레이션과 형식 검증의 차이를 안다",
        "assume 과 assert 의 역할을 구분한다",
        "형식 검증에 적합한 대상을 고른다",
        "반례를 해석한다",
    ],
    "body": [
        lead("시뮬레이션은 '내가 넣은 자극에서 문제가 없었다'를 보여줍니다. "
             "형식 검증은 '모든 가능한 입력에서 문제가 없다'를 증명합니다. "
             "18-19장에서 쓴 assertion 이 그대로 재료가 됩니다."),

        h2("51.1  두 방법의 차이"),
        table(["기준", "시뮬레이션", "형식 검증"],
              [["입력", "내가 만든 자극", "수학적으로 모든 경우"],
               ["결과", "이 자극에서는 통과", "증명 또는 반례"],
               ["규모", "큰 설계도 가능", "상태 공간 폭발에 취약"],
               ["커버리지", "측정 필요", "개념상 100%"],
               ["적합 대상", "데이터패스, 시스템", "제어 로직, 프로토콜"],
               ["결과 해석", "파형", "반례(counterexample) 파형"]],
              weights=[0.8, 1.3, 1.3]),
        key("경쟁이 아니라 보완",
            "형식 검증은 작고 제어 중심인 블록에 강하고, "
            "시뮬레이션은 크고 데이터 중심인 시스템에 강합니다. "
            "실무는 둘을 함께 씁니다."),

        h2("51.2  assert / assume / cover"),
        code("formal_directives.sv", """
// assert : 증명해야 할 성질 (DUT 가 지켜야 함)
a_no_overflow : assert property (
    @(posedge clk) disable iff (!rstn)
    (wr_en && full) |=> $stable(count)
);

// assume : 환경이 지킨다고 가정하는 제약 (입력 조건)
m_no_wr_when_full : assume property (
    @(posedge clk) disable iff (!rstn)
    full |-> !wr_en
);

// cover : 이 상황이 도달 가능한가 (sanity check)
c_full : cover property (
    @(posedge clk) disable iff (!rstn) full
);
"""),
        kv([("assert", "이것이 항상 참임을 증명하라"),
            ("assume", "이 조건 아래에서만 증명하면 된다 (입력 제약)"),
            ("cover", "이 상황에 도달할 수 있는지 확인 (반례를 찾아라)")], 68),
        trap("assume 을 과하게 걸면",
             "증명이 쉬워지는 대신 무의미해집니다. "
             "'입력이 절대 안 온다'고 가정하면 아무 성질이나 증명됩니다. "
             "assume 은 실제 환경이 보장하는 것만 써야 합니다."),
        key("vacuity 검사",
            "assume 을 걸었으면 cover property 로 관심 상황이 여전히 "
            "도달 가능한지 확인하세요. cover 가 실패하면 assume 이 "
            "너무 강한 것입니다."),

        h2("51.3  형식 검증에 적합한 대상"),
        table(["적합", "부적합"],
              [["FIFO 제어 로직 (포인터, full/empty)", "곱셈기, FFT 같은 데이터패스"],
               ["arbiter (중재기)", "큰 메모리를 포함한 블록"],
               ["프로토콜 브리지", "CPU 코어 전체"],
               ["FSM", "긴 카운터 (2^32 상태)"],
               ["CDC 동기화 회로", "부동소수점 연산기"]],
              weights=[1.3, 1.3]),
        tip("상태 공간을 줄여라",
            "FIFO 깊이 1024 는 증명이 안 되지만 깊이 4 는 됩니다. "
            "파라미터를 줄여 증명한 뒤 '깊이에 무관한 성질'이라고 "
            "논증하는 것이 실무 기법입니다."),

        h2("51.4  반례 읽기"),
        art("""
   형식 도구가 내놓는 반례 (counterexample)

   clk     _|~|_|~|_|~|_|~|_
   rstn    ~~~~~~~~~~~~~~~~~
   wr_en   ___|~~~~~~~|_____
   rd_en   _______________|~
   full    _______|~~~~~~~~~
   count   0  1  2  3  3  3
                     ^
                     +-- 여기서 assert 위반

   "wr_en=1 이고 full=1 인데 count 가 변했다"
   -> 가장 짧은 위반 경로를 보여준다
"""),
        p("반례는 시뮬레이션 파형보다 짧습니다. 도구가 "
          "'위반에 이르는 최단 경로'를 찾아주기 때문입니다. "
          "디버깅이 훨씬 빠릅니다."),
        ol("반례가 실제로 가능한 시나리오인가 확인한다",
           "불가능하다면 assume 이 빠진 것 - 환경 제약을 추가",
           "가능하다면 진짜 버그 - RTL 을 고친다",
           "고친 뒤 다시 증명한다"),

        h2("51.5  Vivado 에서는"),
        note("도구 지원",
             "Vivado 는 형식 검증(property checking) 기능을 제공하지 않습니다. "
             "JasperGold, VC Formal, Questa PropCheck 같은 전용 도구가 "
             "필요합니다. 다만 작성하는 SVA 문법은 동일하므로, "
             "시뮬레이션용으로 쓴 assertion 이 그대로 재료가 됩니다.",
             "warn"),
        key("학부 수준에서의 결론",
            "형식 검증 도구를 직접 다룰 기회는 적겠지만, "
            "assertion 을 잘 쓰는 습관을 들이면 그것이 곧 "
            "형식 검증 진입 준비입니다. 18-19장을 충실히 하세요."),

        h2("51.6  실습"),
        lab("과제 51-A",
            "50장의 FIFO 에 대해 형식 검증용 assert 3개와 "
            "assume 2개를 작성하세요. 도구가 없어도 "
            "무엇을 증명하고 무엇을 가정할지 설계하는 연습이 됩니다."),
        quiz("assume 을 과하게 거는 것이 위험한 이유는?",
             ["① 시뮬레이션이 느려진다",
              "② 증명은 통과하지만 실제로 일어나는 경우를 배제해 무의미해진다",
              "③ 컴파일 에러", "④ 반례를 못 찾는다"],
             "② — 극단적으로 '입력이 없다'고 가정하면 어떤 성질이든 "
             "증명됩니다. cover property 로 도달 가능성을 함께 확인하세요."),
    ],
}


CHAPTERS = [CH46, CH47, CH48, CH49, CH50, CH51]
