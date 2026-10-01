# Verification Plan

## 1. 전략

검증 목표는 PROGRAM/READ가 한 번 되는지를 보는 것이 아니다. storage controller에서 결함이 자주 생기는 **backpressure, ECC fault, timeout, error propagation, 핀 타이밍**을 재현하고 자동으로 판정하는 것이다.

네 단계로 쌓았다. 아래 단계일수록 빠르고 원인을 찾기 쉽고, 위 단계일수록 실제와 가깝다.

| 단계 | 대상 | 테스트벤치 | NAND 쪽 상대 | 무엇을 보나 |
|---|---|---|---|---|
| Block | `secded_ecc_32` | `tb_secded_ecc_32`, `tb_ecc_vectors` | - | ECC 자체. 자기 일관성 + Python 골든과 비교 |
| Core | `aio_nand_dma_ctrl` | `tb_aio_nand_dma_ctrl` | valid/ready 트랜잭션 모델 | FSM, DMA, backpressure, 에러 코드 |
| IP | `aio_nand_top` (코어 + PHY) | `tb_aio_nand_top` (directed), `testbench/uvm/` (UVM) | 핀 레벨 `nand_model` | 커맨드 시퀀스, AC 타이밍, 예외 복구, 커버리지 |
| SoC | `aio_soc` | `tb_aio_soc` + 펌웨어 | 핀 레벨 `nand_model` | CPU·버스·DMA·NAND가 한 번에 맞물리는지 |

전부 자기 검증(self-checking)이다. 사람이 파형을 보고 판정하는 테스트는 없다.

## 2. 검사기(checker) 목록

"무엇이 틀리면 어디서 잡히는가"를 한눈에 본다.

| 검사기 | 위치 | 잡는 것 |
|---|---|---|
| NAND AC 타이밍 | `model/nand_model.sv` | tWP, tWH, tRP, tREH, tDS, tDH, tCLS/H, tALS/H, tWHR, tADL, tRR 위반 |
| NAND 프로토콜 | `model/nand_model.sv` | busy 중 커맨드, 주소 없이 확정, CLE·ALE 동시, 범위 밖 row, 페이지 끝 넘어 읽기/쓰기 |
| 핀 불변식 | `rtl/phy/nand_onfi_phy.sv` (sim 전용 assert) | WE#·RE# 동시 low, RE# low 중 DQ 구동(버스 충돌), CE# high 중 스트로브 |
| APB 프로토콜 | `testbench/uvm/aio_uvm_if.sv` (SVA) | SETUP→ACCESS 순서, 전송 중 주소/데이터 변화, PSEL 없는 PENABLE |
| DMA 프로토콜 | `testbench/uvm/aio_uvm_if.sv` (SVA) | ready를 기다리는 동안 요청이 바뀌거나 사라짐 |
| 예측 스코어보드 | `testbench/uvm/aio_scoreboard.svh` | 레지스터 값, irq, DMA 주소·데이터·횟수, NAND 커맨드·주소·데이터 바이트, 최종 셀 내용 |
| 기준 모델 자체 | `aio_base_test::start_of_simulation_phase` | SV 기준 ECC 모델이 Python 골든 벡터와 다르면 에러 |

## 3. UVM 환경 (`testbench/uvm/`)

```text
     시퀀스 ──> [apb_agent]  ──APB──> +-------------+ ──핀──> nand_model
                [mem_agent] <──DMA──> | aio_nand_top|              ^
                                      +-------------+              | backdoor
                [nand_monitor] <──────────── 핀 ──────+            | (peek / flip_bit / fail / stuck)
                     |                                             |
   apb.mon ─┬─ mem.mon ─┬─ nand_mon ──> [aio_scoreboard] ──────────+
                                              |
                                        [aio_coverage]
```

| 컴포넌트 | 종류 | 하는 일 |
|---|---|---|
| `apb_agent` | active | 시퀀스가 준 `apb_item`을 SETUP/ACCESS로 실어 보낸다. 모니터는 완료된 전송과 리셋을 알린다 |
| `mem_agent` | reactive | DUT가 DMA로 요청하면 host memory로서 응답한다. `req_ready`와 응답 지연을 확률로 흔든다 |
| `nand_monitor` | passive | WE#/RE#/CE# 엣지에서 핀을 읽어 CE# 구간 하나를 `nand_txn`(커맨드·주소·데이터)으로 조립한다 |
| `aio_scoreboard` | 예측기 | START 시점에 셀을 backdoor로 읽어 결과를 계산해 두고, DONE에서 전부 비교한다 |
| `aio_coverage` | subscriber | 스코어보드가 판정한 동작 하나마다 커버그룹을 sample한다 |

**스코어보드의 원칙.** 테스트는 기대값을 알려 주지 않는다. 에러 주입도 셀을 뒤집기만 한다. 스코어보드가 그 셀을 직접 읽고 기준 ECC 모델로 "정정 몇 개, 정정 불가 몇 개"를 계산한다. 그래서 무작위 테스트가 가능하다. 예외는 watchdog 하나다(클럭 수를 세야 해서 테스트가 `cfg.expect_watchdog`로 알려 준다).

**테스트 이름 넘기기.** 윈도의 `xsim.bat`은 `=`가 든 인자를 잘라 먹어서 `+UVM_TESTNAME=`을 쓸 수 없다. 실행 디렉터리의 `uvm_test.txt`를 tb가 읽어 `run_test()`에 넘긴다. VCS에서는 `+UVM_TESTNAME`이 그대로 동작한다.

## 4. 테스트 목록

### 4.1 UVM

| 테스트 | 시퀀스 | 내용 |
|---|---|---|
| `aio_smoke_test` | `aio_smoke_seq` | ERASE → 지운 페이지 READ → PROGRAM → READ |
| `aio_ecc_test` | `aio_ecc_seq` | 코드워드 40비트를 하나씩 뒤집기(데이터 32 + ECC 7 + 미사용 1), 같은 워드 2-bit × 24, 3-bit × 8, 모든 워드에 1-bit, (정정 수 0/1/2) × (정정 불가 수 0/1/2) 조합 9가지, 짧은 읽기 |
| `aio_err_test` | `aio_err_seq` | PSLVERR, RO 레지스터 쓰기, 길이 0 / MAX+1, NAND FAIL(program/erase), WP#, R/B# 고착 × 4개 동작 + RESET 복구, watchdog이 READ/PROGRAM 스트림 중간에 터짐(원자성 확인), busy 중 START, CLEAR_STATUS, irq enable |
| `aio_bp_test` | `aio_bp_seq` | DMA ready 15% / 응답 20%의 심한 backpressure와 0% backpressure를 오가며 동작 |
| `aio_reset_test` | `aio_reset_seq` | READ 데이터 구간 중간, PROGRAM의 DMA 구간, idle에서 리셋. 그 뒤 정상 동작 |
| `aio_rand_test` | `aio_rand_seq` | 80회. 동작·row(모서리 편중)·길이·host 주소·backpressure·에러 주입을 전부 무작위. seed를 바꿔 여러 번 |

### 4.2 Directed (non-UVM)

`tb_aio_nand_top`의 16개 시나리오: 전원 인가 RESET, 지운 페이지, PROGRAM(셀·ECC 바이트 확인), READ, 1-bit(데이터), 1-bit(ECC), 2-bit, 두 워드 동시 1-bit, 덮어쓰기는 AND, ERASE는 블록 단위, NAND FAIL, WP#, watchdog 후 PHY 정리, R/B# 고착, RESET으로 복구, 잘못된 길이.

`tb_aio_nand_dma_ctrl`의 트랜잭션 레벨 시나리오(코어만):

| ID | Scenario | Stimulus | Expected result |
|---|---|---|---|
| T01 | Reset/ID | reset 후 ID read | `0x41494F31` |
| T02 | PROGRAM | 16 patterned words, random stalls | NAND data/ECC 전부 golden과 일치 |
| T03 | Clean READ | programmed page read | destination memory 전부 source와 일치 |
| T04 | 1-bit fault | NAND word의 data bit flip | 원본 복구, corrected count=1 |
| T05 | 2-bit fault | 같은 NAND word에서 2 bits flip | uncorrectable flag/count, error code=4 |
| T06 | ERASE | programmed page erase | 모든 word `0xFFFF_FFFF` |
| T07 | NAND fail | model의 fail injection | ERROR=1, error code=2 |
| T08 | Watchdog | command ready 강제 low | ERROR=1, error code=3 |
| T09 | Bad length | `MAX_PAGE_WORDS+1` | bus activity 전 error code=1 |

### 4.3 SoC

`tb_aio_soc`: 펌웨어가 ID 확인 → ERASE → 지운 페이지 확인 → PROGRAM → READ 비교 → (테스트벤치가 1-bit 주입) 정정 확인 → (2-bit 주입) 검출 확인 → ERASE 후 확인. UART로 `AIO EBPR12 PASS`, GPO로 `0xA5`. 테스트벤치는 UART 문자열, GPO, NAND 타이밍 위반 0건을 확인한다.

## 5. 기능 커버리지 (`aio_coverage`)

| 커버그룹 | coverpoint / cross | bin |
|---|---|---|
| `cg_op` | `cp_op` | program / read / erase / reset |
| | `cp_err` | ok / bad_len / nand_fail / timeout / ecc |
| | `x_op_err` | 동작 × 결과 (불가능한 조합은 ignore) |
| | `cp_words` | 0 / 1 / 중간 / 최대 / 초과 |
| | `cp_blk`, `cp_page`, `x_addr` | 블록·페이지의 처음 / 중간 / 끝 |
| | `cp_corr`, `cp_uncorr`, `x_corr_uncorr` | 한 페이지의 정정 수 × 정정 불가 수 (0 / 1 / 여러 개) |
| | `cp_wp`, `x_op_wp` | WP# × 동작 |
| | `cp_bp`, `x_op_bp` | backpressure 단계 × 동작 |
| | `cp_prev`, `x_seq` | 앞 동작 → 이번 동작 |
| `cg_ecc` (워드마다) | `cp_status` | clean / data_fixed / parity_fixed / uncorr |
| | `cp_bit` | 고친 데이터 비트 자리 0..31 각각 |

테스트별 커버리지 DB를 `xcrg`로 합쳐 회귀 전체의 숫자를 낸다. 구멍(100% 미만인 coverpoint)은 `build/regress/report.md`에 이름으로 찍힌다.

## 6. Mutation check (`scripts/mutation.py`)

테스트가 전부 통과한다는 사실만으로는 "설계가 맞다"와 "검사가 빠져 있다"를 구분할 수 없다. RTL에 버그를 하나씩 심고 회귀가 FAIL로 잡아내는지 본다. 하나라도 통과하면 검증 환경에 구멍이 있는 것이다. 심는 버그 목록과 결과는 [results.md](results.md)에 있다.

## 7. Python independent model

`scripts/ecc_ref.py selftest`는 RTL과 별도로 다음을 검사한다.

- corner/random word의 clean decode
- 각 sample에서 32개 data bit single fault 전수
- 7개 ECC bit single fault 전수
- 각 sample에서 10개 random double-bit fault

고정 seed를 사용하므로 실패는 재현 가능하다. `gen` command가 만드는 벡터 파일을 두 군데서 쓴다: `tb_ecc_vectors`(RTL과 비교), UVM의 `aio_base_test`(SV 기준 모델과 비교).

```text
   ecc_ref.py (Python) ──벡터──> secded_ecc_32 (RTL)        tb_ecc_vectors
                       └─벡터──> aio_ref_model (SV 클래스)   UVM 시작 시
                                       │
                                       └── 스코어보드가 이 모델로 RTL 동작을 예측
```

## 8. 실행

```powershell
python scripts\regress.py                # 전부 + 커버리지 병합
python scripts\regress.py --only uvm --seeds 10
python scripts\mutation.py               # mutation check
```

이 PC에서 `python`은 Microsoft Store 스텁이라 실행되지 않는다. `C:\msys64\ucrt64\bin\python3.exe`를 쓴다.

## 9. 아직 하지 않은 것

- 코드 커버리지(line/branch/toggle). xsim 2020.2의 `-cc_type`으로 수집할 수 있다
- 타이밍 파라미터(`T_SU/T_PW/T_HD/T_WAIT`)를 바꿔 가며 도는 회귀. 지금은 기본값과 mutation에서만 바뀐다
- `PAGE_WORDS`가 `MAX_PAGE_WORDS`보다 큰 실제 페이지(2 KB) 구성
- formal property: index bounds, 공정성 가정하의 eventual completion
- watchdog이 DMA 구간에서 터지는 경우(요청 철회 문제를 드러내는 테스트)
- gate-level simulation

## 10. 합격 기준

- 회귀 전부 PASS: PASS 문구가 있고, 금지 문구(`Fatal:`, `Error:`, `UVM_ERROR`, `NAND_MODEL VIOLATION`)가 없어야 한다
- 병합 기능 커버리지 100%, 또는 구멍마다 이유가 적혀 있을 것
- mutation 전부 killed
- Python ECC selftest PASS
- post-route setup/hold slack이 음수가 아닐 것 (또는 위반 경로와 대책이 [results.md](results.md)에 적혀 있을 것)
