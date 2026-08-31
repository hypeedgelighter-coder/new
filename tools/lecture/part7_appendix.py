"""Part VIII - 부록 (레퍼런스 / 체크리스트 / 용어집 / 종합문제 / 로드맵)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART VIII",
    "title": "부록 - 레퍼런스와 정리",
    "blurb": "실습 중에 펼쳐 놓고 참조하는 부분입니다. 클래스와 매크로 "
             "레퍼런스, 코딩 체크리스트, 자주 쓰는 코드 조각, 용어집, "
             "그리고 종합 연습문제를 담았습니다.",
    "items": [
        "52장 UVM 클래스 레퍼런스",
        "53장 매크로와 명령행 옵션 레퍼런스",
        "54장 SystemVerilog 문법 요약",
        "55장 코딩 체크리스트",
        "56장 코드 스니펫 모음",
        "57장 용어집",
        "58장 종합 연습문제",
        "59장 학습 로드맵",
    ],
}


# ==========================================================================
CH52 = {
    "number": "CHAPTER 52",
    "title": "UVM 클래스 레퍼런스",
    "goals": [
        "자주 쓰는 클래스의 상속 관계를 찾는다",
        "각 클래스가 제공하는 멤버를 안다",
        "생성자 시그니처를 확인한다",
        "필요한 클래스를 빠르게 고른다",
    ],
    "body": [
        lead("실습 중에 '이 클래스에 뭐가 있더라'를 확인하는 용도입니다. "
             "전부 외울 필요는 없고, 어디를 보면 되는지만 알면 됩니다."),

        h2("52.1  상속 트리 전체"),
        art("""
   uvm_void
     |
     +-- uvm_object                        <- 동적, 계층 없음
     |     |
     |     +-- uvm_transaction
     |     |     +-- uvm_sequence_item
     |     |
     |     +-- uvm_sequence_base
     |     |     +-- uvm_sequence #(REQ, RSP)
     |     |
     |     +-- uvm_object_wrapper
     |     |     +-- uvm_object_registry #(T, Tname)
     |     |     +-- uvm_component_registry #(T, Tname)
     |     |
     |     +-- uvm_printer / uvm_comparer / uvm_packer
     |     +-- uvm_callback
     |     +-- uvm_reg / uvm_reg_field / uvm_reg_block
     |
     +-- uvm_report_object
           |
           +-- uvm_component                <- 정적, 계층 있음
                 |
                 +-- uvm_driver #(REQ, RSP)
                 +-- uvm_monitor
                 +-- uvm_sequencer #(REQ, RSP)
                 +-- uvm_subscriber #(T)
                 +-- uvm_scoreboard
                 +-- uvm_agent
                 +-- uvm_env
                 +-- uvm_test
"""),

        h2("52.2  uvm_object"),
        table(["멤버", "설명"],
              [["new(string name)", "생성자"],
               ["get_name()", "인스턴스 이름"],
               ["get_full_name()", "object 는 get_name 과 동일"],
               ["get_type_name()", "타입 이름 문자열"],
               ["clone()", "복사본 생성. uvm_object 반환 - $cast 필요"],
               ["copy(rhs)", "rhs 의 내용을 자기에게 복사"],
               ["compare(rhs)", "비교. 같으면 1"],
               ["print()", "필드 출력"],
               ["convert2string()", "한 줄 요약 (직접 구현 권장)"],
               ["do_copy / do_compare / do_print", "사용자 훅"]],
              weights=[1.3, 1.5]),

        h2("52.3  uvm_component"),
        table(["멤버", "설명"],
              [["new(string name, uvm_component parent)", "생성자"],
               ["get_full_name()", "전체 계층 경로"],
               ["get_parent()", "부모 컴포넌트"],
               ["get_child(name)", "자식 조회"],
               ["get_children(array)", "자식 전부"],
               ["build_phase(phase)", "자식 생성"],
               ["connect_phase(phase)", "포트 연결"],
               ["end_of_elaboration_phase", "계층 확정 후"],
               ["start_of_simulation_phase", "시뮬레이션 직전"],
               ["run_phase(phase)", "실행 (유일한 task)"],
               ["extract / check / report_phase", "사후 처리"],
               ["set_report_verbosity_level(v)", "이 컴포넌트의 로그 수준"],
               ["print_topology()", "계층 출력 (uvm_top 에서)"]],
              weights=[1.5, 1.3]),

        h2("52.4  uvm_sequence_item"),
        table(["멤버", "설명"],
              [["set_id_info(item)", "응답을 요청과 짝지음"],
               ["get_sequence_id()", "이 아이템을 만든 시퀀스 ID"],
               ["get_transaction_id()", "트랜잭션 ID"],
               ["pre_randomize()", "랜덤화 직전 훅"],
               ["post_randomize()", "랜덤화 직후 훅"]],
              weights=[1.3, 1.5]),

        h2("52.5  uvm_sequence"),
        table(["멤버", "설명"],
              [["body()", "시퀀스 본문 (오버라이드 대상)"],
               ["start(seqr, parent, prio)", "시퀀스 시작"],
               ["start_item(item, prio)", "sequencer 에 요청, 블록"],
               ["finish_item(item, prio)", "driver 로 전달, 블록"],
               ["get_response(rsp)", "응답 수신"],
               ["m_sequencer", "실행 중인 sequencer 핸들"],
               ["p_sequencer", "매크로가 만든 캐스팅 핸들"],
               ["pre_body / post_body", "본문 앞뒤 훅"],
               ["pre_start / post_start", "시작 전후 훅"]],
              weights=[1.4, 1.4]),

        h2("52.6  uvm_driver"),
        table(["멤버", "설명"],
              [["seq_item_port", "sequencer 연결 포트"],
               ["req", "수신 아이템 (REQ 타입, 미리 선언됨)"],
               ["rsp", "응답 아이템 (RSP 타입)"],
               ["seq_item_port.get_next_item(req)", "아이템 수신, 블록"],
               ["seq_item_port.try_next_item(req)", "즉시 시도"],
               ["seq_item_port.item_done(rsp)", "완료 통보"],
               ["seq_item_port.peek(req)", "소비 없이 확인"]],
              weights=[1.6, 1.3]),

        h2("52.7  TLM 포트"),
        table(["클래스", "방향", "블록"],
              [["uvm_analysis_port #(T)", "발신 1:N", "없음"],
               ["uvm_analysis_imp #(T, IMP)", "수신", "없음"],
               ["uvm_analysis_export #(T)", "중계", "없음"],
               ["uvm_subscriber #(T)", "수신 컴포넌트", "없음"],
               ["uvm_tlm_analysis_fifo #(T)", "버퍼", "get 만"],
               ["uvm_blocking_put_port #(T)", "발신 1:1", "있음"],
               ["uvm_blocking_get_port #(T)", "수신 1:1", "있음"],
               ["uvm_seq_item_pull_port", "driver 전용", "있음"]],
              weights=[1.6, 1.0, 0.7]),

        h2("52.8  config_db 와 resource_db"),
        code("config_db_api.sv", """
// 설정
uvm_config_db #(T)::set(uvm_component cntxt, string inst_name,
                        string field_name, T value);

// 조회
bit ok = uvm_config_db #(T)::get(uvm_component cntxt, string inst_name,
                                 string field_name, ref T value);

// 존재 확인만
bit ok = uvm_config_db #(T)::exists(cntxt, inst_name, field_name);

// 대기 (설정될 때까지)
uvm_config_db #(T)::wait_modified(cntxt, inst_name, field_name);
"""),

        h2("52.9  자주 쓰는 유틸리티"),
        table(["함수", "용도"],
              [["uvm_top", "최상위 컴포넌트 (uvm_root 싱글톤)"],
               ["uvm_top.print_topology()", "계층 출력"],
               ["uvm_top.set_timeout(t, 1)", "전역 타임아웃"],
               ["uvm_factory::get()", "factory 싱글톤"],
               ["uvm_factory::get().print()", "등록 타입과 override 출력"],
               ["uvm_report_server::get_server()", "리포트 서버"],
               ["svr.get_severity_count(UVM_ERROR)", "에러 개수"],
               ["uvm_is_match(pattern, str)", "와일드카드 매칭"],
               ["$sformatf(fmt, ...)", "문자열 조립"]],
              weights=[1.6, 1.4]),
    ],
}


# ==========================================================================
CH53 = {
    "number": "CHAPTER 53",
    "title": "매크로와 명령행 옵션 레퍼런스",
    "goals": [
        "매크로의 정확한 인자를 확인한다",
        "필드 플래그를 조합한다",
        "명령행 옵션으로 동작을 바꾼다",
        "매크로 정의 위치를 찾는다",
    ],
    "body": [
        lead("매크로는 인자 개수를 틀리기 쉽고, 명령행 옵션은 "
             "이름을 기억하기 어렵습니다. 이 장을 펼쳐 놓고 쓰세요."),

        h2("53.1  등록 매크로"),
        table(["매크로", "쓰는 곳", "인자"],
              [["`uvm_object_utils(T)", "object, 필드 자동화 없음", "타입"],
               ["`uvm_object_utils_begin(T)", "object, 필드 자동화 시작", "타입"],
               ["`uvm_object_utils_end", "필드 자동화 끝", "없음"],
               ["`uvm_object_param_utils(T)", "파라미터화 object", "타입#(파라미터)"],
               ["`uvm_component_utils(T)", "component", "타입"],
               ["`uvm_component_utils_begin(T)", "component + 필드", "타입"],
               ["`uvm_component_param_utils(T)", "파라미터화 component", "타입#(...)"]],
              weights=[1.6, 1.4, 1.0]),
        code("utils_example.sv", """
// 필드 자동화 없이 (빠름)
class a extends uvm_object;
    `uvm_object_utils(a)
endclass

// 필드 자동화 포함
class b extends uvm_object;
    `uvm_object_utils_begin(b)
        `uvm_field_int(x, UVM_DEFAULT)
    `uvm_object_utils_end
endclass
"""),

        h2("53.2  필드 매크로"),
        table(["매크로", "대상 타입"],
              [["`uvm_field_int(name, FLAG)", "정수형 (logic, bit, int)"],
               ["`uvm_field_real(name, FLAG)", "실수형"],
               ["`uvm_field_enum(T, name, FLAG)", "enum (타입 인자 필요)"],
               ["`uvm_field_object(name, FLAG)", "uvm_object 핸들"],
               ["`uvm_field_string(name, FLAG)", "string"],
               ["`uvm_field_event(name, FLAG)", "event"],
               ["`uvm_field_array_int(name, FLAG)", "정수 배열"],
               ["`uvm_field_queue_int(name, FLAG)", "정수 큐"],
               ["`uvm_field_aa_int_string(name, FLAG)", "연관배열 (string 키)"],
               ["`uvm_field_sarray_int(name, FLAG)", "고정 배열"]],
              weights=[1.7, 1.3]),

        h2("53.3  필드 플래그"),
        table(["플래그", "효과"],
              [["UVM_DEFAULT", "전부 활성 (가장 흔함)"],
               ["UVM_ALL_ON", "UVM_DEFAULT 와 동일"],
               ["UVM_NOCOPY", "copy 에서 제외"],
               ["UVM_NOCOMPARE", "compare 에서 제외"],
               ["UVM_NOPRINT", "print 에서 제외"],
               ["UVM_NOPACK", "pack/unpack 에서 제외"],
               ["UVM_READONLY", "자동 설정에서 제외"],
               ["UVM_BIN / UVM_DEC / UVM_HEX", "출력 진법"],
               ["UVM_OCT / UVM_STRING / UVM_TIME", "출력 형식"]],
              weights=[1.5, 1.4]),
        code("flag_combine2.sv", """
`uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
`uvm_field_int(resp, UVM_DEFAULT | UVM_NOCOMPARE)   // DUT 응답
`uvm_field_int(dbg,  UVM_NOPRINT | UVM_NOCOMPARE)   // 내부용
"""),

        h2("53.4  report 매크로"),
        table(["매크로", "인자", "카운터"],
              [["`uvm_info(ID, MSG, VERB)", "3개", "UVM_INFO"],
               ["`uvm_warning(ID, MSG)", "2개", "UVM_WARNING"],
               ["`uvm_error(ID, MSG)", "2개", "UVM_ERROR"],
               ["`uvm_fatal(ID, MSG)", "2개", "UVM_FATAL + 종료"],
               ["`uvm_info_context(ID,MSG,V,C)", "4개", "지정 컨텍스트로"]],
              weights=[1.7, 0.7, 1.1]),

        h2("53.5  시퀀스 매크로"),
        table(["매크로", "동작"],
              [["`uvm_do(SEQ_OR_ITEM)", "create + start + rand + finish"],
               ["`uvm_do_with(S, {제약})", "인라인 제약 포함"],
               ["`uvm_do_pri(S, PRI)", "우선순위 지정"],
               ["`uvm_do_pri_with(S, PRI, {제약})", "둘 다"],
               ["`uvm_create(S)", "생성만"],
               ["`uvm_send(S)", "start_item + finish_item"],
               ["`uvm_rand_send(S)", "랜덤 + 전송"],
               ["`uvm_declare_p_sequencer(T)", "p_sequencer 선언"]],
              weights=[1.7, 1.4]),

        h2("53.6  callback 매크로"),
        code("callback_macros.sv", """
`uvm_register_cb(T, CB)              // 클래스에 callback 등록 가능 선언
`uvm_set_super_type(T, SUPER)        // 상속 관계 명시
`uvm_do_callbacks(T, CB, METHOD)     // callback 실행
`uvm_do_callbacks_exit_on(T, CB, METHOD, VAL)   // 조건부 중단
`uvm_analysis_imp_decl(SUFFIX)       // write_SUFFIX 를 갖는 imp 생성
"""),

        h2("53.7  명령행 옵션"),
        table(["옵션", "효과"],
              [["+UVM_TESTNAME=name", "실행할 테스트"],
               ["+UVM_VERBOSITY=UVM_HIGH", "전역 로그 수준"],
               ["+UVM_MAX_QUIT_COUNT=N", "에러 N개면 중단"],
               ["+UVM_TIMEOUT=<time>,<overridable>", "전역 타임아웃"],
               ["+UVM_OBJECTION_TRACE", "objection raise/drop 추적"],
               ["+UVM_PHASE_TRACE", "phase 전이 추적"],
               ["+UVM_CONFIG_DB_TRACE", "config_db set/get 추적"],
               ["+UVM_RESOURCE_DB_TRACE", "resource_db 추적"],
               ["+uvm_set_verbosity=<경로>,<ID>,<수준>,<시점>", "부분 로그 수준"],
               ["+uvm_set_action=<경로>,<ID>,<severity>,<action>", "심각도별 동작"],
               ["+uvm_set_severity=<경로>,<ID>,<cur>,<new>", "심각도 변경"],
               ["+uvm_set_type_override=<orig>,<new>", "명령행 factory override"],
               ["+uvm_set_inst_override=<orig>,<new>,<path>", "인스턴스 override"]],
              weights=[1.8, 1.3]),
        code("cmdline_examples.sh", """
# 특정 컴포넌트만 상세 로그
xsim tb -R +uvm_set_verbosity=uvm_test_top.env.agt.drv,_ALL_,UVM_HIGH,time,0

# 에러를 경고로 낮추기 (임시 우회)
xsim tb -R +uvm_set_severity=uvm_test_top.env.scb,SCB,UVM_ERROR,UVM_WARNING

# 재컴파일 없이 override
xsim tb -R +uvm_set_type_override=seq_item,err_item
"""),
        key("+uvm_set_type_override 의 가치",
            "재컴파일 없이 factory override 를 걸 수 있습니다. "
            "회귀에서 여러 변형을 돌릴 때 유용합니다."),

        h2("53.8  Vivado 특화"),
        code("vivado_opts.sh", """
# 컴파일
xvlog -sv -L uvm  file.sv          # -L uvm 필수

# 엘라보레이션
xelab -L uvm -debug typical tb -s snapshot
xelab -L uvm -cov_db_name mycov -cov_db_dir ./cov tb -s snapshot

# 실행
xsim snapshot -R                                # 배치
xsim snapshot --gui                             # GUI
xsim snapshot -R -sv_seed random                # 매번 다른 시드
xsim snapshot -R -sv_seed 12345                 # 고정 시드
xsim snapshot -R -log my.log                    # 로그 파일 지정

# 커버리지 리포트
xcrg -report_format html -dir ./cov -report_dir ./cov_report
"""),
        table(["소스 위치 (Vivado 2020.2)", "내용"],
              [["...\\uvm_1.2\\uvm_macros.svh", "모든 매크로 정의"],
               ["...\\uvm_1.2\\xlnx_uvm_package.sv", "UVM 클래스 전체"]],
              weights=[1.6, 1.0]),
    ],
}


# ==========================================================================
CH54 = {
    "number": "CHAPTER 54",
    "title": "SystemVerilog 문법 요약",
    "goals": [
        "자료형과 연산자를 빠르게 확인한다",
        "제약 문법을 참조한다",
        "커버리지와 assertion 문법을 찾는다",
        "시스템 함수를 확인한다",
    ],
    "body": [
        lead("문법이 헷갈릴 때 펼치는 부분입니다."),

        h2("54.1  자료형"),
        table(["타입", "상태", "폭", "부호", "초기값"],
              [["logic", "4", "지정", "unsigned", "X"],
               ["reg", "4", "지정", "unsigned", "X"],
               ["wire", "4", "지정", "unsigned", "Z"],
               ["integer", "4", "32", "signed", "X"],
               ["time", "4", "64", "unsigned", "X"],
               ["bit", "2", "지정", "unsigned", "0"],
               ["byte", "2", "8", "signed", "0"],
               ["shortint", "2", "16", "signed", "0"],
               ["int", "2", "32", "signed", "0"],
               ["longint", "2", "64", "signed", "0"],
               ["real", "-", "64", "signed", "0.0"],
               ["string", "-", "가변", "-", "\"\""]],
              weights=[1.0, 0.6, 0.6, 0.9, 0.7]),

        h2("54.2  연산자 우선순위 (높은 것부터)"),
        code("operator_precedence.txt", """
 1  () [] :: .                     괄호, 인덱스, 스코프
 2  + - ! ~ & ~& | ~| ^ ~^         단항, 축약
 3  **                             거듭제곱
 4  * / %                          곱셈류
 5  + -                            덧셈류
 6  << >> <<< >>>                  시프트
 7  < <= > >= inside dist          비교
 8  == != === !== ==? !=?          등가
 9  & ~&                           비트 AND
10  ^ ~^                           비트 XOR
11  | ~|                           비트 OR
12  &&                             논리 AND
13  ||                             논리 OR
14  ?:                             조건
15  -> <->                         함축
16  = += -= <= 등                  대입
"""),
        table(["연산자", "X/Z 처리"],
              [["==", "X 가 있으면 결과가 X"],
               ["!=", "X 가 있으면 결과가 X"],
               ["===", "X, Z 까지 정확히 비교"],
               ["!==", "X, Z 까지 정확히 비교"],
               ["==?", "우변의 X/Z 를 wildcard 로"],
               ["!=?", "우변의 X/Z 를 wildcard 로"]],
              weights=[1.0, 1.6]),
        key("검증 코드에서는 === / !==",
            "스코어보드 비교에 == 를 쓰면 X 가 섞였을 때 조건이 "
            "거짓이 되어 버그를 놓칩니다."),

        h2("54.3  제약 문법"),
        code("constraint_syntax.sv", """
constraint c_name {
    // 범위
    a inside {[0:255]};
    b inside {1, 2, 4, 8};
    c inside {[0:9], [20:29], 50};
    !(d inside {[100:200]});          // 제외

    // 분포
    e dist {0 := 10, 1 := 20, [2:5] := 30};   // 각 값에 가중치
    f dist {[0:9] :/ 50, [10:99] :/ 50};      // 범위에 가중치

    // 관계
    g < h;
    i + j == 100;
    k % 4 == 0;

    // 조건
    en -> (data > 0);                 // 함축
    if (mode == 1) len == 8;
    else           len == 16;

    // 배열
    arr.size() inside {[1:16]};
    foreach (arr[idx]) arr[idx] < 100;
    unique {a, b, c};                 // 서로 다른 값

    // 해 순서
    solve en before data;

    // 소프트 제약 (충돌 시 무시됨)
    soft len == 8;
}
"""),
        code("constraint_control.sv", """
obj.c_name.constraint_mode(0);      // 이 제약 끄기
obj.constraint_mode(0);             // 모든 제약 끄기
obj.field.rand_mode(0);             // 이 필드를 랜덤화 제외

obj.randomize() with { a == 5; };   // 인라인 제약
obj.randomize(a, b);                // 지정 필드만 랜덤화
"""),

        h2("54.4  커버리지 문법"),
        code("coverage_syntax.sv", """
covergroup cg_name @(posedge clk);       // 자동 샘플링 (생략 가능)
    option.per_instance = 1;
    option.at_least     = 2;
    option.goal         = 95;
    option.weight       = 1;

    cp_name : coverpoint expr {
        bins single   = {5};
        bins list     = {1, 3, 5};
        bins range    = {[0:15]};
        bins each[]   = {[0:15]};        // 값마다 별개 bin
        bins split[4] = {[0:255]};       // 4개로 분할
        bins others   = default;

        // 전이 커버리지
        bins trans    = (0 => 1 => 2);
        bins rep      = (1 [*3]);

        ignore_bins  ig  = {[240:255]};
        illegal_bins bad = {255};
    }

    x_name : cross cp_a, cp_b {
        ignore_bins ig = binsof(cp_a.low) && binsof(cp_b.high);
        bins        sel = binsof(cp_a.max);
    }
endgroup

cg_name cg = new();       // 반드시 생성
cg.sample();              // 수동 샘플링
cg.get_inst_coverage();   // 이 인스턴스 커버리지 %
cg.get_coverage();        // 타입 전체 커버리지 %
"""),

        h2("54.5  assertion 문법"),
        code("sva_syntax.sv", """
// 시퀀스
sequence s_name;
    a ##1 b ##[1:5] c;           // 지연
    a[*3];                        // 연속 3회
    a[->2];                       // 비연속 2번째
    a[=2];                        // 비연속 2회 후 자유
endsequence

// 프로퍼티
property p_name;
    @(posedge clk) disable iff (!rstn)
    req |-> ##1 ack;             // 함축 (overlapped)
    // req |=> ack;              // non-overlapped (= |-> ##1)
endproperty

// 사용
a_name : assert property (p_name) else `uvm_error("SVA", "실패");
c_name : cover  property (p_name);
m_name : assume property (p_name);      // 형식 검증용

// 즉시 assertion
assert (cond) else $error("...");
"""),
        table(["함수", "의미"],
              [["$past(x, N)", "N 클럭 전의 값"],
               ["$rose(x) / $fell(x)", "상승/하강 에지"],
               ["$stable(x) / $changed(x)", "변화 없음/있음"],
               ["$onehot(x) / $onehot0(x)", "정확히 1개 / 0 또는 1개"],
               ["$countones(x)", "1인 비트 수"],
               ["$isunknown(x)", "X 또는 Z 포함"],
               ["$past(x, N, en, @(clk))", "조건부 과거값"]],
              weights=[1.4, 1.4]),

        h2("54.6  자주 쓰는 시스템 함수"),
        table(["함수", "용도"],
              [["$display / $write", "출력 (write 는 개행 없음)"],
               ["$sformatf(fmt, ...)", "문자열 조립하여 반환"],
               ["$time / $realtime", "현재 시각"],
               ["$urandom", "32비트 무작위"],
               ["$urandom_range(max, min)", "범위 내 무작위"],
               ["$random", "signed 무작위 (권장하지 않음)"],
               ["$bits(x)", "비트 폭"],
               ["$size(arr, dim)", "배열 크기"],
               ["$clog2(n)", "ceil(log2(n))"],
               ["$signed(x) / $unsigned(x)", "부호 변환"],
               ["$cast(dst, src)", "다운캐스트"],
               ["$test$plusargs(\"NAME\")", "명령행 플래그 확인"],
               ["$value$plusargs(\"N=%d\", v)", "명령행 값 추출"],
               ["$fatal / $error / $warning", "종료/에러/경고"],
               ["$assertoff / $asserton", "assertion 제어"]],
              weights=[1.6, 1.4]),
        code("plusargs_example.sv", """
int num_txn = 100;
initial begin
    void'($value$plusargs("NUM_TXN=%d", num_txn));
    if ($test$plusargs("DEBUG")) begin
        ...
    end
end
// 실행: xsim tb -R -testplusarg NUM_TXN=500 -testplusarg DEBUG
"""),
    ],
}


# ==========================================================================
CH55 = {
    "number": "CHAPTER 55",
    "title": "코딩 체크리스트",
    "goals": [
        "코드를 커밋하기 전에 점검한다",
        "리뷰 관점을 표준화한다",
        "흔한 실수를 미리 차단한다",
        "환경 품질을 정량적으로 관리한다",
    ],
    "body": [
        lead("실습 과제를 제출하기 전, 그리고 실무에서 코드를 커밋하기 전에 "
             "훑어보는 목록입니다."),

        h2("55.1  RTL 체크리스트"),
        ul("출력 폭이 최대값을 담을 수 있는가 (N비트 + N비트 = N+1비트)",
           "조합 논리에 always_comb 를 썼는가",
           "순차 논리에 always_ff 와 논블로킹(<=)을 썼는가",
           "case 에 default 가 있는가 (없으면 래치)",
           "리셋이 모든 상태 요소를 초기화하는가",
           "감지 목록에 빠진 신호가 없는가 (always_comb 면 자동)",
           "다중 드라이버가 없는가",
           "부호 있는 타입과 없는 타입을 섞지 않았는가"),

        h2("55.2  트랜잭션 (sequence_item)"),
        ul("입력에는 rand, DUT 응답에는 rand 를 붙이지 않았는가",
           "uvm_object_utils 매크로가 있는가",
           "생성자 인자가 (string name) 하나인가",
           "super.new(name) 을 호출하는가",
           "convert2string 을 구현했는가",
           "제약이 아이템에 있는가 (시퀀스마다 반복하지 않는가)",
           "불필요한 필드가 없는가 (수천 개가 만들어진다)"),

        h2("55.3  시퀀스"),
        ul("uvm_sequence #(item_type) 으로 파라미터를 지정했는가",
           "start_item -> randomize -> finish_item 순서인가",
           "randomize() 반환값을 검사하는가",
           "finish_item 을 두 번 부르지 않는가",
           "body() 를 virtual 로 선언했는가",
           "아이템을 지역 변수로 선언했는가 (클래스 필드보다 안전)",
           "type_id::create 를 쓰는가 (new 가 아니라)"),

        h2("55.4  드라이버"),
        ul("생성자 인자가 (string name, uvm_component parent) 인가",
           "build_phase 에서 vif 를 받고 실패 시 fatal 을 내는가",
           "get_next_item 과 item_done 이 1:1 인가",
           "예외 경로(return, continue)에서도 item_done 을 부르는가",
           "핀 구동에 논블로킹(<=)을 쓰는가",
           "clocking block 을 쓰는가 (또는 최소한 #1)",
           "리셋 중 동작을 처리하는가",
           "run_phase 에 virtual 을 붙였는가"),

        h2("55.5  모니터"),
        ul("vif 에 값을 쓰는 코드가 전혀 없는가 (읽기 전용)",
           "analysis_port 를 생성자에서 new 했는가",
           "리셋 중 트랜잭션을 걸러내는가",
           "샘플링 시점이 DUT 갱신 이후인가",
           "트랜잭션을 매번 새로 create 하는가 (재사용하면 덮어써진다)"),

        h2("55.6  스코어보드"),
        ul("analysis_imp 를 생성자에서 new 했는가",
           "수신 함수 이름이 write 인가",
           "비교에 !== 를 쓰는가 (X 처리)",
           "에러 메시지에 입력/기대/실제/차이가 다 있는가",
           "check_phase 에서 미처리 큐를 검사하는가",
           "report_phase 에서 비교 횟수 0 을 검사하는가",
           "핸들을 그대로 저장하지 않고 clone 하는가"),

        h2("55.7  agent / env / test"),
        ul("모든 phase 메서드에 super 호출이 있는가",
           "생성은 build_phase, 연결은 connect_phase 에 있는가",
           "create 의 두 번째 인자로 this 를 넘겼는가",
           "active/passive 를 지원하는가",
           "test 에서 objection 을 raise/drop 하는가",
           "objection 을 드라이버나 모니터에서 다루지 않는가",
           "base_test 에 공통 구성을 모았는가",
           "factory override 를 super.build_phase 전에 거는가"),

        h2("55.8  커버리지"),
        ul("covergroup 을 생성자에서 new 했는가",
           "option.per_instance = 1 을 설정했는가",
           "샘플링이 트랜잭션 단위인가 (매 클럭이 아니라)",
           "도달 불가능한 bin 을 ignore_bins 로 처리했는가",
           "illegal_bins 로 금지 조합을 감시하는가",
           "cross 의 bin 수가 현실적인가"),

        h2("55.9  제출 전 최종 확인"),
        ol("컴파일 경고가 없는가 (경고도 읽어라)",
           "회귀가 여러 시드에서 통과하는가",
           "일부러 버그를 심었을 때 환경이 잡아내는가",
           "커버리지 미달 항목마다 이유를 설명할 수 있는가",
           "print_topology 출력이 의도한 계층인가",
           "UVM_ERROR 와 UVM_FATAL 이 0인가",
           "죽은 코드와 주석 처리된 코드를 지웠는가"),

        h2("55.10  시간을 아끼는 습관"),
        table(["습관", "아끼는 시간"],
              [["smoke test 먼저 돌리기", "툴 설정 문제를 초반에 발견"],
               ["print_topology 켜두기", "계층 오류를 즉시 발견"],
               ["convert2string 구현", "로그 읽는 시간 절반"],
               ["에러 메시지에 차이값 포함", "원인 추정 즉시"],
               ["시드를 로그 이름에", "실패 재현 즉시"],
               ["TRACE 옵션 먼저 켜기", "코드 읽기 전에 원인 파악"],
               ["회귀에서 덤프 끄기", "실행 시간 3~10배"]],
              weights=[1.4, 1.4]),
    ],
}


# ==========================================================================
CH56 = {
    "number": "CHAPTER 56",
    "title": "코드 스니펫 모음",
    "goals": [
        "자주 쓰는 패턴을 복사해 쓴다",
        "보일러플레이트 작성 시간을 줄인다",
        "표준 형태를 익힌다",
    ],
    "body": [
        lead("매번 처음부터 쓰지 말고 여기서 가져다 고치세요."),

        h2("56.1  최소 UVM 환경 (한 페이지)"),
        code("minimal_uvm.sv", """
class item extends uvm_sequence_item;
    `uvm_object_utils(item)
    rand bit [7:0] data;
    function new(string name = "item"); super.new(name); endfunction
endclass

class seq extends uvm_sequence #(item);
    `uvm_object_utils(seq)
    function new(string name = "seq"); super.new(name); endfunction
    virtual task body();
        item it;
        repeat (10) begin
            it = item::type_id::create("it");
            start_item(it);
            if (!it.randomize()) `uvm_error("SEQ", "rand fail")
            finish_item(it);
        end
    endtask
endclass

class drv extends uvm_driver #(item);
    `uvm_component_utils(drv)
    virtual my_if vif;
    function new(string n, uvm_component p); super.new(n, p); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual my_if)::get(this,"","vif",vif))
            `uvm_fatal("NOVIF","")
    endfunction
    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.data <= req.data;
            seq_item_port.item_done();
        end
    endtask
endclass

class env extends uvm_env;
    `uvm_component_utils(env)
    uvm_sequencer #(item) seqr;
    drv d;
    function new(string n, uvm_component p); super.new(n, p); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = uvm_sequencer#(item)::type_id::create("seqr", this);
        d    = drv::type_id::create("d", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)
    env e;
    function new(string n, uvm_component p); super.new(n, p); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
        seq s = seq::type_id::create("s");
        phase.raise_objection(this);
        s.start(e.seqr);
        phase.drop_objection(this);
    endtask
endclass
"""),

        h2("56.2  자주 쓰는 조각"),
        h3("vif 받기 (실패 시 fatal)"),
        code("snippet_vif.sv", """
if (!uvm_config_db #(virtual my_if)::get(this, "", "vif", vif))
    `uvm_fatal("NOVIF", {"vif 를 찾을 수 없습니다: ", get_full_name()})
"""),
        h3("clone 해서 analysis_port 로"),
        code("snippet_clone.sv", """
my_item t;
if (!$cast(t, item.clone()))
    `uvm_fatal("CLONE", "clone 타입 불일치")
ap.write(t);
"""),
        h3("타임아웃 있는 대기"),
        code("snippet_timeout.sv", """
fork
    begin
        wait (done == 1'b1);
        `uvm_info("WAIT", "정상 완료", UVM_LOW)
    end
    begin
        #10000;
        `uvm_error("WAIT", "타임아웃")
    end
join_any
disable fork;
"""),
        h3("fork 안에서 루프 변수 캡처"),
        code("snippet_fork.sv", """
for (int i = 0; i < N; i++) begin
    automatic int idx = i;          // 반드시 복사
    fork
        do_something(idx);
    join_none
end
wait fork;
"""),
        h3("에러 메시지 표준 형식"),
        code("snippet_error.sv", """
`uvm_error("SCB", $sformatf(
    "[#%0d @%0t] 불일치\\n"
    "  입력  a=%0d b=%0d\\n"
    "  기대  y=%0d (0x%0h)\\n"
    "  실제  y=%0d (0x%0h)\\n"
    "  차이  %0d",
    txn_id, $time, t.a, t.b, exp, exp, t.y, t.y,
    $signed(t.y) - $signed(exp)))
"""),
        h3("스코어보드 큐 패턴"),
        code("snippet_scb_queue.sv", """
my_item exp_q[$];

function void write_in(my_item t);
    my_item e;
    $cast(e, t.clone());
    e.y = predict(t);
    exp_q.push_back(e);
endfunction

function void write_out(my_item t);
    my_item e;
    if (exp_q.size() == 0) begin
        `uvm_error("SCB", "기대값 없이 출력 관측")
        return;
    end
    e = exp_q.pop_front();
    if (t.y !== e.y) `uvm_error("SCB", "불일치")
endfunction

function void check_phase(uvm_phase phase);
    if (exp_q.size() != 0)
        `uvm_error("SCB", $sformatf("미처리 %0d건", exp_q.size()))
endfunction
"""),
        h3("커버리지 컬렉터"),
        code("snippet_cov.sv", """
class my_cov extends uvm_subscriber #(my_item);
    `uvm_component_utils(my_cov)
    my_item it;

    covergroup cg;
        option.per_instance = 1;
        cp : coverpoint it.data { bins b[8] = {[0:255]}; }
    endgroup

    function new(string n, uvm_component p);
        super.new(n, p);
        cg = new();
    endfunction

    virtual function void write(my_item t);
        it = t;
        cg.sample();
    endfunction
endclass
"""),
        h3("리셋 처리 드라이버"),
        code("snippet_reset.sv", """
virtual task run_phase(uvm_phase phase);
    fork
        forever begin
            @(negedge vif.rstn);
            reset_signals();
            @(posedge vif.rstn);
        end
        begin
            wait (vif.rstn === 1'b1);
            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        end
    join
endtask
"""),
        h3("phase 디버그 심기"),
        code("snippet_phase_dbg.sv", """
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("PH", {"build: ", get_full_name()}, UVM_NONE)
endfunction

virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info("PH", {"connect: ", get_full_name()}, UVM_NONE)
endfunction

virtual task run_phase(uvm_phase phase);
    `uvm_info("PH", {"run: ", get_full_name()}, UVM_NONE)
endtask
"""),
    ],
}


# ==========================================================================
CH57 = {
    "number": "CHAPTER 57",
    "title": "용어집",
    "goals": [
        "영문 용어와 한글 표현을 대응시킨다",
        "문서와 에러 메시지를 해석한다",
        "면접과 시험에 대비한다",
    ],
    "body": [
        lead("UVM 문서와 에러 메시지는 대부분 영어입니다. "
             "용어를 알면 검색이 훨씬 쉬워집니다."),

        h2("57.1  SystemVerilog 언어"),
        kv([("4-state", "0, 1, X, Z 네 값을 갖는 자료형. logic, reg 등"),
            ("2-state", "0, 1 만 갖는 자료형. bit, int 등"),
            ("packed", "연속된 비트 벡터로 취급되는 배열/구조체"),
            ("unpacked", "원소가 분리되어 저장되는 배열"),
            ("self-determined", "주변과 무관하게 폭이 정해지는 표현식"),
            ("context-determined", "좌변까지 포함해 폭이 정해지는 표현식"),
            ("blocking assignment", "= . 즉시 대입"),
            ("non-blocking assignment", "<= . 시간 단계 끝에 대입"),
            ("NBA region", "논블로킹 대입이 반영되는 이벤트 영역"),
            ("automatic", "호출마다 새로 생성되는 변수 수명"),
            ("static", "하나만 존재해 공유되는 변수 수명"),
            ("polymorphism", "다형성. 실제 객체 타입에 따라 메서드가 선택됨"),
            ("dynamic binding", "동적 바인딩. virtual 이 만드는 것"),
            ("downcast", "부모 핸들을 자식 핸들로. $cast 필요"),
            ("constrained random", "제약 조건 하의 무작위 생성")], 118),

        h2("57.2  UVM 구조"),
        kv([("agent", "driver, monitor, sequencer 를 묶은 프로토콜 단위"),
            ("active agent", "자극을 생성하는 agent (driver 포함)"),
            ("passive agent", "관측만 하는 agent (monitor 만)"),
            ("driver", "트랜잭션을 핀 신호로 변환하는 컴포넌트"),
            ("monitor", "핀 신호를 트랜잭션으로 복원하는 컴포넌트"),
            ("sequencer", "sequence 와 driver 사이의 중계자"),
            ("scoreboard", "기대값과 실제값을 비교하는 컴포넌트"),
            ("env", "agent 와 scoreboard 를 묶은 검증 환경"),
            ("VIP", "Verification IP. 재사용 가능한 검증 부품"),
            ("TLM", "Transaction Level Modeling. 트랜잭션 단위 통신"),
            ("analysis port", "1:N 브로드캐스트 포트"),
            ("virtual sequencer", "여러 sequencer 핸들을 모은 조율용 sequencer")], 118),

        h2("57.3  UVM 메커니즘"),
        kv([("factory", "타입을 런타임에 교체할 수 있게 하는 생성 메커니즘"),
            ("registry", "타입을 factory 에 등록하는 대리인 클래스"),
            ("type_id", "registry 의 typedef 별명"),
            ("type override", "그 타입 전체를 다른 타입으로 교체"),
            ("instance override", "특정 경로의 인스턴스만 교체"),
            ("phase", "모든 컴포넌트가 동기화되는 실행 단계"),
            ("objection", "phase 종료를 막는 카운터"),
            ("config_db", "계층 경로 기반 설정 전달 메커니즘"),
            ("resource_db", "config_db 의 하위 메커니즘"),
            ("callback", "특정 지점에 사용자 코드를 끼워 넣는 훅"),
            ("RAL", "Register Abstraction Layer. 레지스터 추상화"),
            ("adapter", "RAL 과 버스 프로토콜을 잇는 변환기"),
            ("verbosity", "로그 상세도 수준"),
            ("late randomization", "start_item 후 finish_item 전 랜덤화")], 118),

        h2("57.4  검증 방법론"),
        kv([("DUT", "Design Under Test. 검증 대상 설계"),
            ("stimulus", "자극. DUT 입력"),
            ("reference model", "기대값을 계산하는 모델. golden model"),
            ("code coverage", "RTL 코드 실행 여부 측정 (도구 자동)"),
            ("functional coverage", "설계 의도 시나리오 측정 (사람이 정의)"),
            ("coverpoint", "커버리지 측정 항목"),
            ("bin", "coverpoint 를 나눈 구간"),
            ("cross coverage", "여러 coverpoint 의 조합 측정"),
            ("SVA", "SystemVerilog Assertion"),
            ("concurrent assertion", "매 클럭 평가되는 assertion"),
            ("vacuous success", "선행 조건이 거짓이라 무의미하게 통과한 경우"),
            ("regression", "회귀 시험. 여러 시드/테스트 반복 실행"),
            ("directed test", "특정 시나리오를 겨냥한 수동 테스트"),
            ("mutation testing", "버그를 일부러 심어 환경 품질을 검증"),
            ("coverage closure", "커버리지 목표 달성"),
            ("golden reference", "정답으로 삼는 기준 모델")], 118),

        h2("57.5  자주 보는 약어"),
        table(["약어", "원말", "뜻"],
              [["UVM", "Universal Verification Methodology", "표준 검증 방법론"],
               ["OVM", "Open Verification Methodology", "UVM 의 전신"],
               ["VMM", "Verification Methodology Manual", "Synopsys 계열 전신"],
               ["TLM", "Transaction Level Modeling", "트랜잭션 수준 모델링"],
               ["RAL", "Register Abstraction Layer", "레지스터 추상화"],
               ["VIP", "Verification IP", "검증 IP"],
               ["DPI", "Direct Programming Interface", "C 연동 인터페이스"],
               ["SVA", "SystemVerilog Assertion", "SV 어서션"],
               ["LRM", "Language Reference Manual", "언어 표준 문서"],
               ["FCOV", "Functional Coverage", "기능 커버리지"],
               ["CCOV", "Code Coverage", "코드 커버리지"],
               ["REQ / RSP", "Request / Response", "요청 / 응답"]],
              weights=[0.7, 1.7, 1.2]),
    ],
}


# ==========================================================================
CH58 = {
    "number": "CHAPTER 58",
    "title": "종합 연습문제",
    "goals": [
        "전 과정의 내용을 통합해 확인한다",
        "취약한 부분을 찾는다",
        "면접과 시험에 대비한다",
    ],
    "body": [
        lead("각 문제는 앞의 어느 장과 연결됩니다. 틀린 문제의 장으로 "
             "돌아가 다시 읽으세요."),

        h2("58.1  언어 기초"),
        quiz("logic [7:0] a=200, b=100; logic [7:0] y; assign y = a+b; 의 y 값은? (2장)",
             ["① 300", "② 44", "③ 255", "④ X"],
             "② 44 — 좌변이 8비트라 계산도 8비트로 이뤄져 캐리가 소실됩니다. "
             "300 - 256 = 44."),
        quiz("DUT 출력을 받는 테스트벤치 변수를 bit 로 선언하면? (1장)",
             ["① 문제없다", "② X 가 0 으로 뭉개져 초기화 버그를 놓친다",
              "③ 컴파일 에러", "④ 폭이 32비트가 된다"],
             "② — 2-state 는 X 를 담지 못합니다. DUT 신호는 4-state 로 받으세요."),
        quiz("module 안의 task 를 fork 로 동시에 3번 호출했더니 지역 변수가 "
             "섞입니다. 원인은? (7장)",
             ["① 논블로킹 대입 문제", "② task 가 static 수명이라 변수를 공유",
              "③ 시뮬레이터 버그", "④ ref 인자 문제"],
             "② — module 안의 task 는 기본이 static 입니다. "
             "automatic 을 붙이면 호출마다 별개 변수가 됩니다."),

        h2("58.2  객체지향"),
        quiz("uvm_component::run_phase 가 virtual 이 아니라면? (10장)",
             ["① 컴파일 에러", "② 사용자가 작성한 run_phase 가 실행되지 않는다",
              "③ 성능이 좋아진다", "④ 차이 없다"],
             "② — UVM 은 부모 핸들로 호출하므로 base 의 빈 구현이 실행됩니다."),
        quiz("드라이버가 받은 아이템을 스코어보드로 보낼 때 올바른 방법은? (8장)",
             ["① ap.write(item);",
              "② $cast(t, item.clone()); ap.write(t);",
              "③ ap.write(new item);",
              "④ ap.write(item.copy());"],
             "② — clone 으로 독립 복사본을 만들어야 시퀀스가 원본을 재사용해도 "
             "안전합니다."),
        quiz("파라미터화 클래스에 uvm_object_utils 를 쓰면? (13장)",
             ["① 정상 동작", "② 에러. uvm_object_param_utils 를 써야 한다",
              "③ 경고만 난다", "④ 파라미터가 무시된다"],
             "② — 타입 이름을 문자열로 만들 수 없어 param 버전을 씁니다."),
        quiz("constraint c { en -> (d > 100); } 에서 d 가 50 이면 en 은? (15장)",
             ["① 자유", "② 반드시 0", "③ 반드시 1", "④ randomize 실패"],
             "② — 함축은 대우도 성립합니다. 솔버는 양방향으로 해석합니다."),

        h2("58.3  검증 기법"),
        quiz("스코어보드 비교에 != 대신 !== 를 쓰는 이유는? (20장)",
             ["① 더 빠르다", "② X 가 섞이면 != 는 결과가 X 가 되어 조건이 거짓",
              "③ 문법 규칙", "④ 차이 없다"],
             "② — != 는 X 를 만나면 결과가 X 입니다. if 조건이 거짓이 되어 "
             "불일치를 놓칩니다."),
        quiz("assert property (@(posedge clk) req |-> gnt); 에서 req 가 한 번도 "
             "1이 아니면? (18장)",
             ["① 실패", "② vacuous success 로 통과 처리",
              "③ 컴파일 에러", "④ 평가되지 않음"],
             "② — 선행이 거짓이면 함축은 참입니다. cover property 로 "
             "선행 발생을 따로 확인해야 합니다."),
        quiz("커버리지가 항상 0% 인 가장 흔한 원인은? (17장)",
             ["① 샘플링 시점 문제", "② 생성자에서 cg = new() 를 빠뜨림",
              "③ bins 정의 오류", "④ 시뮬레이터 설정"],
             "② — covergroup 은 자동 생성되지 않습니다. 에러도 안 나서 "
             "찾기 어렵습니다."),

        h2("58.4  UVM 핵심"),
        quiz("type_id 는 무엇인가? (24장)",
             ["① seq_item 의 다른 이름",
              "② uvm_object_registry#(seq_item,\"seq_item\") 의 typedef 별명",
              "③ 객체의 고유 번호", "④ UVM 이 부여하는 정수"],
             "② — 매크로가 심어준 typedef 입니다. 가리키는 것은 트랜잭션이 "
             "아니라 그것을 만드는 등록소입니다."),
        quiz("create(\"SEQ_ITEM\") 의 \"SEQ_ITEM\" 은 어디 쓰이는가? (25장)",
             ["① factory 장부의 Key", "② 만들어진 객체의 이름표 (로그용)",
              "③ override 대상 지정", "④ 안 쓰인다"],
             "② — 장부의 Key 는 타입 이름 \"seq_item\" 입니다. "
             "\"SEQ_ITEM\" 은 인스턴스 이름으로 new(name) 에 전달됩니다."),
        quiz("start_item 과 finish_item 사이에서 randomize 하는 이유는? (29장)",
             ["① 문법 제약", "② driver 가 대기 중인 가장 늦은 시점에 값을 확정",
              "③ 성능", "④ 관례"],
             "② — late randomization. driver 가 받을 준비된 시점의 "
             "최신 상태를 반영할 수 있습니다."),
        quiz("get_next_item 후 item_done 을 안 부르면? (30장)",
             ["① 다음 아이템이 자동으로 온다", "② 시퀀스의 finish_item 이 영원히 블록",
              "③ 에러 후 계속 진행", "④ 큐에 쌓인다"],
             "② — 시뮬레이션이 그 자리에서 멈춘 것처럼 보입니다."),
        quiz("connect_phase 가 bottom-up 인 이유는? (26장)",
             ["① 성능", "② 연결하려면 양쪽이 이미 존재해야 해서",
              "③ UVM 규칙", "④ build 의 반대라서"],
             "② — 자식이 먼저 완성되어야 부모가 연결할 수 있습니다."),
        quiz("시뮬레이션이 0ns 에 끝나는 원인은? (26장)",
             ["① objection 을 안 올림", "② objection 을 안 내림",
              "③ vif 가 null", "④ 시퀀스가 비어 있음"],
             "① — run_phase 를 붙잡는 objection 이 없으면 즉시 종료됩니다."),
        quiz("factory override 를 super.build_phase() 뒤에 걸면? (25장)",
             ["① 정상 동작", "② 컴포넌트는 이미 생성되어 override 가 안 먹는다",
              "③ 컴파일 에러", "④ sequence_item 도 안 된다"],
             "② — 컴포넌트는 super.build_phase 에서 만들어집니다. "
             "sequence_item 은 run_phase 생성이라 영향 없습니다."),
        quiz("config_db 에서 int 로 set 한 값을 bit[31:0] 으로 get 하면? (27장)",
             ["① 자동 변환", "② 실패. 타입이 정확히 같아야 한다",
              "③ 컴파일 에러", "④ 경고 후 성공"],
             "② — 타입별로 별개 저장소를 씁니다."),

        h2("58.5  실습과 확장"),
        quiz("FIFO 스코어보드의 레퍼런스 모델로 가장 적합한 것은? (50장)",
             ["① 연관배열", "② 큐 (queue)", "③ 동적 배열", "④ 고정 배열"],
             "② — 큐의 push_back / pop_front 가 FIFO 동작 그 자체입니다. "
             "추가 코드 없이 모델이 완성됩니다."),
        quiz("always_comb 안 case 에서 next 에 기본값을 안 주면? (46장)",
             ["① 컴파일 에러", "② 래치가 추론되어 경고",
              "③ 자동으로 0", "④ 문제없다"],
             "② — 모든 경로에서 할당되지 않으면 래치입니다. "
             "맨 앞에 next = state; 를 두는 것이 표준 관용구입니다."),
        quiz("$fopen 이 0을 반환했는데 검사하지 않고 진행하면? (47장)",
             ["① 런타임 에러로 즉시 멈춤", "② 조용히 아무것도 안 읽고 진행",
              "③ 빈 파일이 생성됨", "④ 컴파일 에러"],
             "② — 에러 없이 진행되어 '자극이 안 나간다'로 시간을 "
             "낭비하게 됩니다. fd 를 반드시 검사하세요."),
        quiz("grab 과 lock 의 차이는? (49장)",
             ["① grab 은 읽기 전용", "② grab 은 즉시, lock 은 차례를 기다린 뒤 독점",
              "③ 같다", "④ lock 은 해제가 불필요"],
             "② — grab 은 대기 중인 시퀀스를 제칩니다. 인터럽트 처리에 "
             "적합합니다."),
        quiz("형식 검증에서 assume 을 과하게 거는 것이 위험한 이유는? (51장)",
             ["① 느려진다", "② 증명은 통과하지만 실제 경우를 배제해 무의미해진다",
              "③ 반례를 못 찾는다", "④ 문법 오류"],
             "② — 극단적으로 '입력이 없다'고 가정하면 무엇이든 증명됩니다. "
             "cover property 로 도달 가능성을 함께 확인하세요."),
        quiz("`uvm_info 의 메시지를 미리 변수에 조립해 넘기면? (43장)",
             ["① 더 빠르다", "② verbosity 지연 평가가 무효화되어 느려진다",
              "③ 차이 없다", "④ 컴파일 에러"],
             "② — 매크로 안에서 조립해야 출력하지 않을 때 조립 비용도 "
             "건너뜁니다."),
        quiz("스코어보드를 agent 안에 두면 안 되는 이유는? (41장)",
             ["① 성능", "② DUT 별 로직이라 재사용이 안 됨",
              "③ UVM 규칙 위반", "④ 연결이 안 됨"],
             "② — agent 는 프로토콜만 알아야 합니다. '정답이 무엇인가'는 "
             "프로젝트마다 다르므로 env 레벨에 둡니다."),
        quiz("regmodel.CTRL.set(1) 만 하고 update 를 안 부르면? (40장)",
             ["① DUT 에 써진다", "② 모델의 desired 값만 바뀌고 DUT 는 그대로",
              "③ 에러", "④ mirror 가 바뀐다"],
             "② — set() 은 버스 접근을 하지 않습니다. 실제 쓰기는 "
             "update() 나 write() 가 합니다."),
        quiz("run_phase 와 main_phase 를 둘 다 쓰면? (26장)",
             ["① main 이 먼저 실행된다", "② 동시에 돌아 자극 순서가 뒤엉킨다",
              "③ 컴파일 에러", "④ run_phase 가 무시된다"],
             "② — 두 계열은 병렬로 실행됩니다. 프로젝트에서 한 계열만 "
             "쓰기로 정해야 합니다."),
        quiz("uvm_analysis_imp 대신 uvm_tlm_analysis_fifo 를 쓰는 경우는? (31장)",
             ["① 구독자가 여럿일 때", "② 수신측이 시간을 소비하며 처리해야 할 때",
              "③ 성능이 필요할 때", "④ 타입이 여러 개일 때"],
             "② — write() 는 함수라 시간을 못 씁니다. @(posedge clk) 같은 "
             "대기가 필요하면 FIFO 로 받아 task 안에서 get 합니다."),

        h2("58.6  서술형"),
        lab("서술 1",
            "sequence 와 sequence_item 의 차이를 설명하고, "
            "sequence 가 핀을 직접 구동하지 않는 것이 "
            "재사용에 어떤 이점을 주는지 서술하세요. (29장)"),
        lab("서술 2",
            "UVM 이 new() 대신 type_id::create() 를 쓰는 이유를 "
            "factory override 와 연결해 설명하세요. 그리고 이 구조를 위해 "
            "필요한 세 가지 요소(매크로, registry, factory)의 역할을 "
            "각각 한 문장으로 정리하세요. (24-25장)"),
        lab("서술 3",
            "8비트 가산기의 출력을 8비트로 선언하면 어떤 버그가 생기는지 "
            "구체적 수치와 함께 설명하고, SystemVerilog 의 표현식 폭 규칙으로 "
            "그 원인을 서술하세요. (2장)"),
        lab("서술 4",
            "virtual task, virtual class, virtual interface 세 가지 "
            "virtual 의 의미를 각각 설명하고 서로 어떻게 다른지 "
            "비교하세요. (10장, 11장, 6장)"),
        lab("서술 5",
            "스코어보드가 입력을 드라이버가 아니라 모니터에서 받아야 하는 "
            "이유를 설명하고, 드라이버에서 받으면 어떤 버그를 놓치는지 "
            "예를 드세요. (20장)"),
        lab("서술 6",
            "검증 환경이 제대로 동작하는지 확인하는 방법을 "
            "mutation testing 개념으로 설명하고, 레지스터 DUT 에 심을 수 있는 "
            "버그 세 가지와 각각을 잡아낼 검사 방법을 표로 정리하세요. (36장)"),
    ],
}


# ==========================================================================
CH59 = {
    "number": "CHAPTER 59",
    "title": "학습 로드맵과 참고자료",
    "goals": [
        "다음에 무엇을 공부할지 정한다",
        "신뢰할 만한 자료를 안다",
        "실무 진입 경로를 파악한다",
    ],
    "body": [
        lead("이 교재는 시작점입니다. 여기서 어디로 갈지 정리합니다."),

        h2("59.1  단계별 로드맵"),
        table(["단계", "목표", "확인 방법"],
              [["1. 언어", "SV 문법과 OOP 를 자유롭게 씀",
                "클래스로 간단한 TB 를 스스로 작성"],
               ["2. UVM 구조", "환경을 처음부터 만들 수 있음",
                "가산기 환경을 참고 없이 작성"],
               ["3. 메커니즘", "factory, phase, config_db 를 설명함",
                "왜 그렇게 동작하는지 설명 가능"],
               ["4. 측정", "커버리지와 assertion 을 설계함",
                "검증 계획서를 작성하고 실행"],
               ["5. 확장", "다중 인터페이스, RAL, VIP",
                "재사용 가능한 VIP 를 배포"],
               ["6. 실무", "프로토콜 검증 (AXI, PCIe 등)",
                "표준 프로토콜 VIP 를 다룸"]],
              weights=[0.9, 1.4, 1.5]),

        h2("59.2  이 교재 이후 추천 순서"),
        ol("표준 프로토콜 하나를 골라 VIP 를 직접 만든다 (APB 가 가장 쉽다)",
           "RAL 을 실제 레지스터 맵에 적용해 본다",
           "오픈소스 RTL(예: 간단한 RISC-V 코어)에 검증 환경을 붙인다",
           "커버리지 100% 를 실제로 달성해 본다 - 여기서 배우는 것이 많다",
           "형식 검증(formal) 기초를 접해 본다 - assertion 이 그대로 쓰인다"),

        h2("59.3  참고자료"),
        h3("표준 문서"),
        ul("IEEE 1800-2017 - SystemVerilog LRM. 최종 권위. 검색용으로 쓸 것",
           "UVM 1.2 Class Reference (Accellera) - 클래스별 API 문서",
           "UVM 1.2 User Guide (Accellera) - 개념 설명"),
        h3("코드"),
        ul("Vivado 설치 경로의 xlnx_uvm_package.sv - UVM 구현체 자체",
           "uvm_macros.svh - 매크로가 무엇을 만드는지 확인",
           "Accellera UVM 배포판 - src/ 아래가 파일별로 나뉘어 읽기 좋음"),
        h3("온라인"),
        ul("verificationacademy.com - 무료 강좌와 예제가 많음",
           "chipverify.com - 초보자용 정리가 잘 되어 있음",
           "edaplayground.com - 브라우저에서 UVM 코드를 바로 실행",
           "Accellera 포럼 - 표준 관련 질문"),
        note("자료를 볼 때 주의",
             "인터넷 예제는 UVM 버전이 섞여 있습니다. "
             "OVM 시절 코드(ovm_ 접두사)나 UVM 1.0 코드가 그대로 도는 경우도 "
             "있고 아닌 경우도 있습니다. 버전을 확인하세요.",
             "warn"),

        h2("59.4  실습 환경 추천"),
        table(["도구", "장점", "단점"],
              [["Vivado xsim", "무료, UVM 내장, 설치 쉬움",
                "속도 느림, 디버그 기능 제한"],
               ["EDA Playground", "설치 불필요, 여러 시뮬레이터",
                "무료 계정은 제약 있음"],
               ["Questa/ModelSim", "업계 표준, 디버그 강력",
                "라이선스 필요"],
               ["Verilator", "매우 빠름, 오픈소스",
                "UVM 지원 제한적"]],
              weights=[1.0, 1.4, 1.3]),
        tip("학습용 조합",
            "개념 확인은 EDA Playground 에서 빠르게, "
            "과제 제출용 정식 실행은 Vivado 로 하는 조합이 효율적입니다."),

        h2("59.5  면접에서 자주 나오는 질문"),
        ol("sequence 와 sequence_item 의 차이는? (29장)",
           "factory 를 왜 쓰나? new 와 무엇이 다른가? (24-25장)",
           "phase 순서를 설명하고, build 와 connect 의 방향이 다른 이유는? (26장)",
           "objection 은 무엇을 하는가? (26장)",
           "virtual interface 가 필요한 이유는? (6장)",
           "코드 커버리지와 기능 커버리지의 차이는? (17장)",
           "스코어보드에서 clone 을 쓰는 이유는? (8장)",
           "active agent 와 passive agent 의 차이와 용도는? (22장)",
           "제약 랜덤화가 방향 테스트보다 나은 점과 못한 점은? (15장)",
           "검증을 언제 끝낼 것인가? (21장)"),

        h2("59.6  마무리"),
        p("이 교재의 핵심 메시지는 하나입니다. UVM 의 규칙들은 "
          "'테스트벤치를 고치지 않고 테스트를 바꾼다'는 목표에서 나왔습니다. "
          "factory 도, phase 도, config_db 도, sequence 와 driver 의 분리도 "
          "전부 그 목표를 위한 장치입니다."),
        p("규칙을 외우려 하지 말고, 매번 '이 규칙이 없으면 무엇이 "
          "불편해지는가'를 물어보세요. 그러면 대부분 스스로 답이 나옵니다."),
        key("마지막 조언",
            "UVM 은 읽어서 익히는 것이 아니라 만들면서 익힙니다. "
            "이 교재의 실습 과제를 하나도 빠짐없이 직접 손으로 쳐 보세요. "
            "복사해서 붙이면 아무것도 남지 않습니다."),
    ],
}


CHAPTERS = [CH52, CH53, CH54, CH55, CH56, CH57, CH58, CH59]
