`timescale 1ns / 1ps  // 시뮬레이션 시간 단위 1ns / 정밀도 1ps → 아래의 #5 는 5ns 를 뜻함

//======================================================================
// UVM adder 검증환경 데이터 흐름
//   sequence → sequencer → driver → interface → DUT
//                             interface → monitor → scoreboard(판정)
//======================================================================

`include "uvm_macros.svh"  // uvm_info, uvm_component_utils 같은 UVM 매크로 정의를 끌어옴
import uvm_pkg::*;  // UVM 라이브러리(uvm_driver, uvm_sequence ...)를 접두어 없이 바로 쓰도록 import

//----------------------------------------------------------------------
// 0. interface : DUT 와 검증환경(클래스)을 잇는 신호 묶음
//----------------------------------------------------------------------
interface adder_if (
    input bit clk  // TB 에서 만든 클럭을 받아옴. driver/monitor 가 이 clk 에 동기화됨
);

    logic [7:0] a;  // 피연산자 A. driver 가 값을 쓰고(write), monitor 가 읽음(read)
    logic [7:0] b;  // 피연산자 B. 위와 동일
    logic [8:0] y;  // 덧셈 결과. 8비트+8비트는 캐리까지 9비트가 필요해서 [8:0]

endinterface

//----------------------------------------------------------------------
// 1. transaction : 테스트 한 번에 오가는 데이터 한 묶음
//----------------------------------------------------------------------
class seq_item extends uvm_sequence_item;  // UVM 트랜잭션의 부모 클래스를 상속
    rand bit [7:0] a;  // rand → randomize() 호출 시 무작위 값이 채워짐 (DUT 에 넣을 자극)
    rand bit [7:0] b;  // 위와 동일. 이 둘이 driver 를 거쳐 DUT 입력으로 나감
    logic    [8:0] y;  // 결과는 DUT 가 만드는 값이라 rand 아님. monitor 가 관측해서 채워줌

    function new(string name = "ADDER_Seq_item");  // 생성자. uvm_object 계열이라 parent 인자가 없고 이름만 받음
        super.new(name);  // 여기 super 는 "부모 클래스"(uvm_sequence_item) 의 생성자. 위의 parent 와는 다른 개념
    endfunction

    `uvm_object_utils_begin(seq_item)  // factory 등록 시작 → type_id::create() 로 생성 가능해짐
        `uvm_field_int(a, UVM_DEFAULT)  // a 를 UVM 필드로 등록 → print/copy/compare 가 자동 지원됨
        `uvm_field_int(b, UVM_DEFAULT)  // b 도 동일하게 등록
        `uvm_field_int(y, UVM_DEFAULT)  // y 도 동일하게 등록
    `uvm_object_utils_end  // factory 등록 끝

endclass

//----------------------------------------------------------------------
// 2. sequence (generator) : seq_item 을 만들어 sequencer 로 흘려보냄
//----------------------------------------------------------------------
class adder_sequence extends uvm_sequence;  // 시나리오를 기술하는 클래스. component 가 아닌 object
    // factory registry
    `uvm_object_utils(adder_sequence)  // object 용 factory 등록 매크로
    seq_item adder_seq_item;  // 만들어 보낼 트랜잭션 핸들. 아직 객체는 없고 null 상태

    function new(string name = "ADDER_Sequence");  // seq_item 과 같은 uvm_object 계열 → parent 인자 없이 이름만
        super.new(name);  // 부모 클래스(uvm_sequence) 의 생성자 호출
    endfunction

    task body();  // sequence 의 본체. start() 하면 UVM 이 이 task 를 실행함
        adder_seq_item =
            seq_item::type_id::create("SEQ_ITEM");  // factory 로 트랜잭션 실제 생성 (new() 대신 쓰는 UVM 방식)
        start_item(adder_seq_item);  // sequencer 에 "보낼 준비 됐다" 알리고 driver 가 받을 때까지 대기
        // randomize
        if (!adder_seq_item.randomize()) begin  // a, b 에 무작위 값 채움. 실패하면 0 을 리턴
            `uvm_fatal("SEQ", "adder_seq_item randomized fail")  // 랜덤화 실패는 치명적 → 시뮬레이션 즉시 종료
        end
        // message output : to TCL consol, log
        // sformatf : function 이라 리턴값 있음 / sformat : task 라 리턴값 없음
        `uvm_info("SEQ", $sformatf(" a = %d, b = %d", adder_seq_item.a,  // 생성된 자극 값을 로그로 출력
                                   adder_seq_item.b), UVM_MEDIUM)  // UVM_MEDIUM : 기본 verbosity 에서 보이는 등급
        finish_item(adder_seq_item);  // driver 의 item_done() 을 기다림. 이게 풀려야 다음 아이템으로 진행
    endtask

endclass

//----------------------------------------------------------------------
// 3. driver : seq_item 을 받아 실제 인터페이스 신호로 구동
//----------------------------------------------------------------------
class adder_driver extends uvm_driver #(seq_item);  // #(seq_item) : 이 driver 가 다룰 트랜잭션 타입 지정
    // factory registry : class uvm_driver
    `uvm_component_utils(adder_driver)  // component 용 factory 등록 (object 용과 매크로가 다름)
    seq_item adder_seq_item;  // sequencer 에서 받아올 트랜잭션을 담을 핸들


    // virtual interface
    virtual adder_if    a_vif;  // 클래스에서 모듈의 실제 신호에 접근하는 통로(핸들)

    function new(string name = "ADDER_DRV", uvm_component c = null);  // uvm_component 계열이라 parent(c) 를 추가로 받음
        super.new(name, c);  // 부모 클래스 생성자 호출. 넘긴 c 가 UVM 계층 트리에서 나의 상위 컴포넌트가 됨
    endfunction

    // build phase. configuration component
    function void build_phase(uvm_phase phase);  // build_phase : 객체 생성/설정 단계 (위 → 아래 순서로 실행)
        super.build_phase(phase);  // 부모 build_phase 를 먼저 실행
        // interface connect
        if (!uvm_config_db#(virtual adder_if)::get(  // config_db 에서 top 이 넣어둔 인터페이스를 꺼냄
                this, "", "a_vif", a_vif  // this=나 / ""=추가경로 없음 / "a_vif"=키 이름 / a_vif=받을 변수
            )) begin  // get 이 0 을 리턴하면 인터페이스 연결 실패
            `uvm_fatal(get_name(), "unable to access adder interface")  // 인터페이스 없으면 구동 불가 → 즉시 종료
        end
    endfunction

    // run phase.
    task run_phase(uvm_phase phase);  // run_phase : 시뮬레이션 시간이 실제로 흐르는 단계 (컴포넌트들이 병렬 실행)
        // to drive to interface
        // get seq_item
        // handshake
        seq_item_port.get_next_item(adder_seq_item);  // sequencer 에 아이템 요청. 올 때까지 블로킹 (핸드셰이크 1단계)

        @(posedge a_vif.clk);  // 클럭 상승엣지까지 대기 → 신호를 동기적으로 인가하기 위함
        a_vif.a <= adder_seq_item.a;  // 트랜잭션의 a 를 인터페이스 신호 a 로 구동 (논블로킹 대입)
        a_vif.b <= adder_seq_item.b;  // 트랜잭션의 b 를 인터페이스 신호 b 로 구동


        // done to use
        seq_item_port.item_done(adder_seq_item);  // "다 썼다" 통보 → sequence 의 finish_item() 이 풀림 (핸드셰이크 2단계)
    endtask

endclass

//----------------------------------------------------------------------
// 4. monitor : 인터페이스를 관측만 해서 scoreboard 로 방송
//----------------------------------------------------------------------
class adder_monitor extends uvm_monitor;  // 신호를 구동하지 않고 읽기만 하는 수동 컴포넌트
    `uvm_component_utils(adder_monitor)  // component 용 factory 등록

    // broadcasting
    uvm_analysis_port #(seq_item) send;  // analysis port : 1:N 방송용 출구. 관측 결과를 여기로 내보냄
    virtual adder_if              a_vif;  // 관측 대상 인터페이스 핸들
    seq_item                      adder_seq_item;  // 관측값을 담아 보낼 트랜잭션 핸들

    function new(string name = "ADDER_MON", uvm_component c = null);  // 생성자
        super.new(name, c);  // 부모 생성자 호출
        send = new("WRITE", this);  // analysis port 는 factory 가 아니라 그냥 new 로 생성
    endfunction

    // build phase
    function void build_phase(uvm_phase phase);  // 객체 생성/설정 단계
        super.build_phase(phase);  // 부모 먼저 실행
        if (!uvm_config_db#(virtual adder_if)::get(  // driver 와 똑같이 인터페이스를 꺼내옴
                this, "", "a_vif", a_vif  // 같은 키("a_vif")로 조회 → driver 와 같은 인터페이스를 공유
            )) begin  // 조회 실패 시
            `uvm_fatal(get_name(), "unable to access adder interface")  // 관측 불가 → 즉시 종료
        end
    endfunction

    // run phase
    task run_phase(uvm_phase phase);  // 실제 관측을 수행하는 단계
        // adder_seq_item new
        // check...
        adder_seq_item = seq_item::type_id::create("SEQ_ITEM");  // 관측값을 담을 트랜잭션 생성

        @(posedge a_vif.clk);  // 클럭 엣지에 맞춰 샘플링
        adder_seq_item.a = a_vif.a;  // 인터페이스의 a 를 읽어 담음
        adder_seq_item.b = a_vif.b;  // 인터페이스의 b 를 읽어 담음
        adder_seq_item.y = a_vif.y;  // DUT 가 만든 결과 y 를 읽어 담음 (이게 검증 대상)
        send.write(adder_seq_item);  // analysis port 로 방송 → 연결된 scoreboard 의 write() 가 호출됨
        // sformatf : function 이라 리턴값 있음 / sformat : task 라 리턴값 없음
        `uvm_info("MON", $sformatf(" a = %d, b = %d", adder_seq_item.a,  // 관측한 값을 로그로 출력
                                   adder_seq_item.b), UVM_MEDIUM)  // verbosity 등급
    endtask

endclass

//----------------------------------------------------------------------
// 5. scoreboard : 기대값과 실제값을 비교해 PASS/FAIL 판정
//----------------------------------------------------------------------
class adder_scoreboard extends uvm_scoreboard;  // 판정 담당 컴포넌트
    `uvm_component_utils(adder_scoreboard)  // component 용 factory 등록
    uvm_analysis_imp #(seq_item, adder_scoreboard) recv;  // analysis imp : 방송을 받는 입구. write() 구현을 강제함
    // check
    function new(string name = "ADDER_SCB", uvm_component c = null);  // 생성자
        super.new(name, c);  // 부모 생성자 호출
        recv = new("READ", this);  // imp 도 new 로 생성. this 를 넘겨야 내 write() 가 불림
    endfunction

    bit [8:0] expected_data = 0;  // 소프트웨어로 계산한 기대 결과 (레퍼런스 모델 역할)
    int pass_cnt = 0, fail_cnt = 0;  // 통과/실패 횟수를 세는 카운터

    function void write(seq_item data);  // monitor 가 send.write() 하면 자동 호출되는 콜백
        // pass/fail decition
        expected_data = data.a + data.b;  // 기대값 계산 : DUT 와 무관하게 직접 더한 정답
        if (expected_data == data.y) begin  // DUT 결과 y 와 기대값을 비교
            `uvm_info("SCB", $sformatf(" PASS : a = %d, b = %d, y = %d",  // 일치 → PASS 로그 출력
                                       data.a, data.b, data.y), UVM_MEDIUM)  // 실제 값들을 함께 남김
            pass_cnt++;  // 통과 카운트 증가
        end else begin  // 불일치인 경우
            `uvm_info("SCB", $sformatf(  // FAIL 로그 출력
                      " Fail : a = %d, b = %d, y = %d", data.a, data.b, data.y),  // 어떤 입력에서 틀렸는지 기록
                      UVM_MEDIUM)  // verbosity 등급
            fail_cnt++;  // 실패 카운트 증가
        end
    endfunction

    function void report_phase(uvm_phase phase);  // report_phase : 시뮬레이션이 끝난 뒤 결과를 요약하는 단계
        `uvm_info("SCB", $sformatf(  // 최종 집계 출력
                  " === PASS : %d === \n === FAIL : %d", pass_cnt, fail_cnt),  // \n 으로 두 줄로 나눠 출력
                  UVM_MEDIUM)  // verbosity 등급
        if (!(pass_cnt + fail_cnt))  // no transaction. 통과도 실패도 0 이면 아무것도 안 들어온 것
            `uvm_error("SCB", "No transaction received !!!")  // 조용히 통과한 것처럼 보이는 함정을 잡아줌
    endfunction

endclass

//----------------------------------------------------------------------
// 6. agent : driver + monitor + sequencer 를 한 덩어리로 묶은 단위
//----------------------------------------------------------------------
class adder_agent extends uvm_agent;  // uvm_agent 상속
    `uvm_component_utils(adder_agent)  // component 용 factory 등록

    adder_driver    adder_drv;  // 하위 컴포넌트 핸들 : driver
    adder_monitor   adder_mon;  // 하위 컴포넌트 핸들 : monitor
    uvm_sequencer   #(seq_item) adder_sqr;  // sequencer 는 UVM 기본 클래스를 그대로 사용 (따로 만들 필요 없음)

    function new(string name = "ADDER_AGT", uvm_component c = null);  // 생성자
        super.new(name, c);  // 부모 생성자 호출
    endfunction

    function void build_phase(uvm_phase phase);  // 하위 컴포넌트를 실제로 생성하는 단계
        super.build_phase(phase);  // 부모 먼저 실행
        adder_drv = adder_driver::type_id::create("DRV", this);  // driver 생성. this 를 부모로 지정
        adder_mon = adder_monitor::type_id::create("MON", this);  // monitor 생성
        adder_sqr = uvm_sequencer#(seq_item)::type_id::create("SQR", this);  // sequencer 생성
    endfunction

    function void connect_phase(uvm_phase phase);  // connect_phase : 포트를 잇는 단계 (아래 → 위 순서로 실행)
        super.connect_phase(phase);  // 부모 먼저 실행
        adder_drv.seq_item_port.connect(adder_sqr.seq_item_export);  // driver 의 요청 포트를 sequencer 의 공급 포트에 연결
    endfunction

endclass

//----------------------------------------------------------------------
// 7. environment : agent + scoreboard 를 묶은 검증환경
//----------------------------------------------------------------------
class adder_environment extends uvm_env;  // uvm_env 상속
    `uvm_component_utils(adder_environment)  // component 용 factory 등록

    adder_agent adder_agt;  // 하위 : agent (자극 구동 + 관측 담당)
    adder_scoreboard adder_scb;  // 하위 : scoreboard (판정 담당)

    function new(string name = "ADDER_ENV", uvm_component c = null);  // 생성자
        super.new(name, c);  // 부모 생성자 호출
    endfunction

    function void build_phase(uvm_phase phase);  // 하위 컴포넌트 생성 단계
        super.build_phase(phase);  // 부모 먼저 실행
        adder_agt = adder_agent::type_id::create("AGT", this);  // agent 생성 → 그 아래 drv/mon/sqr 가 이어서 생성됨
        adder_scb = adder_scoreboard::type_id::create("SCB", this);  // scoreboard 생성
    endfunction

    function void connect_phase(uvm_phase phase);  // 포트 연결 단계
        super.connect_phase(phase);  // 부모 먼저 실행
        adder_agt.adder_mon.send.connect(adder_scb.recv);  // monitor 의 analysis port 를 scoreboard 의 imp 에 연결
    endfunction

endclass

//----------------------------------------------------------------------
// 8. test : 최상위 시나리오. run_test() 가 여기서 시작됨
//----------------------------------------------------------------------
class adder_test extends uvm_test;  // UVM 계층의 꼭대기 클래스
    `uvm_component_utils(adder_test)  // factory 등록. run_test 가 이름 문자열로 찾아 생성함

    adder_sequence    adder_seq;  // 실행할 시나리오(sequence) 핸들
    adder_environment adder_env;  // 검증환경(env) 핸들

    function new(string name = "ADDER_TEST", uvm_component c = null);  // 생성자
        super.new(name, c);  // 부모 생성자 호출
    endfunction

    function void build_phase(uvm_phase phase);  // 객체 생성 단계
        super.build_phase(phase);  // 부모 먼저 실행

        adder_seq = adder_sequence::type_id::create("SEQ", this);  // sequence 생성. object 라서 이 this 는 계층 부모가 아니라 factory override 조회용 문맥(context)
        adder_env = adder_environment::type_id::create("ENV", this);  // env 생성 → 아래 계층이 줄줄이 생성됨
    endfunction

    task run_phase(uvm_phase phase);  // 실제 시나리오를 돌리는 단계
        // start run phase
        phase.raise_objection(this);  // objection 올림 = "아직 안 끝났으니 시뮬레이션 끝내지 마"
        adder_seq.start(adder_env.adder_agt.adder_sqr);  // sequence 를 sequencer 에 붙여 실행 → body() 가 돌아감
        #100;  // 결과가 나올 시간을 벌어줌 (없으면 판정 전에 끝나버림)
        // stop run phase
        phase.drop_objection(this);  // objection 내림 = "끝났다". 모든 objection 이 0 이면 run_phase 종료
    endtask

endclass

//----------------------------------------------------------------------
// 9. top module : 클럭 생성 + DUT 연결 + UVM 시동
//----------------------------------------------------------------------
module tb_adder_uvm ();  // 시뮬레이션 최상위 모듈. 포트 없음
    logic clk = 0;  // 클럭 신호. 0 으로 초기화
    always #5 clk = ~clk;  // 5ns 마다 반전 → 주기 10ns(100MHz) 클럭 생성
    adder_if a_if (clk);  // 인터페이스 인스턴스화. 위에서 만든 clk 을 물려줌


    adder dut (  // 검증 대상(DUT) 인스턴스
        .a(a_if.a),  // DUT 입력 a 를 인터페이스 신호에 연결 (driver 가 여기에 씀)
        .b(a_if.b),  // DUT 입력 b 를 인터페이스 신호에 연결
        .y(a_if.y)  // DUT 출력 y 를 인터페이스 신호에 연결 (monitor 가 여기서 읽음)
    );

    initial begin  // 시뮬레이션 시작 시 딱 한 번 실행되는 블록
        uvm_config_db#(virtual adder_if)::set(null, "*", "a_vif", a_if);  // 인터페이스를 config_db 에 등록. "*" = 모든 컴포넌트가 꺼내 쓸 수 있게
        run_test("adder_test");  // UVM 시동. adder_test 를 factory 로 생성하고 phase 를 순서대로 실행
    end


endmodule
