# UART + FIFO + ASCII 경로만 (2026-08-24)

통합 프로젝트(`2026-08-15_all_in_one`)에서 **PC 와 주고받는 부분만** 떼어 낸 폴더.
스톱워치 / 시계 / FND / 센서 / 버튼은 전부 빠졌다. 이 폴더만으로 컴파일되고
이 폴더만 시뮬레이션하면 된다.

```
 PC --TX--> rx --> [uart_rx] --> [RX_FIFO] --> [ascii_decoder] --> cmd_* 펄스
                                                                   cmd_get ─┐
                                                                            │
 PC <--RX-- tx <-- [uart_tx] <-- [TX_FIFO] <-- [ascii_sender]  <─────────────┘
                                                     ^
                                              표시값 (TB 가 준다)
```

## 파일

| 파일 | 안에 든 모듈 |
|---|---|
| `uart_comm.v` | **최상위**. 아래 3덩어리 배선 + 송신 시점 결정 |
| `uart_fifo.v` | `uart_fifo` : baud tick + rx/tx + FIFO 2개 |
| `uart.v` | `baud_tick_gen`, `uart_rx`, `uart_tx` |
| `fifo.v` | `fifo`, `register_file`, `fifo_control_unit` |
| `ascii_decoder.v` | 수신 바이트 -> 1클럭 명령 펄스 |
| `ascii_sender.v` | 현재 모드 값 -> ASCII 문자열 -> TX FIFO |
| `tb/` | 테스트벤치 10개 (모듈 하나당 하나 + 전 구간 1개) |
| `run_tests.bat` | 명령줄로 10개 전부 돌리기 |
| `make_project.tcl` | 이 폴더만으로 Vivado 프로젝트 만들기 |

의존성이 이 6개 파일 안에서 닫힌다. `tick_gen.v` 도 필요 없다
(1초 주기 송신을 없애고 PC 의 `g` 요청으로 바꾸면서 `periodic_pulse` 가 빠졌다).

## 통합본에서 가져오면서 손댄 것

RTL 6개는 `2026_08_15_all` 프로젝트의 **최신본 그대로** 복사했다. 고친 것은
테스트벤치 쪽뿐이다. 예전 테스트벤치가 옛날 인터페이스를 보고 있어서 그대로는
안 돌아갔다.

| 파일 | 무엇이 안 맞았나 | 어떻게 고쳤나 |
|---|---|---|
| `tb/tb_ascii_decoder.v` | `cmd_get` 출력이 생겼는데 TB 가 연결도 안 하고 `g` 를 "매핑 안 된 문자"로 알고 있었다. 그래서 `g` 가 나와도 그냥 통과 — 검사가 아예 안 되던 상태 | 포트 연결 추가, 명령 벡터 12 -> 13비트, 참조 디코더에 `"g","G"` 추가, 무작위 문자표에 `g`/`G` 넣어 실제로 때려 보게 함 |
| `tb/tb_ascii_sender.v` | `disp_mode` 입력이 생겼는데 연결이 없어서 **x 로 떠 있었고**, 기대 문자열이 옛날 13바이트 포맷(`HH:MM:SS.mm`, `DIST 123cm`, `H 60% T 25C`) 그대로였다 | `disp_mode` 연결 + 무작위화, 기대 문자열을 현재 포맷(7/5/7바이트)으로 다시 씀. 전송 시작 직후 흐트러뜨리는 값에 `mode_sel`/`disp_mode` 도 넣어서, 전송 도중 모드가 바뀌어도 나가던 문자열이 안 흔들리는지 확인 |
| `tb/tb_uart_comm.v` | 옛 버전은 `SEND_PERIOD` 파라미터(1초 자동 송신)를 오버라이드하고 있었다. 그 파라미터가 없어져서 elaborate 실패 | 오늘 새로 쓴 전 구간 TB 로 교체 (`g` 요청 방식, 9600bps 실속도) |

나머지 7개(`tb_register_file`, `tb_fifo_control_unit`, `tb_fifo`,
`tb_baud_tick_gen`, `tb_uart_rx`, `tb_uart_tx`, `tb_uart_fifo`)는 대상 모듈이
안 바뀌었으므로 그대로 가져왔다.

## 테스트벤치

작은 것부터 큰 것 순서.

| 테스트벤치 | 대상 | 무작위로 만드는 것 / 보는 것 |
|---|---|---|
| `tb_register_file.v` | `register_file` | we/주소/데이터. 같은 주소 읽기·쓰기 겹침 포함 |
| `tb_fifo_control_unit.v` | `fifo_control_unit` | push/pop. 포인터·full·empty 전부 비교 |
| `tb_fifo.v` | `fifo` | push/pop/데이터 매 클럭. 큐 참조 모델과 비교 |
| `tb_baud_tick_gen.v` | `baud_tick_gen` | 보드레이트 3종 동시 + 무작위 reset. tick 간격 = DIV |
| `tb_uart_rx.v` | `uart_rx` | 바이트 값, 유휴 길이, 짧은 글리치를 바이트로 오인하지 않는가 |
| `tb_uart_tx.v` | `uart_tx` | 바이트 값, 쉬는 시간. 선을 직접 받아 되돌려 비교 |
| `tb_uart_fifo.v` | `uart_fifo` | 주고받는 바이트, 묶음 크기, pop 시점. 순서 유지, 깊이 초과 backpressure 무손실 |
| `tb_ascii_decoder.v` | `ascii_decoder` | 명령 문자 + 아무 바이트 섞기, FIFO 빈 구간. `g`/`G` 포함 13개 명령 |
| `tb_ascii_sender.v` | `ascii_sender` | 모드/`disp_mode`/값, tx_full 백프레셔. 문자열 완전 일치 |
| `tb_uart_comm.v` | `uart_comm` | **전 구간**. rx 선을 직접 흔들어 보내고 tx 선을 감시해 되돌려 읽는다 |

`tb_uart_comm` 만 성격이 다르다. 나머지 9개는 무작위 자가검증이라 마지막 줄의
`ALL PASS` 만 보면 되고, 이건 PC 역할을 하면서 주고받은 것을 사람이 읽으라고
전부 찍는다 (내부 신호도 계층 참조로 같이 찍는다).

```
  [  892.0us]   .. decoder: cmd_get 펄스
  [  892.0us]   .. sender : send_start -> 문자열 래치
  [  892.0us]   .. sender : TX FIFO <- 0x31
  ...
  [ 1881.6us] PC <-  '1' (0x31)
      받은 문자열 [7바이트] "12:34\r\n"
  PASS  WATCH 'g' -> 12:34
```

`tb_uart_comm` 은 보드레이트를 줄이지 않고 **9600bps 실속도 그대로** 돌린다.
1바이트가 1.04ms 라 전체 시뮬 시간이 87ms(=870만 클럭), 실행에 몇 초 걸린다.

## 돌리는 법

### 명령줄

```
run_tests.bat                  10개 전부
run_tests.bat tb_uart_comm     하나만
```

결과는 `sim_work\<테스트벤치>.log`, 마지막에 PASS/FAIL 요약이 나온다.
Vivado 경로가 다르면 `run_tests.bat` 위쪽 `VIVADO` 한 줄만 고치면 된다.

직접 돌릴 때는:

```
xvlog *.v tb\*.v
xelab -s sim tb_uart_comm
xsim sim -R
```

### Vivado GUI

Vivado 를 열고 Tcl Console 에 한 줄:

```tcl
source d:/work/26_AI_COMP_1/2026_08_24_uart_fifo/make_project.tcl
```

이 폴더에 프로젝트를 만들고, 설계 6개 / 테스트벤치 10개를 등록하고,
시뮬레이션 실행 시간을 `all` 로 바꾼다(기본 1000ns 로는 끝까지 못 간다).
그 다음은 Simulation Sources 에서 돌릴 것을 **Set as Top** -> Run Behavioral Simulation.

> 이 폴더는 시뮬레이션 전용이다. `top.v` 와 `.xdc` 가 없으므로 합성/비트스트림은
> 통합 프로젝트(`2026_08_15_all`)에서 한다.

## 검증 결과 (2026-08-24, xsim 2020.2)

`run_tests.bat` 한 번에 10개 전부.

```
tb_register_file         ALL PASS  (checks=3991,  seed=572692889)
tb_fifo_control_unit     ALL PASS  (checks=32170, seed=826366246)
tb_fifo                  ALL PASS  (checks=27105, seed=253690147)
tb_baud_tick_gen         ALL PASS  (checks=7423,  seed=-1778379264)
tb_uart_rx               ALL PASS  (checks=105,   seed=170351121)
tb_uart_tx               ALL PASS  (checks=242,   seed=2046825012)
tb_uart_fifo             ALL PASS  (checks=57,    seed=253692604)
tb_ascii_decoder         ALL PASS  (checks=1095,  seed=173806046)
tb_ascii_sender          ALL PASS  (checks=3415,  seed=1582104577)
tb_uart_comm             ALL PASS  (7개 시나리오, 87.5ms)
```

씨앗은 각 테스트벤치 위쪽 `seed0` 하나만 바꾸면 완전히 다른 자극이 나온다.
실패하면 그 씨앗이 결과에 찍히므로 그대로 넣어 재현할 수 있다.

## 프로토콜 (PC 쪽에서 보는 것)

9600 8N1.

### PC -> FPGA (1문자 = 1명령, 대소문자 구분)

| 문자 | 동작 |
|---|---|
| `r` / `s` | 스톱워치 RUN / STOP |
| `c` | Clear |
| `m` | 스톱워치 업/다운 카운트 전환 |
| `U` / `D` | 시계 +1 / -1 |
| `L` / `R` | 시계 편집자리 이동 |
| `S` / `M` / `H` | 시계 편집자리 직접 선택 (초/분/시) |
| `t` | 센서 수동 측정 |
| `g` (`G`) | **현재 값 1회 전송 요청**. 이것만 Control Unit 이 아니라 `ascii_sender` 로 간다 |

매핑 안 된 문자(개행 등)는 조용히 버린다. 버리더라도 pop 은 하므로 뒤 명령이 막히지 않는다.

### FPGA -> PC (요청 1번에 1줄, 끝은 CR+LF)

| 모드 | 보내는 것 | 예 |
|---|---|---|
| 스톱워치 / 시계 | `sw[0]`=0 -> `SS.mm` (7바이트) | `56.78` |
| 스톱워치 / 시계 | `sw[0]`=1 -> `HH:MM` (7바이트) | `12:34` |
| SR04 | `DDD` (5바이트) | `123` |
| DHT11 | `HH TT` (7바이트) | `60 25` |

FND 에 보이는 두 자리만, 라벨/단위 없이 숫자만 보낸다.
센서 모드에서는 `g` 요청 없이도 **측정이 끝날 때마다** 한 줄 자동으로 나간다.

## 이 경로에서 실제로 잡혔던 버그 (주석으로도 각 파일에 남아 있다)

1. **ASCII Sender 문자 유실** — `tx_full` 을 N클럭에 보고 push 를 N+1클럭에 내보내서,
   그 사이 FIFO 가 full 이 되면 `we = push & ~full` 로 바이트가 조용히 버려졌다
   (`"H 60% T 25C"` -> `"H 60%T2C"`). push 를 조합 출력으로 바꿔 확인한 그 클럭에
   밀어넣도록 수정. `tb_ascii_sender` 가 매 클럭 `push && tx_full` 을 감시한다.
2. **FIFO 깊이 부족** — 4단으로는 문자열 한 줄이 안 들어가 계속 full 이었다.
   `AWIDTH` 파라미터로 빼고 16단으로.
3. **`control_unit` 이름 충돌** — FIFO 내부 포인터 제어기를 `fifo_control_unit` 으로 rename.
4. **센서 done 전송이 한 측정 뒤처짐** — done 이 뜨는 엣지에 값 레지스터도 갱신되는데
   같은 엣지에 전송을 시작해서 옛날 값을 래치했다. `uart_comm` 에서 done 을 1클럭 지연.
