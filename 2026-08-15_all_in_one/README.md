# 통합 프로젝트 (스톱워치 + 시계 + SR04 + DHT11 + UART/FIFO)

지금까지 만든 모듈을 블록도대로 하나의 `top` 으로 합친 것.
Basys3 (xc7a35tcpg236-1) / 100MHz 기준.

```
 BTN --> [BTN_UNIT] ------------+
                                v
 PC <--UART--> [UART_COMM] --> [CONTROL_UNIT] <-- SW
                   ^              |
                   |              +--> [TIME_DATAPATH] --+
                   |              |     스톱워치+시계     |
                   |              +--> [SENSOR_UNIT] ----+--> 표시값
                   |                    SR04+DHT11       |
                   +------------------------------------+|
                                                         v
                                      [FND_DISPLAY] --> FND
                                      [LED_STATUS]  --> LED
```

## 파일

| 파일 | 내용 |
|---|---|
최상위 `top.v` 는 배선만 한다. 아래 **블록 7개**가 RTL 스키매틱에 그대로 상자로 나온다.

| 파일 (블록) | 내용 |
|---|---|
| `top.v` | 최상위. 리셋 동기화 + 블록 배선만 |
| `btn_unit.v` | **블록** `btn_debounce` x4 |
| `uart_comm.v` | **블록** `uart_fifo` + `ascii_decoder` + `ascii_sender` + 송신 타이밍 |
| `main_control_unit.v` | **블록** Control Unit + `control_unit_stopwatch` + `control_unit_watch` |
| `time_datapath.v` | **블록** `stopwatch_datapath` + `watch_datapath` + 표시값 선택 |
| `sensor_unit.v` | **블록** `sr04_controller` + `dht11_controller` + 값/valid 래치 |
| `fnd_display.v` | **블록** 자리수 분리 + 모드 MUX + `fnd_controller` |
| `led_status.v` | **블록** LED 표시 (조합회로) |

하위 모듈 (위 블록 안에 들어감)

| 파일 | 내용 |
|---|---|
| `uart_fifo.v` | UART_FIFO 블록 (rx/tx + FIFO 2개 + baud tick) |
| `uart.v` | `baud_tick_gen`, `uart_rx`, `uart_tx` |
| `fifo.v` | `fifo`, `register_file`, `fifo_control_unit` |
| `ascii_decoder.v` | 수신 바이트 -> 명령 펄스 |
| `ascii_sender.v` | 현재 모드 값 -> ASCII 문자열 -> TX FIFO |
| `stopwatch_datapath.v` | 스톱워치 |
| `watch_datapath.v` | 시계 |
| `tick_gen.v` | `tick_gen_1us`, `tick_gen_100hz`, `periodic_pulse`, `time_counter` |
| `sr04_controller.v` | HC-SR04 |
| `dht11_controller.v` | DHT11 |
| `fnd_controller.v` | 통합 FND (4자리 digit + dot 인터페이스) |
| `btn_debounce.v` | 버튼 디바운스 |
| `top.xdc` | Basys3 핀 제약 |

폴더

| 폴더 | 내용 |
|---|---|
| `tb/` | 테스트벤치 전부. 모듈 하나당 하나, 무작위 자가검증. 등록용 `add_tb.tcl` 도 여기 |
| `tb_legacy/` | 블록 단위로만 있던 예전 테스트벤치. 모듈 이름이 겹치므로 같이 컴파일하지 말 것 |
| `sim_work/` | `run_tests.bat` 이 만드는 작업 폴더 (로그) |

## 테스트벤치

전부 **`tb/` 폴더**에 있다. 설계 파일과 완전히 분리했다.
**모듈 34개에 하나씩**, 서로 독립이라 아무거나 하나만 Set as Top 해도 그것만 돌아간다.
전부 무작위 자극 + 자가 검증(self-checking)이라 마지막 줄만 보면 된다.

```
=====================================================
  tb_fifo : ALL PASS  (checks=27105, seed=253690147)
=====================================================
```

- 어떤 테스트벤치가 무엇을 무작위로 만들고 무엇을 검사하는지는
  **[`tb/README.md`](tb/README.md)** 의 표에 모듈별로 정리돼 있다.
- 무작위 씨앗은 각 파일의 `seed0` 하나만 바꾸면 완전히 다른 자극이 나온다.
  실행 결과에 씨앗을 같이 찍으므로 실패한 패턴을 그대로 재현할 수 있다.
- 시뮬 시간을 줄이려고 파라미터를 축소해서 인스턴스한다 (보드레이트 625k,
  "1us" = 2~4클럭, 100Hz tick = 12클럭 등). 로직은 그대로고 카운터 상수만 작아진다.

### Vivado 에서

한 번만 등록하면 된다. Vivado 의 **Tcl Console** 에서

```tcl
source d:/work/26_AI_COMP_1/2026-08-15_all_in_one/tb/add_tb.tcl
```

`tb/*.v` 를 전부 Simulation Sources 로 넣고, 시뮬레이션 실행 시간을 `all` 로 바꿔 준다
(기본값 1000ns 로는 대부분의 테스트벤치가 끝까지 못 간다).

그 다음부터는 Sources > Simulation Sources 에서 돌릴 것을 **Set as Top** 하고
Run Behavioral Simulation 하면 된다.

### 명령줄에서

```
run_tests.bat                  전부 돌리기
run_tests.bat tb_sensor_unit   하나만
```

결과는 `sim_work\<테스트벤치>.log` 에 남고 마지막에 PASS/FAIL 요약이 나온다.
직접 돌릴 때는:

```
xvlog *.v tb\*.v
xelab -s sim tb_sensor_unit
xsim sim -R
```

> 블록 단위로만 있던 예전 테스트벤치는 `tb_legacy/` 에 그대로 두었다.
> 지금 것과 모듈 이름이 겹치므로 **같이 컴파일하면 안 된다.**

### 통합 테스트벤치에서 원하는 항목만 돌리기

`tb_top.v` 맨 위의 `define 줄을 주석 처리하면 그 구간이 통째로 빠진다.
시나리오뿐 아니라 거기 딸린 센서 동작 모델까지 같이 빠져서 시뮬 시간도 줄어든다.

```verilog
//`define RUN_STOPWATCH
//`define RUN_WATCH
//`define RUN_SR04
`define RUN_DHT11      // <- DHT11 만 돌린다

`define SHOW_TX        // UART 송신 문자열 콘솔 출력. 필요 없으면 주석 처리.
```

| 설정 | 시뮬 시간 |
|---|---|
| 전부 켬 | 6.27 ms |
| DHT11 만 | 3.35 ms |
| SR04 만 | 2.01 ms |
| 스톱워치만 + `SHOW_TX` 끔 | 0.84 ms |

네 시나리오는 서로 독립이라 아무 조합이나 꺼도 나머지가 그대로 돈다.

### 테스트벤치 작성 시 주의
(자세한 규칙은 [`tb/README.md`](tb/README.md) 맨 아래에 정리해 뒀다)
- **자극은 `@(negedge clk)` 에서 준다.** DUT 는 posedge 에서 읽으므로 이미 안정된
  값을 본다. 엣지와 같은 시각에 값을 바꾸면 그 엣지에서 볼지 다음 엣지에서 볼지가
  시뮬레이터 실행 순서에 달려서, 한 번 준 펄스가 두 번 먹거나 아예 안 먹는다.
- **스코어보드는 `@(posedge clk)` 에서 엣지 직전값을 본다.** DUT 도 참조 모델도
  nonblocking 이라 둘 다 반영 전 값이 읽혀서 서로 비교가 된다.
- 한글 메시지는 `$display` 의 포맷 문자열에 직접 쓴다. reg 에 담아 `%0s` 로
  넘기면 xsim 이 깨뜨린다.

## 조작법

### 스위치
| 스위치 | 기능 |
|---|---|
| `sw[0]` | 표시모드 (시계류: 0 = `SS.mm` 초.밀리초, 1 = `HH.MM` 시.분) |
| `sw[1]` | 시계 |
| `sw[2]` | SR04 (거리) |
| `sw[3]` | DHT11 (온습도) |
| `sw[15]` | reset |

`sw[3:1]` 이 모드 선택으로 one-hot. 여러 개 켜지면 **낮은 번호가 우선**,
**전부 내리면 스톱워치**(스톱워치는 전용 스위치 없는 기본 모드).
`sw[0]` 은 모드와 무관하게 표시 형식만 바꾼다.

### 버튼 (현재 모드에만 전달됨)
| 모드 | L | R | U | D | C |
|---|---|---|---|---|---|
| 스톱워치 | Run/Stop 토글 | Clear | 업/다운 카운트 전환 | - | - |
| 시계 | 편집자리 ← | 편집자리 → | +1 | -1 | Clear |
| SR04 / DHT11 | **1회 측정** | - | - | - | - |

센서는 자동 주기 측정을 하지 않는다. 해당 스위치를 올린 상태에서 `L` 을 누른
그 순간에만 한 번 측정하고, 측정값은 다음 측정 전까지 화면에 유지된다.
버튼을 길게 누르고 있어도 재측정되지 않는다(1클럭 펄스 트리거).

### UART (9600 8N1)
| 문자 | 동작 |
|---|---|
| `r` / `s` | 스톱워치 RUN / STOP |
| `c` | Clear |
| `m` | 스톱워치 업/다운 카운트 전환 |
| `U` / `D` | 시계 +1 / -1 |
| `L` / `R` | 시계 편집자리 이동 |
| `S` / `M` / `H` | 시계 편집자리 직접 선택 (초/분/시) |
| `t` | 센서 수동 측정 |

송신 (1초마다 + 센서 측정 완료마다):

```
STOPWATCH / WATCH : 12:34:56.78
SR04              : DIST 123cm
DHT11             : H 60% T 25C
```

### LED
`led[3:0]` 현재 모드 / `led[5:4]` 시계 편집자리 / `led[6]` DHT11 체크섬 정상 / `led[7]` 스톱워치 동작중

## 배선

- SR04 : `trigger` = JB1(A14), `echo` = JB2(A16)
  - **SR04 는 5V 센서다.** echo 를 그대로 FPGA 에 물리면 안 되고 분압저항(1k/2k 등)으로 3.3V 로 낮출 것
- DHT11 : `dht11_io` = JC1(K17), 풀업 4.7k (모듈에 붙어있으면 생략)

## 통합하면서 고친 것

이름이 겹치거나 그대로는 한 프로젝트에 못 들어가던 것들:

1. **`fnd_controller` 2종 통합** — 시계용(msec/sec/min/hour)과 센서용(`fnd_in[15:0]`)이
   `clk_div` / `bcd` / `decoder_2x4` 를 같은 이름 다른 내용으로 각각 정의하고 있었음.
   "4자리 digit + dot" 인터페이스 하나로 합치고 자리수 분리는 `top` 에서 모드별로 처리.
   센서용 `digit_spliter` 는 거리 400cm 에서 `digit_10 = 40` 이 되어 4비트를 넘쳤음.
2. **`control_unit` 이름 충돌** — FIFO 내부 포인터 제어기를 `fifo_control_unit` 으로 rename.
3. **`tick_gen` 이름 충돌** — SR04용(run_stop/clear 있음) / DHT11용(없음) 을
   `tick_gen_1us` 하나로 통합. DHT11 은 `run_stop=1, clear=0` 으로 연결.
4. **`ila_1` 제거** — `sr04_controller` 에 Vivado ILA IP 인스턴스가 박혀 있어서
   IP 없는 프로젝트에선 elaborate 자체가 실패했음.
5. **파생 클럭 제거** — `btn_debounce` / `fnd_controller` 가 분주 클럭을
   `always @(posedge oclk)` 에 직접 물고 있던 것을 클럭 인에이블로 변경. clk 단일 도메인.
   디바운스 샘플 주기도 1us -> 1ms 로 늘림 (8ms 안정 후 인정).
6. **암시적 wire** — `watch_datapath` 의 `w_tick_sec/min/hour`,
   `dht_controller` 의 `tick_us` 를 명시 선언.

시뮬레이션/합성 돌리면서 잡힌 실제 버그:

7. **FND 점 점멸이 안 먹던 것** — `mux_8x1` 의 3비트 `sel` 에
   `{w_dot_onoff, w_digit_sel}` (4비트) 를 연결해서 `w_dot_onoff` 가 잘려나갔음.
   dp 는 세그먼트 bit7 을 직접 끄는 방식으로 변경.
8. **ASCII Sender 문자 유실** — `tx_full` 을 N클럭에 보고 push 를 N+1클럭에 내보내서,
   그 사이 FIFO 가 full 이 되면 `we = push & ~full` 로 바이트가 조용히 버려졌음
   (`"H 60% T 25C"` -> `"H 60%T2C"`). push 를 조합 출력으로 바꿔 확인한 그 클럭에 밀어넣도록 수정.
9. **DHT11 SYNC->DATA 레이스** — 싱크2(80us High)를 카운트로 넘어가는데,
   그 카운트가 실제 센서보다 조금 먼저 끝나면 DATA 진입 시 라인이 아직 High 라서
   "50us Low 대기" 를 통과해버리고 비트가 한 칸씩 밀림 -> 체크섬 항상 실패.
   하강엣지 기준으로 변경.
10. **SR04 거리 1cm 낮게 + 타이밍 위반** — `count_reg / 58` 이 15단 캐리체인이 되어
    100MHz 를 못 맞췄음 (WNS -3.32ns). `1/58 ≈ 1130/65536` 곱셈+쉬프트로 교체하고
    반올림(+32768) 추가. DSP48 1개로 매핑되고 WNS +3.75ns 로 통과.
11. **센서 done 전송이 한 측정 뒤처짐** — done 이 뜨는 엣지에 값 레지스터도 갱신되는데
    같은 엣지에 전송을 시작해서 옛날 값을 래치했음. done 을 1클럭 지연.
12. **SR04 / DHT11 무응답 hang** — 센서 미연결 시 `WAIT` 상태에 영구히 갇혔음. 타임아웃 추가.

## 검증 결과

```
xvlog / xelab           : 에러 0
synth_design (xc7a35t)  : 0 errors, 0 critical warnings, 0 warnings (latch 없음)
timing (100MHz)         : WNS +3.748ns, 실패 endpoint 0
utilization             : 899 LUT / 594 FF / DSP 1  (35T 의 약 4%)
테스트벤치 34개          : 전부 ALL PASS (모듈 34개 = 설계에 있는 모듈 전부)
```

## Vivado 에서 쓰는 법

1. 새 RTL 프로젝트 생성 (part: `xc7a35tcpg236-1`)
2. Add Sources -> 이 폴더의 `.v` 전부 (설계 파일만. `tb/`, `tb_legacy/` 는 넣지 말 것)
3. Add Constraints -> `top.xdc`
4. Top module 을 `top` 으로 지정
5. 테스트벤치는 Tcl Console 에서 `source .../tb/add_tb.tcl` 한 줄로 등록

## 시뮬레이션

테스트벤치는 전부 `top` 이나 각 모듈의 파라미터를 줄여서 인스턴스한다
(1초 -> 500us, "1us" -> 2~4클럭 식). 실보드 값 그대로는 시뮬이 몇 분씩 걸리기 때문.
로직은 동일하고 카운터 상수만 작아진다.
SR04 / DHT11 동작 모델이 테스트벤치 안에 들어있어서 센서 없이도 전체 경로가 돈다.

모듈별로 무엇을 무작위로 만들고 무엇을 검사하는지는 [`tb/README.md`](tb/README.md) 참고.
