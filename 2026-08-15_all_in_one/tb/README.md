# 테스트벤치 (모듈 하나당 하나)

설계 파일은 상위 폴더에, 테스트벤치는 전부 여기에 있다.
**모듈 34개 전부**에 대해 하나씩, 서로 완전히 독립이다.
아무거나 하나만 Set as Top 해도 그것만 돌아간다.

전부 **무작위 자가검증(self-checking)** 이라, 마지막 줄만 보면 된다.

```
=====================================================
  tb_fifo : ALL PASS  (checks=27105, seed=253690147)
=====================================================
```

실패하면 이렇게 나온다. 어느 시각에 무엇이 어긋났는지 최대 20개까지 찍는다.

```
  FAIL [1234500] r_data is not the head
  tb_fifo : FAIL =====  errors=3 / checks=27105
```

## Vivado 에서 쓰기

한 번만 등록하면 된다. Vivado 의 **Tcl Console** 에 붙여넣는다.

```tcl
source d:/work/26_AI_COMP_1/2026-08-15_all_in_one/tb/add_tb.tcl
```

이게 하는 일:
- 예전에 등록돼 있던 테스트벤치를 sim_1 에서 떼어낸다
- 이 폴더의 `.v` 를 전부 Simulation Sources 로 넣는다
- **시뮬레이션 실행 시간을 `all` 로 바꾼다** (기본 1000ns 로는 대부분 끝까지 못 간다)

그 다음부터는

1. Sources 창 > **Simulation Sources** 에서 돌릴 테스트벤치 선택
2. 오른쪽 클릭 > **Set as Top**
3. **Run Simulation > Run Behavioral Simulation**
4. Tcl Console 맨 아래 `ALL PASS` 확인

> 여러 테스트벤치가 한 fileset 에 같이 있어도 상관없다. Vivado 는 전부
> 컴파일하지만 elaborate 는 Top 으로 지정한 것 하나만 한다.

## 명령줄로 한 번에 다 돌리기

상위 폴더의 `run_tests.bat` 을 실행하면 전부 순서대로 돌고 마지막에 요약이 나온다.

```
run_tests.bat                  전부
run_tests.bat tb_fifo          하나만
```

직접 돌릴 때는

```
xvlog ..\*.v *.v
xelab -s sim tb_fifo
xsim sim -R
```

## 무작위 씨앗 바꾸기

각 파일 맨 위 `initial` 안에 `seed0` 가 있다. 이 값을 바꾸면 완전히 다른
자극이 나온다. 실행할 때마다 씨앗을 결과에 같이 찍으므로, 실패한 씨앗을
그대로 넣어 두면 그 실패를 다시 재현할 수 있다.

```verilog
seed0 = 32'h0F1F_0ABC;   // <- 여기를 바꾼다
```

## 목록

### 최상위

| 테스트벤치 | 대상 | 무작위로 만드는 것 / 보는 것 |
|---|---|---|
| `tb_top.v` | `top` | **통합**. UART 명령 -> FND/LED/UART 송신까지 전체 경로. 시나리오 4개(스톱워치/시계/SR04/DHT11)를 맨 위 `` `define `` 으로 골라 끌 수 있다 |

### 블록 (블록도의 상자 7개)

| 테스트벤치 | 대상 | 무작위로 만드는 것 / 보는 것 |
|---|---|---|
| `tb_btn_unit.v` | `btn_unit` | 채널 4개에 서로 다른 무작위 눌림 패턴. 채널별 펄스 개수가 맞는가(= 서로 간섭 없는가) |
| `tb_uart_comm.v` | `uart_comm` | 명령 문자 순서/간격, 표시값. 문자→명령 펄스, 값→문자열, 센서 done 송신, 모드 아닌 센서 done 무시 |
| `tb_main_control_unit.v` | `main_control_unit` | sw 조합, 버튼/UART 펄스. 모드 우선순위와 **게이팅**. 안의 FSM 을 참조로 한 벌 더 두고 비교 |
| `tb_time_datapath.v` | `time_datapath` | mode_sel 과 제어 전부. 하위 모듈을 참조로 한 벌 더 두고 MUX 선택이 맞는가 |
| `tb_sensor_unit.v` | `sensor_unit` | echo 폭, DHT 프레임/체크섬. 체크섬 통과분만 래치·유지, 실패 시 0, 두 센서 간섭 없음 |
| `tb_fnd_display.v` | `fnd_display` | 모드와 표시값 전부(범위 밖 값 포함). 모드별 4자리 세그먼트 코드와 dot |
| `tb_led_status.v` | `led_status` | 입력 13비트 **전수 8192가지** + 무작위 |

### 하위 모듈

| 테스트벤치 | 대상 | 무작위로 만드는 것 / 보는 것 |
|---|---|---|
| `tb_btn_debounce.v` | `btn_debounce` | 샘플 단위 0/1 런 패턴. 8샘플 못 채운 채터링은 무시, 채운 것만 펄스 1회 |
| `tb_uart_fifo.v` | `uart_fifo` | 주고받는 바이트, 묶음 크기, pop 시점. 순서 유지, 깊이 초과 backpressure 무손실 |
| `tb_uart_rx.v` | `uart_rx` | 바이트 값, 유휴 길이, 짧은 글리치. 글리치를 바이트로 오인하지 않는가 |
| `tb_uart_tx.v` | `uart_tx` | 바이트 값, 쉬는 시간. 선을 직접 받아 되돌려 비교 |
| `tb_baud_tick_gen.v` | `baud_tick_gen` | 보드레이트 3종(9600 포함) 동시 + 무작위 reset. tick 간격 = DIV |
| `tb_fifo.v` | `fifo` | push/pop/데이터 매 클럭. 큐 참조 모델과 비교 + 순서 유지 |
| `tb_register_file.v` | `register_file` | we/주소/데이터. 같은 주소 읽기·쓰기 겹침 포함 |
| `tb_fifo_control_unit.v` | `fifo_control_unit` | push/pop. 포인터·full·empty 전부 비교, 깊이 초과/미달 |
| `tb_ascii_decoder.v` | `ascii_decoder` | 명령 문자 + 아무 바이트 섞기, FIFO 빈 구간. 매핑 없는 문자도 소비되는가 |
| `tb_ascii_sender.v` | `ascii_sender` | 모드/값, tx_full 백프레셔, 시작 직후 입력 흐트러뜨리기. 문자열 완전 일치 |
| `tb_control_unit_stopwatch.v` | `control_unit_stopwatch` | 5개 입력 무작위 펄스(겹침 포함). 참조 FSM 비교 + 'r'/'s' 는 토글이 아님 |
| `tb_control_unit_watch.v` | `control_unit_watch` | 8개 입력 무작위 펄스. 참조 FSM 비교 + 편집자리 랩 |
| `tb_stopwatch_datapath.v` | `stopwatch_datapath` | run/stop/clear/업다운. 0 에서 다운 1칸 -> 23:59:59.99 로 **자리올림 전수** |
| `tb_watch_datapath.v` | `watch_datapath` | 편집자리/증감/clear. 한 자리 랩이 옆으로 안 새는가, 23:59:59.99 자리올림 |
| `tb_sr04_controller.v` | `sr04_controller` | echo 폭·지연. 거리 계산식, 범위 밖 거부, 무응답/붙어있는 echo 타임아웃 |
| `tb_dht11_controller.v` | `dht11_controller` | 40비트 데이터·체크섬·비트 길이·응답 지연. 값/valid/dbg_step, 센서 없을 때 타임아웃 |
| `tb_tick_gen_1us.v` | `tick_gen_1us` | run_stop/clear 매 클럭. run_stop=0 은 "멈춤", clear 는 "지움" |
| `tb_tick_gen_100hz.v` | `tick_gen_100hz` | 분주비 3종 동시 + 무작위 reset. tick 간격 |
| `tb_periodic_pulse.v` | `periodic_pulse` | en 매 클럭. en=0 이 "지움"인 것을 정면으로 확인 |
| `tb_time_counter.v` | `time_counter` | 6개 입력 매 클럭. 참조 모델과 매 클럭 비교, TIMES/INIT_VAL 두 조합 |
| `tb_fnd_controller.v` | `fnd_controller` | 4자리 digit·dot, 무작위 간격. 자리별 세그먼트, **dot 이 100의 자리에만**, 스캔 순서 |
| `tb_fnd_scan_tick.v` | `fnd_scan_tick` | 분주비 3종 + reset. 간격과 폭(1클럭) |
| `tb_counter_4.v` | `counter_4` | tick/reset. tick 없으면 유지, 3 다음 0 |
| `tb_decoder_2x4.v` | `decoder_2x4` | sel 전수 + 무작위. 표를 베끼지 않고 식으로 비교, 항상 한 자리만 켜짐 |
| `tb_mux_4x1.v` | `mux_4x1` | 4입력·sel. 자리 뒤바꿔 연결 검출 |
| `tb_seg_decoder.v` | `seg_decoder` | 16가지 전수 + 무작위. 숫자 자리에서 dp 가 켜지지 않는가 |

## 테스트벤치 규칙 (전 파일 공통)

이 규칙을 지키면 시뮬레이터 실행 순서에 따라 결과가 흔들리는 일이 없다.

- **자극은 `@(negedge clk)` 에서 준다.** DUT 는 posedge 에서 읽으므로 이미 안정된 값을 본다.
  엣지와 같은 시각에 값을 바꾸면 그 엣지에서 볼지 다음 엣지에서 볼지가
  시뮬레이터마다 달라진다 (펄스가 두 번 먹거나 아예 안 먹는다).
- **스코어보드는 `@(posedge clk)` 에서 엣지 직전값을 본다.** DUT 도 참조 모델도
  nonblocking 이라 둘 다 "이번 엣지에 반영되기 전 값"이 읽혀서 서로 비교가 된다.
- **1클럭 폭 펄스는 연달아 붙여 주지 않는다.** 실제로 이 설계에 들어오는 펄스는
  전부 `btn_debounce` 나 `ascii_decoder` 가 만든 것이고, 둘 다 두 클럭 연속으로는
  내보내지 않는다. 자극도 거기 맞춘다.
- **자리올림에 시간차가 있는 곳(스톱워치/시계)** 은 tick 이 지나고 전파가 끝난 뒤에만
  비교한다. `time_counter` 를 4단으로 이어 붙였고 각 단의 자리올림이 레지스터를
  한 번씩 거치기 때문이다.
- **한글 메시지는 `$display` 의 포맷 문자열에 직접 쓴다.** reg 에 담아 `%0s` 로
  넘기면 xsim 이 깨뜨린다. 그래서 `chk()` 에 넘기는 꼬리표는 전부 영문이다.

## 예전 테스트벤치

블록 단위로만 있던 예전 것들은 `../tb_legacy/` 에 그대로 두었다.
지금 것과 모듈 이름이 겹치므로 **같이 컴파일하면 안 된다**. 참고용으로만 남긴 것이다.
