# Design Specification

## 1. 목표와 범위

`aio_nand_dma_ctrl`은 CPU가 APB3로 명령을 내리면 host memory와 NAND page 사이를 이동시키는 controller core다. PROGRAM, READ, ERASE 세 명령을 제공하며 최대 page word 수는 parameter로 바꿀 수 있다. 기본 RTL parameter는 64 words이고 testbench는 빠른 regression을 위해 16 words를 사용한다.

Clock domain은 하나(`pclk`)다. 모든 ready/valid interface는 이 clock에 동기화된다. `presetn`은 asynchronous active-low reset이다.

설계는 세 층으로 쌓여 있다. 이 문서의 2~6절은 맨 안쪽 코어를, 7절은 PHY를, 8절은 SoC 통합을 다룬다.

| 층 | 모듈 | 아는 것 | 모르는 것 |
|---|---|---|---|
| 코어 | `aio_nand_dma_ctrl` | 레지스터, DMA, page buffer, ECC, 동작 FSM | NAND 핀이 어떻게 생겼는지 |
| PHY | `nand_onfi_phy` (+ `nand_onfi_cycle`) | 커맨드 시퀀스, 핀 타이밍, R/B# | 데이터가 어디서 왔는지 |
| IP 최상위 | `aio_nand_top` | 위 둘을 묶는다 | |
| SoC | `aio_soc` / `aio_fpga_top` | CPU, APB, RAM, UART와의 연결 | |

## 2. Interface contract

### APB3 slave

- address phase: `psel=1, penable=0`
- access phase: `psel=1, penable=1`
- wait state 없음: `pready=1`
- 정의되지 않은 address access는 `pslverr=1`
- busy 중 새 START는 무시하고 simulation warning을 출력

### DMA memory master

- `mem_req_valid && mem_req_ready`에서 request가 수락됨
- PROGRAM read는 한 번에 한 개만 outstanding
- read request 후 `mem_rsp_valid && mem_rsp_ready`에서 data 수락
- READ write-back은 request handshake에서 완료되는 posted write로 가정
- address는 byte address이며 word마다 4씩 증가

### NAND transaction port

- command: `nand_cmd_valid/ready`, operation, row, word count
- program stream: `nand_w_valid/ready`, data, ECC, last
- read stream: `nand_r_valid/ready`, data, ECC, last
- operation 종결: `nand_done`, 결과: `nand_fail`
- 외부 PHY/model은 stall 중 payload를 안정적으로 유지해야 함

## 3. Register map

| Offset | Name | Access | Reset | Description |
|---:|---|:---:|---:|---|
| `0x000` | CONTROL | RW | `0` | `[0] START`, `[2:1] OP`, `[8] CLEAR_STATUS` |
| `0x004` | STATUS | RO | `0` | `[0] BUSY`, `[1] DONE`, `[2] IRQ`, `[3] ERROR`, `[4] UNCORRECTABLE` |
| `0x008` | NAND_ROW | RW | `0` | NAND row/page address |
| `0x00C` | HOST_ADDR | RW | `0` | DMA base byte address |
| `0x010` | PAGE_WORDS | RW | `16` | number of 32-bit words |
| `0x014` | TIMEOUT | RW | `1024` | maximum busy cycles; zero disables watchdog |
| `0x018` | CORR_COUNT | RO | `0` | corrected data/ECC words in last operation |
| `0x01C` | UNCORR_COUNT | RO | `0` | uncorrectable words in last operation |
| `0x020` | ERROR_CODE | RO | `0` | detailed last error |
| `0x024` | IRQ_ENABLE | RW | `0` | `[0]` completion/error interrupt enable |
| `0x0FC` | ID | RO | `0x41494F31` | ASCII `AIO1` |

OP encoding:

| Value | Operation |
|---:|---|
| `0` | PROGRAM |
| `1` | READ |
| `2` | ERASE (PHY를 붙이면 row가 속한 **블록 전체**가 지워진다) |
| `3` | RESET — PHY가 NAND에 FFh를 보낸다. 코어는 이 값을 그대로 PHY에 넘길 뿐이다 |

Error encoding:

| Value | Meaning |
|---:|---|
| `0x00` | no error |
| `0x01` | zero or oversized page length |
| `0x02` | NAND reported failure (status FAIL bit, WP#로 거부됨, 또는 PHY가 R/B#를 기다리다 포기) |
| `0x03` | watchdog timeout |
| `0x04` | at least one uncorrectable ECC word |

START를 쓰면 이전 operation의 sticky status와 counters가 자동 초기화된다. `CONTROL.CLEAR_STATUS`만 써서 software가 별도로 지울 수도 있다.

## 4. Operation sequences

### PROGRAM

```text
IDLE -> DMA_READ_REQ -> DMA_READ_RSP -> ...
     -> NAND_CMD -> NAND_PROGRAM -> NAND_WAIT -> COMPLETE
```

DMA read response를 page buffer에 저장하는 같은 cycle에 ECC를 생성한다. 전체 page가 준비된 뒤 NAND command와 `(data,ecc)` stream을 전송한다. 이것은 partial page가 NAND에 노출되지 않도록 하는 단순한 정책이다.

### READ

```text
IDLE -> NAND_CMD -> NAND_READ -> NAND_WAIT
     -> DMA_WRITE -> COMPLETE
```

각 NAND word가 도착할 때 ECC decoder가 즉시 판정한다. single-bit data fault는 고친 값이 buffer로 들어가며 correction counter가 증가한다. double-bit fault는 data를 수정하지 않고 uncorrectable status/count를 남긴다. NAND operation이 종료된 뒤 buffer 전체를 host memory로 write-back한다.

### ERASE

```text
IDLE -> NAND_CMD -> NAND_WAIT -> COMPLETE
```

## 5. ECC

32 data bit를 Hamming code position 1..38에 배치한다. position 1, 2, 4, 8, 16, 32는 Hamming parity이고 별도 overall parity를 추가한다.

| Syndrome | Overall mismatch | 판정 |
|---:|---:|---|
| `0` | `0` | clean |
| `0` | `1` | overall parity bit fault |
| nonzero | `1` | single-bit data/parity fault; correctable |
| nonzero | `0` | double-bit fault; uncorrectable |

## 6. Synthesis considerations

- `MAX_PAGE_WORDS`를 키우면 asynchronous read 형태인 buffer mux가 timing/area를 지배할 수 있다.
- productization 단계에서는 dual-port synchronous SRAM/BRAM과 prefetch state를 사용한다.
- NAND PHY가 다른 clock을 사용하면 command/data path마다 CDC FIFO와 reset-domain 검증이 필요하다.
- high-throughput 구조는 ping-pong page buffer로 NAND와 DMA를 overlap할 수 있다.
- timing constraint는 현재 100 MHz 단일 clock 기준이다.

## 7. ONFI PHY (`rtl/phy/nand_onfi_phy.sv`)

코어의 트랜잭션 포트를 실제 NAND 핀으로 바꾼다. NAND 배경은 [nand_onfi_notes.md](nand_onfi_notes.md)에 있다.

### 7.1 한 사이클 : `nand_onfi_cycle`

```text
          | SETUP  |   PULSE    |  HOLD  |
 CLE/ALE  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
 DQ(out)  =========== valid ============---
 WE#      ‾‾‾‾‾‾‾‾‾\____________/‾‾‾‾‾‾‾‾‾‾‾
                                ^ NAND가 DQ를 잡는다
```

| 파라미터 | 기본 | 100 MHz에서 | 보장하는 것 |
|---|---:|---:|---|
| `T_SU` | 1 | 10 ns | CLE/ALE/DQ를 스트로브보다 먼저 세운다 |
| `T_PW` | 3 | 30 ns | tWP, tRP, 그리고 읽기에서 tREA(20 ns) 뒤에 샘플 |
| `T_HD` | 2 | 20 ns | tCLH, tALH, tDH, tWH, tREH |
| `T_WAIT` | 16 | 160 ns | tWB, tWHR, tADL, tRR 공용 대기 |

FPGA 빌드(`aio_fpga_top`)는 `T_PW = 4`(40 ns)를 쓴다. 시뮬레이션은 핀 지연이 0이라 3으로도 통과하지만, 배치배선 뒤의 실제 I/O 지연(RE# 핀까지 최대 13 ns)에 tREA 20 ns를 더하면 30 ns를 넘는다. 계산은 `syn/aio_fpga_top.xdc`의 "NAND 입력" 절과 [results.md](results.md) 3절에 있다. SoC 시뮬레이션(`tb_aio_soc`)도 같은 4로 돈다.

- 모든 핀 출력은 플롭에서 바로 나간다(스트로브 글리치 방지).
- 읽기 데이터는 RE#를 올리는 엣지에서 한 번에 잡는다. 동기화 플롭이 없다. RE#가 우리 신호라 데이터가 언제 안정되는지 알기 때문이다.
- R/B#는 2단 동기화한다. 리셋 값은 0(busy)이다.

### 7.2 시퀀스 : `nand_onfi_phy`

```text
P_INIT ─> P_CMD1(FFh) ─> P_WAIT_WB ─> P_WAIT_RB ─> P_DONE ─> P_IDLE      (전원 인가 직후 자동)

PROGRAM : CMD1(80h) ADDR×5 WAIT_ADL [W_BEAT W_BYTE×5]×N CMD2(10h) WAIT_WB WAIT_RB STAT_CMD(70h) WAIT_RD STAT_RD DONE
READ    : CMD1(00h) ADDR×5 CMD2(30h) WAIT_WB WAIT_RB WAIT_RD [R_BYTE×5 R_BEAT]×N DONE
ERASE   : CMD1(60h) ADDR×3 CMD2(D0h) WAIT_WB WAIT_RB STAT_CMD(70h) WAIT_RD STAT_RD DONE
RESET   : CMD1(FFh) WAIT_WB WAIT_RB DONE
```

- CE#는 동작 하나(첫 커맨드 ~ status)가 끝날 때까지 계속 0이다. 그래서 핀 모니터는 "CE#가 내려가 있는 한 구간 = 트랜잭션 하나"로 자른다.
- PROGRAM/ERASE는 끝에 status를 읽어 `fail = status[0] | ~status[7]`를 코어에 올린다.
- `write_protect` 입력이 1이면 WP#를 0으로 내린다. NAND는 PROGRAM/ERASE를 무시하고 status bit7을 0으로 준다 → fail.

### 7.3 페이지 안에서의 배치

```text
flash byte :  5i   5i+1  5i+2  5i+3  5i+4
              d[7:0] d[15:8] d[23:16] d[31:24]  {1'b1, ecc[6:0] ^ 7'h67}
```

- 워드와 그 ECC를 붙여 놓는다(codeword interleave). PHY가 5바이트를 읽으면 곧바로 코어에 넘길 수 있어서 PHY에 버퍼가 필요 없다.
- ECC를 `0x67`과 XOR하는 이유: 지운 페이지(전부 0xFF)가 "에러 없음"으로 읽히게 하기 위해서다. 0xFFFFFFFF의 ECC는 0x18이므로 0x18 ^ 0x67 = 0x7F가 되어 지운 상태와 일치한다. 남는 bit7은 1로 쓴다.
- column 주소는 항상 0이다. 한 번의 동작은 페이지 맨 앞부터 `5 × PAGE_WORDS` 바이트를 쓴다.

### 7.4 예외 처리

| 상황 | PHY의 행동 | 코어가 보는 것 |
|---|---|---|
| R/B#가 `2^RB_TIMEOUT_W` 클럭 안에 안 돌아옴 | 포기하고 `done + fail` | `ERR_NAND_FAIL` (READ 도중에도 받는다: `ST_NAND_READ`의 `nand_done && nand_fail` 분기) |
| 코어가 watchdog으로 먼저 떠남 (스트림 handshake가 `2^STALL_W` 클럭 동안 없음) | NAND에 FFh를 보내 정리하고 IDLE. `done`은 내지 않는다 | 이미 `ERR_TIMEOUT`으로 끝나 있다 |
| NAND status의 FAIL 또는 WP | `done + fail` | `ERR_NAND_FAIL` |

## 8. SoC 통합 (`rtl/soc/`)

```text
                     +--> RAM (포트 A)  0x1000_0000 <--+
 ROM --> RV32I --> APB Master                          | 같은 메모리
                     +--> GPO           0x2000_0100    |
                     +--> UART          0x2000_0300    |
                     +--> aio_nand_top  0x3000_0000    |
                            |  DMA ------------------->+ RAM (포트 B)
                            +==== NAND 핀
```

| 영역 | 주소 | 비고 |
|---|---|---|
| 명령어 ROM | `0x0000_0000` ~ 4 KB | CPU에 직결(하버드). 데이터 버스로는 읽을 수 없다 |
| RAM | `0x1000_0000` ~ 4 KB | `apb_dpram`. 포트 A = APB, 포트 B = DMA. 동기 읽기(BRAM) |
| GPO | `0x2000_0100` | LED. 시뮬레이션에서는 펌웨어가 테스트벤치에 단계를 알리는 데 쓴다 |
| UART | `0x2000_0300` | SR / TXD / RXD |
| NAND 컨트롤러 | `0x3000_0000` ~ 4 KB | 3절의 레지스터 |

- CPU, APB 마스터, UART는 `cpu/` 프로젝트의 것을 그대로 가져왔다(`rtl/soc/cpu/`, `rtl/soc/periph/`). 바꾼 것은 주소 디코더와 메모리 맵(`apb_pkg.sv`), 그리고 크기를 파라미터로 뺀 `instruction_rom`뿐이다.
- `apb_dpram`은 APB의 SETUP 사이클에 주소가 이미 나와 있다는 점을 이용해 wait state 없이 동기 읽기를 한다.
- 이 APB 마스터는 PSLVERR을 보지 않는다. 컨트롤러의 `pslverr`는 SoC에서 연결되지 않는다.
- CPU에 인터럽트가 없어서 `irq`는 핀(LED)으로만 나가고 펌웨어는 STATUS를 폴링한다.
- `aio_fpga_top`은 리셋 동기화기(비동기 assert, 동기 deassert), 스위치 동기화, DQ 3-state 버퍼만 갖는다.

펌웨어(`sw/main.c`)가 쓰는 API는 하나다.

```c
status = nand_op(op, row, buf, words);   // ROW, HOST_ADDR, PAGE_WORDS, CONTROL 을 쓰고 DONE 을 기다린다
```

## 9. 알려진 한계와 모서리 동작

PHY를 붙여 시뮬레이션하면서 드러난 것과 코드를 읽다가 찾은 것을 구분해서 적는다. 고치지 않은 것은 이유와 함께 남긴다.

| 항목 | 내용 | 어떻게 찾았나 | 상태 |
|---|---|---|---|
| 지운 페이지 ECC | 마스크 없이는 지운 페이지가 워드마다 정정 불가로 읽힌다 | 시뮬레이션 (mutation M03으로 재현) | PHY에서 해결 (7.3) |
| READ 중 PHY 실패 | 코어가 `ST_NAND_READ`에서 `nand_done/fail`을 보지 않아 watchdog까지 기다렸다 | 시뮬레이션 (mutation M10으로 재현) | 코어에 분기 추가 |
| watchdog이 DMA 요청을 철회 | `mem_req_valid`가 ready 없이 내려갈 수 있다. 지금의 메모리 포트에서는 무해하지만 AXI에서는 위반이다 | 코드 리뷰. 재현하는 테스트는 없다 (`mem_if`의 `a_req_stable` assertion이 걸리게 된다) | 미해결. AXI 어댑터를 만들 때 "진행 중인 요청은 끝까지 보낸다"로 바꿔야 한다 |
| watchdog과 완료가 같은 클럭 | `ST_NAND_WAIT → ST_COMPLETE` 전이와 watchdog이 같은 클럭에 겹치면, 뒤에 적힌 case 문의 `state` 대입이 이겨서 동작은 끝났는데 `ERR_TIMEOUT`이 남는다 | 코드 리뷰. 시뮬레이션으로 재현하지는 않았다 | 미해결. watchdog 판정을 case 뒤로 옮기면 일관되게 에러로 끝난다 |
| busy 중 `CLEAR_STATUS` | 진행 중인 동작의 카운터까지 지운다 | 코드 리뷰 | 사용 규칙으로 막는다 (소프트웨어는 DONE 뒤에만 쓴다. 스코어보드는 이 자극이 오면 에러를 낸다) |
| busy 중 `START` | 무시된다. 다만 같은 쓰기의 `OP` 필드는 `op_reg`에 들어간다 | 시뮬레이션 (`aio_err_test`) | 의도된 동작 |
| 3-bit 에러 | SEC-DED는 1-bit 에러로 오인해 오정정할 수 있다 | 시뮬레이션 (`aio_ecc_test`의 3-bit 케이스) | 알고리즘의 한계. BCH/LDPC로 가야 한다 |
| page buffer | 레지스터 배열 + 조합 읽기 | 합성 보고서 | 미해결. `docs/10_day_plan.md` Day 7의 개선 과제 |
| column 주소 | 항상 0. 페이지 중간부터 읽고 쓸 수 없다 | 설계 범위 | 범위 밖 |
| 타이밍 파라미터 | 합성 시점에 고정. 레지스터로 바꿀 수 없다 | 설계 범위 | 부품이 바뀌면 다시 합성해야 한다 |
