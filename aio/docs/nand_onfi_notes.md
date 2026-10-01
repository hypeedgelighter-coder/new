# NAND / ONFI 배경 노트

이 프로젝트의 PHY(`rtl/phy/nand_onfi_phy.sv`)와 NAND 모델(`model/nand_model.sv`)을 읽기 전에 알아야 하는 것만 모았다. 면접에서 "NAND가 뭐가 특별한가요?"에 답할 수 있는 수준이 목표다.

> 타이밍 숫자는 ONFI async timing mode 4 수준의 **대표값**이다. 실제 부품에 붙일 때는 그 부품의 데이터시트 값을 써야 한다. 이 문서의 숫자를 외워서 말하지 말고 "부품 데이터시트의 tXX를 클럭 수로 환산해 파라미터로 넣는다"고 설명하는 편이 안전하다.

## 1. NAND의 세 가지 물리 규칙

| 규칙 | 뜻 | 이 프로젝트에서 보이는 곳 |
|---|---|---|
| PROGRAM은 1→0만 된다 | 셀에 전하를 넣을 수만 있다 | 모델의 `mem = mem & page_reg`, TB의 "overwrite is bitwise AND" |
| 0→1은 ERASE뿐이고 블록 단위다 | 페이지 하나만 지울 수 없다 | `OP_ERASE`가 row가 속한 블록 64페이지를 전부 0xFF로 |
| 읽을 때 비트가 틀릴 수 있다 | 셀 전하가 새거나 옆 셀의 간섭을 받는다 | ECC, `flip_bit()` fault injection |

이 세 가지에서 컨트롤러가 해야 할 일이 전부 나온다.

- 덮어쓰기가 안 되므로 **다른 곳에 쓰고 주소표를 바꾼다** → FTL(Flash Translation Layer). 이 프로젝트 범위 밖.
- 블록마다 지울 수 있는 횟수가 정해져 있으므로 **골고루 쓴다** → wear leveling. 범위 밖.
- 비트가 틀리므로 **ECC를 붙여 쓰고 읽을 때 고친다** → 이 프로젝트의 `secded_ecc_32`.
- 출하 때부터 못 쓰는 블록이 있으므로 **bad block 표를 관리한다** → 범위 밖.

구조 용어: **page**(읽기/쓰기 단위, 예 2048 byte data + 64 byte spare) → **block**(지우기 단위, 예 64 page) → device. 주소는 `column`(페이지 안 바이트 위치)과 `row`(페이지 번호)로 나뉜다.

## 2. 핀

| 핀 | 방향(컨트롤러 기준) | 역할 |
|---|---|---|
| CE# | out | 칩 선택 |
| CLE | out | 1이면 지금 DQ가 **커맨드** |
| ALE | out | 1이면 지금 DQ가 **주소** |
| WE# | out | **상승 엣지**에 NAND가 DQ를 받아들인다 |
| RE# | out | 내리면 NAND가 DQ로 데이터를 내놓는다 |
| WP# | out | 0이면 PROGRAM/ERASE 금지 |
| R/B# | in | 0이면 내부 동작 중. **open-drain**(풀업 필요), 클럭과 무관하게 움직인다 |
| DQ[7:0] | inout | 커맨드 / 주소 / 데이터가 전부 이 8가닥으로 다닌다 |

클럭 핀이 없다. 타이밍은 전부 컨트롤러가 WE#/RE# 펄스 폭으로 만든다. 그래서 "비동기(async) 인터페이스"라고 부른다.

## 3. 사이클 네 종류

| 종류 | CLE | ALE | 스트로브 | DQ를 모는 쪽 |
|---|:---:|:---:|:---:|---|
| 커맨드 | 1 | 0 | WE# | 컨트롤러 |
| 주소 | 0 | 1 | WE# | 컨트롤러 |
| 데이터 쓰기 | 0 | 0 | WE# | 컨트롤러 |
| 데이터 읽기 | 0 | 0 | RE# | NAND |

`nand_onfi_cycle`이 이 한 사이클을 SETUP → PULSE → HOLD 세 구간으로 만든다.

## 4. 커맨드 시퀀스 (이 프로젝트가 쓰는 것)

```text
RESET    FFh ─(tWB)─ R/B#↓ ... R/B#↑
READ     00h ─ col col row row row ─ 30h ─(tWB)─ R/B#↓ ..tR.. R/B#↑ ─(tRR)─ RE# × N
PROGRAM  80h ─ col col row row row ─(tADL)─ WE# × N ─ 10h ─(tWB)─ R/B#↓ ..tPROG.. R/B#↑ ─ 70h ─(tWHR)─ RE#(status)
ERASE    60h ─ row row row ─ D0h ─(tWB)─ R/B#↓ ..tBERS.. R/B#↑ ─ 70h ─(tWHR)─ RE#(status)
```

- 커맨드가 **두 번** 나뉘어 간다(설정 + 확정). 확정 커맨드(30h/10h/D0h)가 가야 실제 동작이 시작된다. 그래서 PROGRAM 도중 10h 전에 멈추면 셀은 하나도 안 바뀐다 — UVM `aio_err_test`의 "watchdog이 스트림 중간에 터져도 셀이 그대로"가 이 성질을 확인한다.
- PROGRAM/ERASE는 성공했는지 **status를 읽어 봐야** 안다. bit0 = FAIL, bit6 = RDY, bit7 = WP#(1이면 쓰기 가능).
- 전원을 넣은 뒤 첫 커맨드는 RESET(FFh)이어야 한다. PHY가 리셋 직후 스스로 보낸다.

## 5. 타이밍 파라미터

| 이름 | 뜻 | 모델 값 | 컨트롤러가 만드는 값 (100 MHz, 기본 파라미터) |
|---|---|---:|---|
| tWP | WE# low 폭 | 12 ns | `T_PW`=3 → 30 ns |
| tWH | WE# high 폭 | 10 ns | HOLD 2 + 쉬는 1 + SETUP 1 → 40 ns |
| tDS / tDH | DQ setup / hold (WE#↑ 기준) | 10 / 5 ns | 40 / 20 ns |
| tCLS / tALS | CLE / ALE setup | 10 ns | 40 ns |
| tRP | RE# low 폭 | 12 ns | 30 ns |
| tREA | RE#↓ → 데이터 유효 | 20 ns | 30 ns 뒤에 샘플 → 여유 10 ns |
| tRHOH | RE#↑ 뒤 데이터 유지 | 15 ns | RE#를 올리는 엣지에서 샘플하므로 자동 충족 |
| tWB | 확정 커맨드 → R/B#↓ (**최대**) | 100 ns | `T_WAIT`=16 → 160 ns 기다린 뒤 R/B#를 본다 |
| tWHR | WE#↑ → RE#↓ (status 읽기) | 60 ns | 160 ns |
| tADL | 마지막 주소 → 첫 데이터 | 70 ns | 160 ns |
| tRR | R/B#↑ → RE#↓ | 20 ns | 160 ns |
| tR / tPROG / tBERS | 읽기 / 쓰기 / 지우기 busy 시간 | 2 / 6 / 12 us (시뮬레이션용으로 줄인 값) | R/B#를 기다린다 (길이에 의존하지 않는다) |

위 표의 "컨트롤러가 만드는 값"은 핀 지연이 0인 시뮬레이션 기준이다. 실제 FPGA에서는 RE#가 핀에 도착하는 데만 최대 13 ns가 걸려서 tREA 여유 10 ns가 사라진다. 그래서 FPGA 빌드는 `T_PW`를 4(40 ns)로 올렸다. 부품 데이터시트의 숫자를 클럭 수로 바꿀 때는 **칩 밖의 지연까지 더해서** 계산해야 한다는 교훈이다([results.md](results.md) 3절).

**tWB가 함정이다.** 확정 커맨드를 보내고 곧바로 R/B#를 보면 아직 1이다(내려오는 데 최대 tWB). "벌써 끝났네" 하고 읽어 버리면 쓰레기를 읽는다. 그래서 `P_WAIT_WB`에서 먼저 기다린 뒤에 `P_WAIT_RB`로 간다. 이 대기를 4클럭으로 줄이면 테스트가 첫 단계에서 실패한다(`docs/results.md`의 mutation 표).

## 6. 동기화가 필요한 신호와 필요 없는 신호

| 신호 | 동기화 | 이유 |
|---|---|---|
| R/B# | 2단 플롭 | NAND 내부 타이머로 움직인다. 우리 클럭과 아무 관계가 없다 → 메타스테이블 가능 |
| DQ(읽기) | 없음. 한 번에 샘플 | 우리가 RE#를 내린 시점으로부터 tREA 뒤에 나온다. 언제 안정되는지 **우리가 안다** |

면접에서 "DQ는 왜 동기화 안 했나요?"가 나올 수 있다. 답: 비동기 신호가 아니라 우리 스트로브에 대한 응답이고, 샘플 시점을 tREA보다 뒤로 잡아 setup을 보장한다. XDC의 `set_input_delay` + `set_multicycle_path -setup 3`이 그 계산을 STA에 알려 준다.

## 7. ECC를 페이지에 어떻게 놓는가

이 프로젝트는 32-bit 워드마다 7-bit SEC-DED를 붙이고 **워드 바로 뒤에** 놓는다(codeword interleave).

```text
flash byte :  0  1  2  3  4 | 5  6  7  8  9 | ...
              d0 d1 d2 d3 E0| d0 d1 d2 d3 E1| ...
              └── word 0 ───┘└── word 1 ───┘
```

- 장점: PHY가 5바이트를 읽자마자 한 워드를 코어에 넘길 수 있다. 버퍼가 필요 없다.
- 단점: 오버헤드가 25%(4바이트당 1바이트)다. 실제 제품은 512~1024바이트 덩어리에 BCH/LDPC를 걸어 오버헤드를 몇 %로 줄이고, 패리티를 spare 영역에 둔다.

**지운 페이지 문제.** 지운 페이지는 ECC 자리까지 0xFF다. 그런데 데이터 0xFFFFFFFF의 올바른 ECC는 0x18이다. 그대로면 지운 페이지를 읽을 때마다 "정정 불가"가 난다. 해결: ECC를 `0x67`(= 0x18 ^ 0x7F)과 XOR해서 저장한다. Hamming 코드는 선형이라 같은 상수를 쓸 때와 읽을 때 XOR해도 정정 능력이 그대로다. 실제 컨트롤러도 같은 이유로 ECC를 반전/스크램블해서 "all-FF가 유효한 codeword"가 되게 만든다.

## 8. 회사 제품과의 연결

SD / eMMC / UFD(USB) 컨트롤러는 **host 쪽 프로토콜**이 다를 뿐 NAND 쪽은 같다.

```text
 Host (SD / eMMC / USB) ── host IF ── [ CPU + FW(FTL) + 버퍼 + ECC + NAND IF ] ── NAND
                                        └────────── 컨트롤러 SoC ──────────┘
```

이 프로젝트가 만든 것은 오른쪽 절반(CPU subsystem, DMA, 버퍼, ECC, NAND IF)의 축소판이다. host IF와 FTL은 없다. 면접에서는 "NAND 쪽 데이터 경로를 핀 레벨까지 만들어 검증했고, host IF와 FTL은 다음 단계"라고 범위를 분명히 말한다.
