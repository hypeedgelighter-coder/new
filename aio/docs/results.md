# Reproducible Results

실행 환경: Xilinx Vivado/XSim 2020.2, target `xc7a35tcpg236-1`(Basys3), 100 MHz. 아래 숫자는 전부 이 저장소의 스크립트가 만든 것이고, 같은 명령으로 다시 만들 수 있다.

| 무엇 | 명령 | 결과물 |
|---|---|---|
| 회귀 + 커버리지 | `python scripts\regress.py` | `build/regress/report.md` |
| Mutation check | `python scripts\mutation.py` | `build/mutation/report.md` |
| SoC 배치배선 + 타이밍 | `scripts\run_impl.ps1` | `build/impl/*.rpt` |
| 코어만 합성 | `scripts\run_synth.ps1` | `build/synth/*.rpt` |

## 1. 회귀

**13 / 13 PASS.** 스코어보드와 테스트벤치가 수행한 비교는 합쳐서 432,636건이다.

| test | 단계 | seed | 결과 | 시뮬레이션 시간 | 내용 |
|---|---|---:|:---:|---:|---|
| ecc_unit | block | - | PASS | 5.4 us | 5,250 checks (105 워드 × 단일 비트 전수 + 2-bit) |
| ecc_vectors | block | - | PASS | 1 us | Python 골든 벡터 1,000개 (clean / data / parity / uncorr 각 250) |
| core_txn | core | - | PASS | 4.8 us | 8 scenarios, 트랜잭션 레벨 |
| top_pin | ip | - | PASS | 248 us | 16 scenarios, 핀 레벨, NAND 타이밍 위반 0 |
| uvm_smoke | ip | 1 | PASS | 46 us | 4 ops, 7,357 checks |
| uvm_ecc | ip | 1 | PASS | 795 us | 88 ops, 51,688 checks |
| uvm_err | ip | 1 | PASS | 568 us | 33 ops, 58,606 checks |
| uvm_bp | ip | 1 | PASS | 137 us | 15 ops, 16,900 checks |
| uvm_reset | ip | 1 | PASS | 76 us | 6 ops, 8,664 checks |
| uvm_rand_s1 | ip | 1 | PASS | 721 us | 84 ops, 84,822 checks |
| uvm_rand_s2 | ip | 2 | PASS | 743 us | 81 ops, 110,906 checks |
| uvm_rand_s3 | ip | 3 | PASS | 708 us | 86 ops, 88,443 checks |
| soc_fw | soc | - | PASS | 374 us | 펌웨어 셀프 테스트 |

UVM 테스트는 매번 시작할 때 SV 기준 ECC 모델을 Python 골든 벡터 1,000개와 대조한다.

### 기능 커버리지 (UVM 테스트 전체를 `xcrg`로 병합)

| 커버그룹 | 결과 |
|---|---:|
| `cg_op` (동작 × 결과, 길이, 주소, 정정/정정불가 조합, WP#, backpressure, 순서) | 100% |
| `cg_ecc` (워드별 판정, 고친 데이터 비트 자리 32개) | 100% |
| 합계 | 100%, 구멍 없음 |

처음 병합했을 때는 99.3%였다. `x_corr_uncorr`(한 페이지 안의 정정 수 × 정정 불가 수) 9칸 중 2칸이 비어 있었다. 무작위로는 잘 나오지 않는 조합(정정 0 + 정정 불가 여러 개 등)이어서 `aio_ecc_seq`에 9가지 조합을 직접 만드는 자극을 추가했다.

### SoC 펌웨어 테스트 로그

```text
[213705000] TB  : injected 1-bit fault (word 5)
[274035000] TB  : injected 2-bit fault (word 3)
[371875000] UART: AIO EBPR12 PASS
PASS: firmware self-test on aio_soc (uart = 'AIO EBPR12 PASS')
      NAND ops : reset=1 erase=2 program=1 read=5
      DMA      : 64 word read from RAM, 320 word written to RAM
      APB      : 1539 accesses to the NAND controller registers
      CPU      : 8258 instructions, multicycle assumption held on every one
      NAND timing violations : 0
```

UART 글자의 뜻: `E` erase, `B` 지운 페이지 확인, `P` program, `R` read 비교, `1` 1-bit 정정, `2` 2-bit 검출. 이 테스트는 FPGA 빌드와 같은 `T_PW=4`로 돈다.

## 2. Mutation check

**16 / 16 killed.** RTL에 버그를 하나씩 심고, 그 버그를 잡아야 하는 테스트만 골라 돌렸다. 지정한 테스트가 전부 FAIL로 잡았다.

| id | 심은 버그 | 잡아낸 테스트 | 어떻게 드러났나 |
|---|---|---|---|
| M01 | PHY: WE#/RE# 펄스 3 → 1 클럭 | top_pin, uvm_smoke | NAND 타이밍 위반 88건 / 271건 |
| M02 | PHY: 확정 커맨드 뒤 대기 16 → 4 클럭 | top_pin, uvm_smoke | R/B#를 너무 일찍 봄. 전원 인가 RESET부터 실패 |
| M03 | PHY: 지운 페이지용 ECC 마스크 제거 | top_pin, uvm_smoke | 지운 페이지가 정정 불가로 읽힘 |
| M04 | PHY: row 주소 바이트 순서 바꿈 | top_pin, uvm_smoke | NAND 주소 바이트 / 셀 내용 불일치 |
| M05 | PHY: status의 FAIL/WP 비트 무시 | top_pin, uvm_err | 실패해야 할 동작이 성공으로 보고됨 |
| M06 | PHY: 스트림이 끊겨도 FFh로 정리 안 함 | top_pin, uvm_err | PHY가 멈춰 다음 동작이 끝나지 않음 |
| M07 | PHY: 데이터 바이트 순서 뒤집힘 | top_pin, uvm_smoke | NAND data-in 바이트 불일치 |
| M08 | 코어: ECC 자리 에러를 정정 수에 안 셈 | top_pin, uvm_ecc | CORR_COUNT 불일치 |
| M09 | 코어: DMA 주소를 2씩 증가 | core_txn, uvm_smoke | DMA 주소 불일치 |
| M10 | 코어: READ 중 PHY 실패 경로 제거 | top_pin, uvm_err | 실패가 보고되지 않아 동작이 끝나지 않음 |
| M11 | 코어: 정정 불가인데 에러 코드 없음 | core_txn, uvm_ecc | ERROR_CODE 불일치 |
| M12 | 코어: 길이 상한 검사 누락 | core_txn, uvm_err | 거부돼야 할 길이가 실행됨 |
| M13 | ECC: 2-bit 에러를 "에러 없음"으로 | ecc_unit, ecc_vectors, uvm_ecc | 판정 불일치 |
| M14 | ECC: encoder의 overall parity 반전 | ecc_unit, ecc_vectors | Python 골든과 불일치 |
| M15 | SoC: RAM의 DMA 포트 주소 한 칸 밀림 | soc_fw | 펌웨어가 2단계(읽어 온 데이터 확인)에서 실패 : `AIO EF02` |
| M16 | SoC: 주소 디코더가 NAND 영역을 잘못 잡음 | soc_fw | 펌웨어가 0단계(ID 확인)에서 실패 : `AIO F00` |

이 표가 말해 주는 것은 "위 16가지 종류의 버그는 이 환경이 잡는다"까지다. 심지 않은 종류의 버그에 대해서는 아무 말도 하지 않는다.

## 3. SoC 구현 (`aio_fpga_top`, post-route)

### 자원

| | LUT | FF | BRAM | 비고 |
|---|---:|---:|---:|---|
| 전체 | 3,145 (15.1%) | 4,150 (10.0%) | 1 | F7 MUX 559, F8 MUX 226 |
| RV32I CPU | 1,516 | 1,027 | 0 | 레지스터 파일이 FF 992개 |
| 명령어 ROM | 203 | 0 | 0 | LUT ROM (조합 읽기) |
| APB 마스터 | 141 | 89 | 0 | |
| RAM (`apb_dpram`) | 24 | 1 | 1 | RAMB36 하나로 추론됨 |
| UART | 39 | 55 | 0 | |
| NAND 코어 (`aio_nand_dma_ctrl`) | 933 | 2,791 | 0 | page buffer 64 × 39 bit가 전부 FF |
| NAND PHY (`nand_onfi_phy`) | 291 | 167 | 0 | |

NAND 코어의 FF 2,791개 중 약 2,500개가 page buffer다(64워드 × (32 + 7)비트). F7/F8 MUX 대부분도 그 버퍼를 읽는 64:1 MUX다. `docs/10_day_plan.md` Day 7의 개선 과제가 이것을 BRAM으로 옮기는 것이다.

### 타이밍: 제약을 고치기 전과 후

| | setup WNS | 위반 끝점 | hold WHS | 최악 경로 |
|---|---:|---:|---:|---|
| 처음 (클럭 제약 + 단순 I/O 제약) | **−4.585 ns** | 1,562 | +0.127 ns | CPU: `PC → ROM → 레지스터 파일 → ALU → 레지스터 파일`, 17단 |
| 제약 수정 + `T_PW` 3 → 4 | **+0.561 ns** | 0 | +0.127 ns | NAND: `PHY sh → ECC decoder → 코어 error_code`, 10단 |

RTL 구조는 바꾸지 않았다. 바꾼 것은 제약 세 곳과 파라미터 하나다. 각각 "왜 위반이 났고, 왜 그 해결이 옳은가"를 설명할 수 있어야 한다.

**(1) CPU 경로 1,288개 → multicycle 3.**
이 CPU는 멀티사이클이다. PC와 레지스터 파일은 명령의 마지막 클럭에만 바뀌고, 거기서 출발한 값이 어딘가에 잡히는 것은 빨라야 execute의 끝(3클럭 뒤)이다. STA는 이것을 모르고 1클럭 경로로 봤다. `set_multicycle_path -setup 3 -hold 2 -from {PC, 레지스터 파일}`로 알려 줬다. 실제 datapath 지연은 20.4 ns(14단)로, 30 ns 안에 9.2 ns 여유로 들어온다.

multicycle 제약은 STA가 검증해 주지 않는다. 설계가 바뀌어 가정이 깨지면 STA는 통과하는데 칩이 죽는다. 그래서 `tb_aio_soc`에 assertion을 넣었다: "PC가 바뀐 뒤 2클럭 동안은 PC도, 레지스터 파일도, APB 마스터도 아무것도 잡지 않는다." 펌웨어가 실행한 8,258개 명령 전부에서 성립했다. 이 assertion을 3클럭으로 조이면 2,506번 걸린다(분기 명령이 정확히 3클럭째에 PC를 잡는다). 즉 3이 이 CPU의 정확한 한계다.

**(2) NAND 출력 → 창을 [1, 7] ns에서 [2, 13] ns로.**
처음에는 "모든 NAND 출력이 클럭 엣지 뒤 1~7 ns 안에 나와야 한다"고 적었고 −4.3 ns 위반이 났다. 클럭 삽입 지연과 출력 버퍼만으로 11 ns가 나오기 때문이다. 그런데 NAND에는 클럭이 가지 않는다. NAND가 보는 것은 핀들 사이의 시간 차이(skew)뿐이다. 클럭 수로 확보한 가장 작은 여유가 tDH의 15 ns(설계 20 ns, 요구 5 ns)이므로 skew가 그보다 작기만 하면 된다. 창을 [2, 13] ns(skew ≤ 11 ns)로 다시 잡았다. 조일 이유가 없는 곳을 조였던 것이어서 설계가 아니라 제약을 고쳤다.

**(3) NAND 입력 DQ → `T_PW` 3 → 4.**
(2)의 실제 숫자를 넣으면 RE#가 핀에 도착하는 데 최대 13 ns, NAND가 데이터를 내놓는 데 tREA 20 ns, 보드 1 ns로 합계 34 ns다. RE#를 3클럭(30 ns)만 잡으면 데이터가 서기 전에 샘플한다. 시뮬레이션은 핀 지연이 0이라 3으로도 통과했지만 실제 I/O 지연에서는 모자란다. FPGA 빌드의 `T_PW`를 4(40 ns)로 올리고 입력 제약을 "지연 34 ns, 4-cycle 경로"로 적었다. 읽기 한 바이트가 10 ns 느려진다.

### 경로 종류별 최악 slack (수정 후)

| 경로 | slack | 설명 |
|---|---:|---|
| NAND IP 내부 (1클럭) | +0.561 ns | `sh` → ECC decoder → `error_code` CE, 10단. **지금의 critical path** |
| CPU (3-cycle) | +9.236 ns | datapath 20.4 ns, 14단 |
| NAND 출력, 가장 늦은 핀 | +0.589 ns | `nand_dq[0]` (3-state 제어 경로) |
| NAND 출력, 가장 이른 핀 | +0.799 ns | `nand_ale` |
| NAND DQ 입력 setup (4-cycle) | +3.022 ns | |
| NAND DQ 입력 hold | +0.127 ns | 입력 플롭이 IOB 안에 있다 |
| 리셋 recovery | +0.926 ns | 동기화된 리셋 → NAND IP의 비동기 리셋 핀 |

### critical path를 어떻게 줄일 것인가

지금의 최악 경로는 PHY가 모은 5바이트(`sh`)가 ECC decoder(조합 10단)를 지나 코어의 `error_code`/`page_data`에 들어가는 경로다. 여유가 0.56 ns밖에 없다.

- ECC 판정 결과를 한 번 플롭에 받는다(파이프라인 1단). PHY는 한 워드를 모으는 데 수십 클럭을 쓰므로 1클럭 늦어져도 처리량은 그대로다.
- page buffer를 BRAM으로 바꾸면 2,048개 플롭의 CE로 가던 고팬아웃 배선이 사라진다(제약 수정 전 분석에서 `PHY state → page_data` 경로가 배선 지연 86%였다).

### 남아 있는 경고

| 경고 | 건수 | 판단 |
|---|---:|---|
| `[Constraints 18-5573]` `nand_dq_oe`를 IOB에 못 넣음 | 8 | 플롭 하나가 8핀의 3-state를 몬다. 방향 전환이 1~2 ns 늦을 뿐이고 출력 창 안이다. 핀마다 플롭을 두면 없앨 수 있다 |
| `[DRC REQP-1839]` RAMB36 제어 입력이 비동기 리셋 플롭에서 옴 | 20 | 리셋이 클럭과 겹치면 BRAM 내용이 깨질 수 있다는 Xilinx 권고. RAM 내용은 리셋 뒤 펌웨어가 다시 쓴다. NAND IP를 동기 리셋으로 바꾸면 사라진다 |
| `[Designutils 20-1567]` 합성은 multicycle `-hold`를 쓰지 않음 | 2 | 구현 단계에서는 적용된다 |

### 하지 않은 것

- 비트스트림을 만들어 보드에 올리지 않았다. Basys3에는 NAND가 없고, Pmod에 실제 NAND를 달아 확인하지 않았다.
- NAND의 AC 타이밍 값은 대표값이다. 실제 부품으로 바꾸면 입력 지연(34 ns)과 `T_PW`를 다시 계산해야 한다.
- 온도·전압 코너는 Vivado의 기본(slow/fast) 분석까지만 봤다.

## 4. 코어 단독 합성 (`aio_nand_dma_ctrl`, post-synthesis 추정)

| Metric | Result |
|---|---:|
| Slice LUTs | 1,164 |
| Slice registers | 2,835 |
| F7 / F8 muxes | 312 / 156 |
| BRAM tiles | 0 |
| 100 MHz worst setup slack | +2.998 ns |

Reports: `build/synth/utilization.rpt`, `build/synth/timing_summary.rpt`. 합성 직후의 추정치라 배선 지연이 들어 있지 않다. 위 3절의 post-route 숫자가 실제에 가깝다(같은 코어가 SoC 안에서는 여유 +0.56 ns).

처음 이 저장소에 있던 코어의 숫자는 LUT 1,155 / slack +3.060 ns였다. READ 도중 PHY 실패를 받는 분기를 넣은 뒤 LUT 9개가 늘었다.

## 5. Python ECC model

```text
PASS: SEC-DED golden model - 1005 words, all 32 data-bit faults,
all 7 ECC-bit faults, and 10 random double-bit faults per word
```

## 6. 통합하면서 찾은 것

| 발견 | 어디서 드러났나 | 조치 |
|---|---|---|
| 지운 페이지가 워드마다 정정 불가로 읽힘 | 핀 레벨 모델을 붙이자마자 (`top_pin` TEST 2) | PHY에서 ECC를 0x67과 XOR |
| READ 도중 PHY 실패를 코어가 못 받음 | R/B# 고착 시나리오 (`top_pin` TEST 14) | 코어 `ST_NAND_READ`에 분기 추가 |
| tWB 전에 R/B#를 보면 안 됨 | 대기를 줄인 mutation (M02) | `P_WAIT_WB` 상태 |
| 100 MHz에서 CPU 경로 −4.6 ns | post-route 타이밍 | multicycle 제약 + assertion |
| I/O 절대 지연을 조인 제약이 틀렸음 | post-route 타이밍 | skew 창으로 다시 잡음 |
| RE# 3클럭으로는 실제 I/O에서 부족 | post-route 타이밍 | FPGA 빌드 `T_PW=4` |
| 커버리지 구멍 `x_corr_uncorr` 7/9 | 커버리지 병합 | 조합 9가지를 직접 만드는 자극 추가 |
