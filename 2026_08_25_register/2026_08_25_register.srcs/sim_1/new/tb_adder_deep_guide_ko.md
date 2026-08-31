# `tb_adder.sv` UVM 문법·동작 딥 가이드

대상 코드: `tb_adder.sv`

이 파일은 단순히 위에서 아래로 실행되는 코드가 아니다. 다음 네 종류가 한 파일 안에 섞여 있다.

| 종류 | 예 | 역할 |
|---|---|---|
| 전처리기 | `` `include``, `` `uvm_info`` | 컴파일 전에 매크로를 확장한다. |
| HDL 정적 구조 | `module`, `interface`, `always` | 시뮬레이션 시작 전에 인스턴스로 만들어진다. |
| 동적 클래스 객체 | `class`, `new`, `type_id::create()` | 시뮬레이션 도중 필요할 때 생성된다. |
| UVM 실행 구조 | phase, TLM port, factory | 생성 순서와 데이터 흐름을 관리한다. |

## 1. 전체 데이터 흐름

```text
adder_sequence
   │  rand a, b 생성
   ▼
uvm_sequencer
   │  request 전달 및 중재
   ▼
adder_driver
   │  interface의 a, b 구동
   ▼
adder DUT
   │  y 출력
   ▼
adder_monitor
   │  a, b, y 관측
   ▼
adder_scoreboard
      expected = a + b와 y 비교
```

`sequence item`, `sequence`, `sequencer`는 이름이 비슷하지만 역할이 전혀 다르다.

| 항목 | 역할 | 비유 |
|---|---|---|
| `seq_item` | 데이터 한 건 | 택배 상자 |
| `adder_sequence` | item을 만드는 시나리오 | 주문 생성기 |
| `uvm_sequencer` | 여러 sequence를 중재하여 driver에 전달 | 교통정리 담당 |

## 2. 핵심 기호 문법

### `.`과 `::`

`.`은 이미 존재하는 객체나 인스턴스의 멤버에 접근한다.

```systemverilog
adder_seq_item.a
phase.raise_objection(this)
adder_env.adder_agt.adder_sqr
```

`::`은 클래스·타입·패키지 영역에 접근한다.

```systemverilog
seq_item::type_id::create("SEQ_ITEM")
uvm_config_db#(virtual adder_if)::get(...)
```

### `#(...)`와 `#5`

```systemverilog
uvm_driver #(seq_item)
```

괄호 안에 타입이 들어가면 parameter 지정이다. 위 문장은 `seq_item`을 처리하도록 특수화된 `uvm_driver` 타입을 뜻한다.

```systemverilog
#5;
#100;
```

숫자가 바로 나오면 시간 지연이다. 현재 `` `timescale 1ns/1ps``이므로 `#5`는 5ns다.

### `@(...)`

```systemverilog
@(posedge a_vif.clk);
```

해당 신호의 상승 에지가 생길 때까지 실행을 멈춘다. 시간을 소비하므로 `task` 안에서는 가능하지만 `function` 안에서는 사용할 수 없다.

### `=`와 `<=`

```systemverilog
expected_data = data.a + data.b;
```

Blocking assignment다. 문장이 실행되는 시점에 즉시 값이 바뀐다.

```systemverilog
a_vif.a <= adder_seq_item.a;
```

Nonblocking assignment다. 새 값은 현재 문장에서 바로 적용되지 않고 해당 시간 슬롯의 NBA 영역에 예약된다.

## 3. 전처리기와 UVM 매크로

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;
```

두 문장은 역할이 다르다.

- `import uvm_pkg::*`는 `uvm_driver`, `uvm_sequence` 같은 패키지 안의 타입과 이름을 가져온다.
- `` `include "uvm_macros.svh"``는 `` `uvm_info``, `` `uvm_component_utils`` 같은 전처리기 매크로를 가져온다.
- package를 import한다고 매크로까지 자동으로 import되는 것은 아니다.

매크로는 SystemVerilog parser가 코드를 해석하기 전에 다른 코드로 확장된다.

## 4. 자료형

### `bit`과 `logic`

| 타입 | 가능한 값 |
|---|---|
| `bit` | 0, 1 |
| `logic` | 0, 1, X, Z |

```systemverilog
rand bit [7:0] a;
logic [8:0] y;
```

`a`는 8비트 2-state 랜덤 변수이고 `y`는 9비트 4-state 변수다.

주의: Monitor가 `logic` 신호의 X를 `bit` 변수에 복사하면 X가 0으로 변환될 수 있다. 따라서 관측값에서 X를 보존하려면 `rand logic [7:0] a`처럼 선언하거나 request와 observed transaction을 분리할 수 있다.

### `[7:0]`

Packed vector 범위다.

```text
[7] = MSB
[0] = LSB
총 8비트, 값의 범위 0~255
```

8비트 두 수의 최대 합은 `255 + 255 = 510`이므로 carry까지 보존하려면 결과가 9비트여야 한다.

### `rand`와 `randomize()`

`rand`는 자동으로 값이 생긴다는 뜻이 아니다. 객체에서 `randomize()`를 호출할 때 해당 필드가 랜덤화된다.

```systemverilog
if (!adder_seq_item.randomize()) begin
    `uvm_fatal("SEQ", "randomize fail")
end
```

`randomize()`는 성공 시 1, 실패 시 0을 반환한다. `!`가 결과를 반전하므로 위 조건은 “랜덤화에 실패했다면”이다.

인라인 constraint 예시:

```systemverilog
assert(adder_seq_item.randomize() with {
    a inside {[0:10]};
    b > a;
});
```

## 5. 클래스 선언과 핸들

```systemverilog
seq_item adder_seq_item;
```

왼쪽은 타입, 오른쪽은 변수 이름이다. 이 선언만으로 객체가 생기지 않는다. 클래스 변수는 객체 자체가 아니라 객체를 가리키는 핸들이므로 초기값은 `null`이다.

```systemverilog
adder_seq_item = seq_item::type_id::create("SEQ_ITEM");
```

이때 실제 객체가 생성되고 핸들이 그 객체를 가리킨다.

반면 다음 HDL 문법은 정적 인스턴스 생성이다.

```systemverilog
adder_if a_if(clk);
adder dut(...);
```

## 6. `extends`, `super`, `this`, `parent`

```systemverilog
class seq_item extends uvm_sequence_item;
```

`seq_item`이 `uvm_sequence_item`을 상속한다. 따라서 자식 객체는 직접 선언한 필드뿐 아니라 부모 클래스의 이름, transaction ID, sequence ID 등의 기능도 가진다.

```systemverilog
super.new(name);
```

`super`는 상속 관계에서 바로 위의 부모 클래스다. 여기서는 `uvm_sequence_item`의 생성자를 호출한다.

Component 생성자에서 받는 `parent`는 다른 개념이다.

```text
super  = 상속 관계의 부모 클래스
parent = UVM 인스턴스 계층에서 나를 포함하는 상위 Component
```

```systemverilog
function new(string name, uvm_component parent);
    super.new(name, parent);
endfunction
```

`this`는 현재 객체 자기 자신이다.

```systemverilog
adder_driver::type_id::create("DRV", this);
```

Agent 안에서 실행됐다면 `this`는 현재 Agent이며, 새 Driver의 계층상 parent가 된다.

Object 생성 시 전달하는 두 번째 인자는 계층 parent가 아니다.

```systemverilog
adder_sequence::type_id::create("SEQ", this);
```

Sequence는 Object이므로 UVM Component 트리에 자식으로 등록되지 않는다. 이 `this`는 Factory override 검색 문맥으로 사용된다.

## 7. UVM Object와 Component

| | `uvm_object` 계열 | `uvm_component` 계열 |
|---|---|---|
| 역할 | 데이터·명령·설정 | 검증환경의 고정 구조 |
| 현재 코드 | `seq_item`, `adder_sequence` | Driver, Monitor, Scoreboard, Agent, Env, Test |
| parent | 없음 | 있음 |
| phase | 없음 | 있음 |
| Factory 매크로 | `uvm_object_utils` | `uvm_component_utils` |

현재 Component 계층은 다음과 같다.

```text
uvm_test_top
└─ ENV
   ├─ AGT
   │  ├─ DRV
   │  ├─ MON
   │  └─ SQR
   └─ SCB
```

`run_test("adder_test")`의 문자열은 Factory에 등록된 클래스 타입 이름이다. 실제 Test 인스턴스 이름은 보통 `uvm_test_top`이다. 생성자의 기본 이름 `ADDER_TEST`와는 다르다.

## 8. `new()`와 Factory `create()`

```systemverilog
send = new("WRITE", this);
```

타입을 직접 생성한다.

```systemverilog
adder_drv = adder_driver::type_id::create("DRV", this);
```

Factory를 거쳐 생성한다. Factory override가 설정돼 있으면 호출부를 바꾸지 않고 다른 파생 클래스로 교체할 수 있다.

```systemverilog
`uvm_component_utils(adder_driver)
```

이 매크로가 타입을 Factory에 등록하고 `type_id`, `get_type_name()` 등의 기능을 생성한다.

```systemverilog
`uvm_object_utils_begin(seq_item)
    `uvm_field_int(a, UVM_DEFAULT)
    `uvm_field_int(b, UVM_DEFAULT)
    `uvm_field_int(y, UVM_DEFAULT)
`uvm_object_utils_end
```

Factory 등록과 함께 필드 automation을 설정한다. 등록된 필드는 UVM의 print/copy/compare/pack 기능에서 자동 처리될 수 있다.

## 9. `function`과 `task`

| | function | task |
|---|---|---|
| 시간 소비 | 불가능 | 가능 |
| `#10` | 불가능 | 가능 |
| `@(posedge clk)` | 불가능 | 가능 |
| 값 반환 | 가능 | 일반적으로 없음 |

그래서 `build_phase()`, `connect_phase()`, Scoreboard `write()`는 function이고, `run_phase()`와 Sequence `body()`는 task다.

`send.write()`는 function 호출이므로 현재 시뮬레이션 시간에 즉시 실행된다. Analysis port 자체에는 자동 저장 큐가 없다. 시간 지연이나 버퍼가 필요하면 `uvm_tlm_analysis_fifo` 같은 구조를 사용한다.

## 10. Phase 실행 순서

```text
run_test()
   ↓
build_phase       Component 생성과 config 조회
   ↓
connect_phase     TLM port/export 연결
   ↓
run_phase         시간이 흐르는 동작
   ↓
report_phase      결과 요약
```

`build_phase`는 일반적으로 위에서 아래 방향, `connect_phase`는 아래에서 위 방향으로 진행된다.

모든 Component의 `run_phase()`는 위에서 아래로 순차 실행되는 것이 아니라 병렬로 시작한다.

```text
test.run_phase      ─┐
driver.run_phase     ├─ 동시에 실행
monitor.run_phase    ┘
```

`phase.raise_objection(this)`는 run phase를 끝내지 말라고 알리고, `drop_objection()`은 현재 작업이 끝났다고 알린다. 모든 objection이 0이 되면 run phase가 끝난다.

Sequence의 `start()`가 끝났다는 것은 Driver가 `item_done()`을 호출했다는 뜻이지, Monitor와 Scoreboard 검사가 끝났다는 뜻은 아니다. 현재의 `#100`은 정확한 완료 동기화가 아니라 임의의 대기 시간이다.

## 11. Sequence–Sequencer–Driver 핸드셰이크

Sequence 쪽:

```systemverilog
start_item(item);
item.randomize();
finish_item(item);
```

정확한 의미는 다음과 같다.

1. `start_item()`이 Sequencer에 전송 권한을 요청하고 grant를 기다린다.
2. 권한을 받은 뒤 item을 randomize한다.
3. `finish_item()`이 item을 실제로 Sequencer에 전달한다.
4. Driver가 `item_done()`을 호출할 때까지 기다린다.

Driver 쪽:

```systemverilog
seq_item_port.get_next_item(item);
// DUT 구동
seq_item_port.item_done();
```

현재 코드의 `item_done(adder_seq_item)` 인자는 처리한 request 표시가 아니라 선택적인 response다. 응답을 사용하지 않는다면 `item_done()`이 일반적이다. response를 계속 넣고 Sequence가 `get_response()`로 꺼내지 않으면 반복 테스트에서 response queue가 쌓일 수 있다.

또한 현재 Sequence 선언은 다음과 같다.

```systemverilog
class adder_sequence extends uvm_sequence;
```

더 타입 안전한 선언은 다음과 같다.

```systemverilog
class adder_sequence extends uvm_sequence #(seq_item);
```

## 12. Virtual interface와 config DB

클래스가 실제 HDL interface 인스턴스를 가리키기 위해 virtual interface를 사용한다.

```systemverilog
virtual adder_if a_vif;
```

Top에서 실제 interface를 저장한다.

```systemverilog
uvm_config_db#(virtual adder_if)::set(
    null, "*", "a_vif", a_if
);
```

| 인자 | 의미 |
|---|---|
| `null` | UVM root 기준 |
| `"*"` | 모든 하위 경로에 적용 |
| `"a_vif"` | 설정 키 |
| `a_if` | 실제 interface 인스턴스 |

Driver와 Monitor에서 가져온다.

```systemverilog
uvm_config_db#(virtual adder_if)::get(
    this, "", "a_vif", a_vif
);
```

`get()`은 성공 시 1, 실패 시 0을 반환한다. `set()`은 반드시 `run_test()`보다 먼저 실행돼야 한다.

현재 `"*"`는 모든 Component가 같은 interface를 받게 한다. 단일 Agent 예제에는 편하지만 여러 Agent가 있으면 대상 경로를 더 구체적으로 지정하는 편이 안전하다.

## 13. Interface의 `modport`와 `clocking block`

현재 interface의 `a`, `b`, `y`에는 Driver/Monitor별 접근 방향이 없다. 따라서 컴파일러가 Driver의 `y` 쓰기나 Monitor의 `a` 쓰기를 막아주지 않는다.

`modport`는 접근 방향을 제한한다.

```systemverilog
modport DRIVER(input clk, output a, b, input y);
modport MONITOR(input clk, a, b, y);
```

`clocking block`은 같은 클럭 에지에서 발생하는 구동·샘플링 race를 막기 위해 신호의 입력/출력 skew를 정의한다.

```text
modport        = 누가 어떤 방향으로 접근하는가
clocking block = 언제 구동하고 언제 샘플링하는가
```

## 14. TLM 연결

Driver와 Sequencer는 request/complete handshake 구조다.

```systemverilog
adder_drv.seq_item_port.connect(
    adder_sqr.seq_item_export
);
```

Monitor와 Scoreboard는 analysis broadcast 구조다.

```systemverilog
uvm_analysis_port #(seq_item) send;
uvm_analysis_imp #(seq_item, adder_scoreboard) recv;
```

`uvm_analysis_imp #(seq_item, adder_scoreboard)`는 “`seq_item`을 수신하면 이 `adder_scoreboard` 객체의 `write(seq_item)`을 호출한다”는 뜻이다.

Analysis port는 여러 subscriber에 방송할 수 있지만 backpressure가 없고 `write()`는 zero-time function이다.

## 15. 객체 핸들 전달과 복제

```systemverilog
send.write(adder_seq_item);
```

객체 전체가 복사되는 것이 아니라 객체 핸들이 전달된다. Scoreboard가 즉시 읽는 현재 구조에서는 괜찮다.

하지만 Monitor가 같은 객체를 반복 재사용하고 Scoreboard가 핸들을 큐에 저장하면 큐의 모든 원소가 같은 객체를 가리킬 수 있다. 이런 경우 매 transaction마다 새 객체를 만들거나 `clone()`/`copy()`를 사용해야 한다.

## 16. Scoreboard 비교

현재 기대값 계산:

```systemverilog
expected_data = data.a + data.b;
```

carry를 명확히 보존하는 표현은 다음과 같다.

```systemverilog
expected_data =
    {1'b0, data.a} + {1'b0, data.b};
```

`{}`는 concatenation이다. `{1'b0, data.a}`는 1비트 0과 8비트 `a`를 이어 붙여 9비트를 만든다.

`==`는 피연산자에 X/Z가 있으면 결과가 X가 될 수 있다. `===`는 X/Z까지 비교하고 반드시 0 또는 1을 반환한다. 검증 코드에서는 X가 있으면 확실히 실패하도록 `===`/`!==`를 쓰기도 한다.

## 17. UVM 메시지

```systemverilog
`uvm_info("SEQ", message, UVM_MEDIUM)
```

| 인자 | 의미 |
|---|---|
| `"SEQ"` | 메시지 ID 또는 분류 |
| `message` | 출력 문자열 |
| `UVM_MEDIUM` | verbosity 수준 |

```systemverilog
$sformatf("a = %d", value)
```

포맷된 문자열을 만들어 반환하는 function이다.

| 매크로 | 의미 |
|---|---|
| `` `uvm_info`` | 정보 로그 |
| `` `uvm_warning`` | 경고 |
| `` `uvm_error`` | 오류를 기록하고 계속 실행 |
| `` `uvm_fatal`` | 치명적 오류 후 종료 |

현재 Scoreboard는 mismatch도 `` `uvm_info``로 출력한다. 따라서 `fail_cnt`가 증가해도 UVM error count는 0일 수 있고, 자동 regression이 테스트를 성공으로 판단할 수 있다. mismatch에서는 `` `uvm_error``를 쓰거나 report phase에서 `fail_cnt > 0`이면 오류를 발생시키는 편이 안전하다.

## 18. 현재 코드의 핵심 타이밍 문제

Driver와 Monitor가 같은 `posedge`를 기다린다.

Driver:

```systemverilog
@(posedge a_vif.clk);
a_vif.a <= adder_seq_item.a;
a_vif.b <= adder_seq_item.b;
```

Monitor:

```systemverilog
@(posedge a_vif.clk);
adder_seq_item.a = a_vif.a;
adder_seq_item.b = a_vif.b;
adder_seq_item.y = a_vif.y;
```

첫 상승 에지의 실행 순서는 개념적으로 다음과 같다.

```text
t=5ns posedge
├─ Driver: 새 a,b를 NBA 업데이트로 예약
├─ Monitor: 아직 바뀌지 않은 이전 a,b,y를 읽음
├─ Scoreboard: 이전 값 검사
└─ NBA: 새 a,b 적용
   └─ 이후 조합회로 y 갱신
```

따라서 Monitor는 현재 transaction이 아니라 이전 값을 읽는다. `<=`를 `=`로만 바꾸면 Driver와 Monitor의 실행 순서 race가 생기므로 완전한 해결이 아니다.

학습용 단순 구조에서는 Driver가 `negedge`에 구동하고 Monitor가 다음 `posedge`에 샘플링하도록 분리할 수 있다. 실제 환경에서는 interface clocking block과 valid/latency 정의를 사용하는 편이 안전하다.

## 19. 현재 코드는 한 번만 실행된다

Sequence가 item을 한 번만 만든다. Driver의 `get_next_item()`과 Monitor의 샘플링도 각각 한 번뿐이다. `#100`은 추가 transaction을 만드는 것이 아니라 단순히 기다릴 뿐이다.

여러 번 검증하려면 다음 세 부분이 함께 반복돼야 한다.

```text
Sequence: repeat(N)으로 N개 생성
Driver:   forever로 계속 request 수신
Monitor:  forever로 계속 관측
```

단순히 Monitor에 `forever`만 넣으면 유효하지 않은 주기나 같은 값을 중복 검사할 수 있다. transaction 유효 시점을 표시하는 valid, 예상 개수, event 또는 FIFO 기반 동기화가 필요하다.

## 20. 현재 DUT 연결 상태

테스트벤치는 다음 포트의 `adder` 모듈을 요구한다.

```systemverilog
adder dut (
    .a(a_if.a),
    .b(a_if.b),
    .y(a_if.y)
);
```

현재 `2026_08_25_register` 폴더에는 호환되는 `adder` DUT가 없고 `register.sv`가 있다.

`2026_08_24/.../adder.sv`에는 `adder`가 있지만 `y`가 8비트다. 테스트벤치는 `y`를 9비트로 기대하므로 해당 DUT를 연결하면 carry가 손실된다.

```text
200 + 100 = 300
8비트 DUT 출력 = 44
9비트 Scoreboard 기대값 = 300
결과 = FAIL
```

carry 포함 덧셈기가 요구사항이라면 DUT 출력도 9비트여야 한다.

```systemverilog
output logic [8:0] y;
assign y = {1'b0, a} + {1'b0, b};
```

## 21. 최종 암기 목록

1. `seq_item item;`은 객체 생성이 아니라 null 핸들 선언이다.
2. `super`는 상속 부모 클래스이고 `parent`는 UVM 계층의 상위 Component다.
3. `.`은 객체 멤버 접근, `::`는 타입·패키지 영역 접근이다.
4. `#(타입)`은 parameter 지정, `#숫자`는 시간 지연이다.
5. function은 시간을 소비할 수 없고 task는 기다릴 수 있다.
6. `start_item()`은 전송 권한 요청, `finish_item()`은 실제 전달과 완료 대기다.
7. `item_done(item)`의 인자는 request 표시가 아니라 선택적인 response다.
8. Sequence, sequence item, Sequencer는 서로 다른 역할이다.
9. Component의 모든 `run_phase()`는 병렬로 실행된다.
10. Analysis port의 `write()`는 즉시 호출되며 자동 큐가 아니다.
11. 같은 객체 핸들을 재사용하면 수신자가 저장한 과거 데이터도 바뀔 수 있다.
12. 현재 Driver와 Monitor는 같은 `posedge`를 사용해 Monitor가 이전 값을 읽는다.
13. 현재 Sequence/Driver/Monitor는 각각 한 번만 동작한다.
14. mismatch를 `` `uvm_info``로만 출력하면 자동 테스트에서 성공처럼 보일 수 있다.
15. 현재 발견된 `adder.sv`는 8비트 출력이라 9비트 Scoreboard와 맞지 않는다.

