# AIO NAND Controller SoC

에이아이오 설계직군 지원을 위해 만든 **합성 가능한 SystemVerilog 포트폴리오 프로젝트**입니다. RV32I CPU가 APB로 명령을 내리면, NAND 컨트롤러가 DMA로 메모리에서 페이지를 직접 가져와 ECC를 붙이고 ONFI 핀 타이밍으로 NAND에 쓰고 읽습니다. RTL, 핀 레벨 NAND 모델, UVM 검증 환경, 펌웨어, 합성·타이밍 분석까지 한 저장소에서 재현됩니다.

> 이 프로젝트는 공개된 회사/제품 정보를 바탕으로 만든 개인 포트폴리오이며 에이아이오의 실제 RTL, 내부 구조 또는 상용 IP를 재현한 것이 아닙니다.

## 왜 이 프로젝트인가

에이아이오는 독자 Controller SoC/Firmware를 기반으로 SD, eMMC, UFD 제품을 만듭니다. 채용 공고는 NAND Storage 컨트롤러 SoC, CPU Subsystem, AMBA Bus, Memory Controller, DMA, RTL simulation, verification 환경, synthesis/timing, Python script, SystemVerilog/UVM을 요구합니다.

세 제품은 host 쪽 프로토콜이 다를 뿐 **NAND 쪽 데이터 경로는 같습니다.** 이 프로젝트는 그 공통 부분을 작게, 그러나 CPU 명령부터 NAND 핀까지 끊기지 않게 만들었습니다.

| 공고의 요구 | 이 저장소에서 보여 주는 것 |
|---|---|
| NAND Storage 컨트롤러 SoC | ONFI async PHY, 커맨드 시퀀스, R/B#·WP# 처리, 핀 레벨 NAND 모델 |
| CPU Subsystem, AMBA Bus | RV32I + APB 마스터에 컨트롤러를 슬레이브로 통합, C 펌웨어 |
| Memory Controller, DMA | page buffer, ready/valid DMA 마스터, dual-port RAM |
| IP/SoC Verification 환경 | UVM(에이전트 3종, 예측 스코어보드, 기능 커버리지), SVA, mutation check |
| Synthesis / Timing Constraint | 핀·I/O 타이밍 제약(XDC), post-route 타이밍 보고서 |
| Python Verification Script | 회귀 러너, ECC 골든 모델, mutation 러너 |

상용 컨트롤러의 LDPC, wear leveling, FTL, host 인터페이스까지 10일 안에 얕게 흉내 내지 않았습니다. 대신 **작지만 끝까지 검증되는 데이터 경로**에 집중했습니다.

## 구조

```text
                     +--> RAM (포트 A)  <──────────────+
 ROM --> RV32I --> APB Master                          | 같은 메모리
 (펌웨어)            +--> UART / GPO                    |
                     +--> aio_nand_top                 |
                          |                            |
        +-----------------+----------------------------+---------+
        |  aio_nand_dma_ctrl (코어)                     | DMA     |
        |    APB 레지스터 → watchdog → 동작 FSM ────────+         |
        |                     |                                  |
        |          page buffer + SEC-DED ECC                     |
        |                     | cmd / w / r  (valid/ready 트랜잭션)|
        |  nand_onfi_phy (PHY)                                   |
        |    커맨드 시퀀스 → 사이클 엔진(SETUP/PULSE/HOLD)         |
        +---------------------+----------------------------------+
                              |
              CE# CLE ALE WE# RE# WP# R/B# DQ[7:0]
                              v
                           NAND Flash
```

- **코어**는 "무엇을 옮길지"만 알고 **PHY**는 "핀을 어떻게 흔들지"만 압니다. 경계가 valid/ready 트랜잭션이라 NAND 인터페이스가 바뀌어도 PHY만 갈아 끼우면 됩니다.
- CPU와 APB 마스터, UART는 이전에 직접 만든 RV32I 멀티사이클 SoC에서 가져왔습니다(`rtl/soc/cpu/`, `rtl/soc/periph/`).

### 페이지 하나를 쓰는 흐름

1. 펌웨어가 RAM에 데이터를 채운다 (APB)
2. 펌웨어가 컨트롤러 레지스터에 row / 메모리 주소 / 길이를 쓰고 START
3. 코어가 RAM에서 직접 읽어 온다 (DMA). 워드마다 ECC 7비트를 만든다
4. PHY가 `80h` → 주소 5바이트 → 데이터 → `10h`를 핀으로 내보낸다
5. PHY가 R/B#를 기다린 뒤 `70h`로 status를 읽어 성공 여부를 코어에 올린다
6. 펌웨어는 STATUS.DONE을 본다

CPU는 3~5 동안 데이터를 한 바이트도 만지지 않습니다.

## 구현 기능

| 기능 | PROGRAM | READ | ERASE | RESET |
|---|:---:|:---:|:---:|:---:|
| APB 설정/시작, 완료·오류 interrupt | O | O | O | O |
| Host DMA | memory → buffer | buffer → memory | - | - |
| ECC (32-bit 워드당 SEC-DED 7-bit) | 생성 | 1-bit 정정 / 2-bit 검출 | - | - |
| ONFI 시퀀스 | 80h…10h + status | 00h…30h | 60h…D0h + status | FFh |
| NAND status FAIL / WP# 보고 | O | - | O | - |
| R/B# timeout, watchdog, 스트림 중단 복구 | O | O | O | O |

전원 인가 직후에는 PHY가 스스로 `FFh`를 보내고 R/B#를 기다립니다.

## 검증

네 단계로 쌓았고 전부 자기 검증입니다. 자세한 내용은 [docs/verification_plan.md](docs/verification_plan.md), 숫자는 [docs/results.md](docs/results.md)에 있습니다.

| 단계 | 대상 | 방법 |
|---|---|---|
| Block | ECC | 단일 비트 전수 + Python 골든 벡터 1,000개 |
| Core | `aio_nand_dma_ctrl` | 트랜잭션 레벨 모델, 무작위 backpressure |
| IP | 코어 + PHY | 핀 레벨 NAND 모델(AC 타이밍 검사 포함), directed 16개 + UVM 6개 테스트 |
| SoC | CPU + 펌웨어 + 전체 | 펌웨어 셀프 테스트, 테스트벤치가 셀 에러 주입 |

- **예측 스코어보드**: 테스트가 기대값을 알려 주지 않습니다. 스코어보드가 NAND 셀을 직접 읽고 기준 ECC 모델로 결과를 계산한 뒤 레지스터, DMA, NAND 핀 시퀀스, 최종 셀 내용을 비교합니다.
- **기능 커버리지**: 동작 × 결과, 길이, 주소 모서리, 정정/정정불가 조합, WP#, backpressure, 동작 순서, 고친 비트 자리 32개. 회귀 전체를 합쳐 100%입니다.
- **Mutation check**: RTL에 버그를 하나씩 심어 회귀가 잡아내는지 확인합니다. 검사기가 실제로 물고 있다는 근거입니다.

### 결과 한눈에

| 항목 | 결과 |
|---|---|
| 회귀 | 13 / 13 PASS, 비교 432,636건 |
| 기능 커버리지 (UVM 병합) | 100%, 구멍 없음 |
| Mutation | 16 / 16 killed |
| SoC 펌웨어 테스트 | `AIO EBPR12 PASS`, NAND 타이밍 위반 0 |
| FPGA 자원 (Basys3, SoC 전체) | LUT 3,145 (15%), FF 4,150 (10%), BRAM 1 |
| 100 MHz post-route 타이밍 | setup WNS +0.561 ns, hold WHS +0.127 ns, 위반 0 (처음에는 −4.585 ns) |

세부 숫자와 재현 명령은 [docs/results.md](docs/results.md)에 있습니다.

### 통합하면서 찾은 것

1~3은 트랜잭션 레벨에서는 보이지 않다가 핀 레벨 모델을 붙이자 드러났고, 4~5는 배치배선 뒤 타이밍 분석에서 드러났습니다.

1. **지운 페이지가 정정 불가로 읽힌다.** 지운 페이지는 ECC 자리까지 0xFF인데, 데이터 0xFFFFFFFF의 올바른 ECC는 0x18입니다. PHY에서 ECC를 0x67과 XOR해 저장해서 all-FF가 유효한 codeword가 되게 했습니다.
2. **READ 도중의 실패를 코어가 받지 못한다.** R/B#가 돌아오지 않아 PHY가 실패를 보고해도 코어는 데이터만 기다리다 watchdog까지 갔습니다. 코어에 경로를 추가했습니다.
3. **확정 커맨드 직후 R/B#를 보면 안 된다.** R/B#가 내려오는 데 최대 tWB가 걸립니다. 대기를 줄이면 전원 인가 RESET부터 실패합니다.
4. **시뮬레이션에서 맞던 핀 타이밍이 실제 I/O 지연에서는 모자란다.** 배치배선 뒤 RE#가 핀에 닿는 데만 최대 13 ns가 걸려, RE# 3클럭(30 ns)으로는 읽기 데이터(tREA 20 ns)가 서기 전에 잡게 됩니다. FPGA 빌드는 4클럭으로 올렸습니다.
5. **멀티사이클 CPU를 STA가 1클럭 경로로 봤다.** 100 MHz에서 −4.585 ns였습니다. PC에서 출발한 값은 3클럭 뒤에야 잡힌다는 것을 multicycle 제약으로 알려 주고, 그 가정이 참인지를 시뮬레이션 assertion으로 매 명령 확인합니다.

고치지 않고 남긴 것은 [docs/design_spec.md](docs/design_spec.md) 9절에 이유와 함께 적었습니다.

## 바로 실행

요구 환경: Windows, Xilinx Vivado/XSim 2020.2 이상, Python 3.9 이상. 펌웨어를 다시 빌드할 때만 RISC-V GCC가 필요합니다(빌드된 `sw/fw.hex`가 들어 있습니다).

```powershell
cd D:\work\26_AI_COMP_1\aio

python scripts\regress.py             # 전 단계 회귀 + 기능 커버리지 병합  -> build\regress\report.md
python scripts\regress.py --only uvm --seeds 10
python scripts\mutation.py            # mutation check                     -> build\mutation\report.md

powershell -ExecutionPolicy Bypass -File scripts\run_impl.ps1    # SoC 합성 + 배치배선 + 타이밍 -> build\impl\
powershell -ExecutionPolicy Bypass -File scripts\run_sim.ps1     # 코어 단계만 빠르게
powershell -ExecutionPolicy Bypass -File scripts\run_synth.ps1   # 코어만 합성
```

`python`이 Microsoft Store 스텁인 PC에서는 `C:\msys64\ucrt64\bin\python3.exe`처럼 실제 인터프리터 경로를 씁니다. Vivado가 PATH에 없으면 `--vivado-bin C:\Xilinx\Vivado\2020.2\bin`을 붙입니다.

펌웨어를 고쳤을 때 (Git Bash):

```bash
cd sw && PATH=/c/msys64/ucrt64/bin:/c/msys64/usr/bin:$PATH make
```

## 디렉터리

```text
aio/
├─ rtl/
│  ├─ aio_nand_dma_ctrl.sv        코어 : APB 레지스터, DMA, page buffer, 동작 FSM
│  ├─ ecc/secded_ecc_32.sv        SEC-DED encoder/decoder
│  ├─ phy/nand_onfi_phy.sv        ONFI async PHY (사이클 엔진 + 시퀀서)
│  ├─ aio_nand_top.sv             IP 최상위 (코어 + PHY)
│  └─ soc/                        RV32I CPU, APB 마스터, dual-port RAM, UART, SoC/FPGA 최상위
├─ model/nand_model.sv            핀 레벨 NAND 동작 모델 + AC 타이밍 검사 + backdoor
├─ testbench/
│  ├─ tb_secded_ecc_32.sv         ECC 자기 일관성
│  ├─ tb_ecc_vectors.sv           ECC vs Python 골든 벡터
│  ├─ tb_aio_nand_dma_ctrl.sv     코어, 트랜잭션 레벨
│  ├─ tb_aio_nand_top.sv          코어 + PHY, 핀 레벨 directed
│  ├─ tb_aio_soc.sv               SoC + 펌웨어
│  └─ uvm/                        UVM 환경 (if, agents, scoreboard, coverage, sequences, tests)
├─ sw/                            펌웨어 (crt0.S, main.c, link.ld, 레지스터 헤더, fw.hex)
├─ scripts/
│  ├─ regress.py                  회귀 러너 + 커버리지 병합 + 보고서
│  ├─ mutation.py                 mutation check
│  ├─ ecc_ref.py                  ECC 골든 모델 + 벡터 생성
│  └─ run_*.ps1                   개별 실행
├─ syn/                           합성·구현 Tcl, XDC
├─ flist/                         컴파일 순서
└─ docs/
```

| 문서 | 내용 |
|---|---|
| [docs/design_spec.md](docs/design_spec.md) | 인터페이스, 레지스터, FSM, PHY, SoC, 알려진 한계 |
| [docs/verification_plan.md](docs/verification_plan.md) | 검증 단계, 검사기, UVM 구조, 테스트, 커버리지 |
| [docs/results.md](docs/results.md) | 회귀·커버리지·mutation·합성·타이밍 결과 |
| [docs/nand_onfi_notes.md](docs/nand_onfi_notes.md) | NAND/ONFI 배경 |
| [docs/interview_qna.md](docs/interview_qna.md) | 예상 질문과 답 |
| [docs/10_day_plan.md](docs/10_day_plan.md) | 남은 기간 계획 |

## 현재 한계

- ECC는 교육용 SEC-DED입니다. 워드당 25% 오버헤드이고 3-bit 에러는 오정정할 수 있습니다. 상용 NAND에는 BCH/LDPC가 필요합니다.
- page buffer가 레지스터 배열이라 한 번에 옮기는 크기가 작습니다(기본 64워드 = 256바이트). 실제 페이지 크기로 가려면 동기 읽기 SRAM으로 바꿔야 합니다.
- DMA 포트는 한 번에 요청 하나만 내는 단순 인터페이스이며 AXI4 master가 아닙니다.
- PHY는 ONFI async(SDR)만 지원합니다. NV-DDR/Toggle 같은 고속 모드는 없습니다. 타이밍은 합성 파라미터로 고정됩니다.
- CPU에 인터럽트가 없어 펌웨어가 폴링합니다.
- FTL, bad-block table, wear leveling, read-retry, power-loss recovery, host 인터페이스는 범위 밖입니다.
- NAND 모델의 타이밍 값은 대표값입니다. 실제 부품에 붙일 때는 데이터시트 값으로 바꿔야 합니다. FPGA 보드에 실제 NAND를 달아 돌려 보지는 않았습니다.

이 한계를 숨기지 않고, 어떤 요구사항에서 다음 구조로 확장할지를 설명하는 것이 프로젝트의 중요한 일부입니다.
