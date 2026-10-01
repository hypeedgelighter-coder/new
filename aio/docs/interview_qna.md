# 면접 예상 질문과 답

답은 전부 이 저장소의 코드로 증명할 수 있는 것만 적었다. 말할 때는 **파일 이름과 신호 이름을 같이** 대는 연습을 한다("PHY의 `P_WAIT_WB` 상태에서…"). 구체적인 이름이 나오면 직접 다뤄 봤다는 것이 전해진다.

채용 공고 항목과의 대응은 맨 아래 표에 있다.

---

## A. 프로젝트 전체

**Q1. 이 프로젝트를 한 문장으로 설명해 보세요.**
RV32I CPU가 APB로 명령을 내리면, NAND 컨트롤러가 DMA로 메모리에서 페이지를 직접 가져와 ECC를 붙이고 ONFI 핀 타이밍으로 NAND에 쓰고 읽는 SoC입니다. RTL, 핀 레벨 NAND 모델, UVM 환경, 펌웨어, 합성·타이밍까지 한 저장소에서 재현됩니다.

**Q2. 왜 이 주제를 골랐나요?**
공고의 담당업무가 "NAND 컨트롤러 SoC, CPU Subsystem, AMBA, Memory Controller, DMA"였습니다. 그 데이터 경로를 작게라도 끝에서 끝까지 직접 만들어 보면 각 블록이 왜 필요한지 설명할 수 있다고 생각했습니다.

**Q3. 어디까지가 본인이 만든 범위고 어디가 범위 밖인가요?**
만든 것: APB 레지스터, DMA 마스터, 페이지 버퍼, SEC-DED ECC, ONFI async PHY, CPU 통합, 펌웨어, 검증 환경. 범위 밖: host 인터페이스(SD/eMMC/USB), FTL, wear leveling, bad block 관리, BCH/LDPC, Toggle/NV-DDR 같은 고속 PHY. 범위 밖인 것은 "왜 필요한지"까지는 설명할 수 있습니다(`docs/nand_onfi_notes.md` 1절).

**Q4. 계층을 어떻게 나눴고 왜 그렇게 나눴나요?**
코어(`aio_nand_dma_ctrl`)는 "무엇을 옮길지", PHY(`nand_onfi_phy`)는 "핀을 어떻게 흔들지"만 압니다. 경계는 valid/ready 트랜잭션입니다. NAND가 Toggle DDR로 바뀌면 PHY만 바꾸면 되고, DMA가 AXI로 바뀌면 코어의 메모리 포트만 바꾸면 됩니다. 검증도 계층별로 따로 할 수 있었습니다(코어만: `tb_aio_nand_dma_ctrl`, 코어+PHY: `tb_aio_nand_top`/UVM, 전체: `tb_aio_soc`).

---

## B. NAND / PHY

**Q5. NAND에 페이지를 쓰는 과정을 핀 수준에서 설명해 보세요.**
80h(커맨드, CLE=1) → 주소 5바이트(ALE=1: column 2, row 3) → tADL 대기 → 데이터 바이트들(WE# 펄스마다 1바이트) → 10h(확정) → tWB 대기 → R/B#가 다시 1이 될 때까지 대기 → 70h → status 읽기. bit0가 1이면 실패입니다.

**Q6. 확정 커맨드를 보낸 직후에 R/B#를 바로 보면 안 되는 이유는?**
R/B#는 확정 커맨드 뒤 최대 tWB 안에 내려옵니다. 그 전에 보면 아직 1이라 "벌써 끝났다"고 오해합니다. 그래서 `P_WAIT_WB`에서 먼저 기다립니다. 실제로 대기를 4클럭으로 줄여 보면 전원 인가 직후 RESET조차 끝나기 전에 다음으로 넘어가서 테스트가 실패합니다.

**Q7. R/B#는 동기화하고 DQ는 동기화하지 않았습니다. 왜죠?**
R/B#는 NAND 내부 타이머로 움직여서 우리 클럭과 무관합니다. 메타스테이블이 생길 수 있으니 2단 플롭을 거칩니다. DQ는 우리가 RE#를 내린 뒤 tREA 안에 안정되는, 시점을 아는 신호입니다. RE#를 `T_PW` 클럭 동안 잡아 두고 올리는 엣지에서 한 번에 잡습니다. 이 가정은 XDC에 `set_input_delay` 34 ns + `set_multicycle_path -setup 4`로 적어 STA가 확인하게 했습니다. (시뮬레이션 기본값은 3클럭인데, 배치배선 뒤 I/O 지연을 넣어 보니 부족해서 FPGA 빌드는 4클럭입니다.)

**Q8. WE#, RE#를 조합 논리로 만들면 왜 안 되나요?**
글리치가 생기면 NAND는 그것을 진짜 펄스로 받아들입니다. 커맨드나 데이터가 한 번 더 들어갑니다. 그래서 `nand_onfi_cycle`의 모든 출력은 플롭에서 바로 나가고, XDC에서 IOB에 넣어 핀 간 지연 차이도 줄였습니다.

**Q9. DQ를 inout으로 쓰지 않고 o/oe/i 세 개로 나눈 이유는?**
칩 내부에는 3-state가 없습니다. 3-state 버퍼는 패드에 하나만 있어야 합니다. IP 경계를 o/oe/i로 두면 FPGA든 ASIC이든 최상위에서 패드 셀만 붙이면 됩니다(`aio_fpga_top`의 `assign nand_dq = oe ? o : 'z`).

**Q10. 코어가 중간에 포기하면(PHY는 아직 동작 중) 어떻게 되나요?**
코어의 watchdog이 터지면 코어는 IDLE로 가 버리고, PHY는 데이터 스트림의 handshake가 끊긴 것을 봅니다. `STALL_W` 클럭 동안 handshake가 없으면 PHY가 NAND에 FFh를 보내 정리하고 IDLE로 돌아옵니다. UVM `aio_err_test`에서 READ와 PROGRAM 둘 다 확인했고, PROGRAM의 경우 10h가 나가기 전이라 셀이 전혀 바뀌지 않는 것(원자성)을 backdoor로 확인합니다.

**Q11. 지운 페이지를 읽으면 ECC 에러가 나지 않나요?**
그대로 두면 납니다. 지운 페이지는 ECC 자리까지 0xFF인데 0xFFFFFFFF의 올바른 ECC는 0x18이라서요. PHY에서 ECC를 0x67과 XOR해 저장해서 all-FF가 유효한 codeword가 되게 했습니다. 트랜잭션 레벨 테스트벤치에서는 보이지 않던 문제인데, 핀 레벨 모델을 붙이자마자 드러났습니다.

---

## C. 코어 / 버스 / DMA

**Q12. APB 전송 한 번을 설명해 보세요.**
SETUP(psel=1, penable=0) 한 클럭 → ACCESS(penable=1), pready가 1인 클럭에 끝납니다. SETUP과 ACCESS 동안 주소·데이터·방향이 바뀌면 안 됩니다. `aio_uvm_if.sv`의 assertion 세 개가 이것을 감시합니다.

**Q13. DMA가 왜 필요한가요? CPU가 직접 옮기면 안 되나요?**
이 CPU는 명령 하나에 4~7클럭이 걸리고, 워드 하나를 옮기려면 lw/sw/증가/비교/분기가 필요합니다. DMA는 워드당 몇 클럭이면 됩니다. 시뮬레이션에서 펌웨어는 레지스터 4개를 쓰고 STATUS만 폴링하고, 64워드는 컨트롤러가 RAM의 두 번째 포트로 직접 가져갑니다(`apb_dpram`의 포트 B).

**Q14. valid/ready에서 지켜야 하는 규칙은?**
(1) 전송은 valid와 ready가 같은 클럭에 1일 때만 일어난다. (2) valid를 올렸으면 ready가 올 때까지 내용을 바꾸거나 valid를 내리면 안 된다. (3) valid가 ready를 기다리며 만들어지면 안 된다(데드락). 코어의 `word_index`는 handshake가 성립한 클럭에만 증가하고, UVM의 메모리 에이전트가 ready를 15%까지 떨어뜨려 이것을 흔듭니다.

**Q15. 이 설계에서 그 규칙을 어기는 곳이 있나요?**
있습니다. watchdog이 DMA 요청을 기다리는 중에 터지면 `mem_req_valid`가 ready 없이 내려갑니다. 지금의 단순 메모리 포트에서는 문제가 없지만 AXI로 바꾸면 위반입니다. AXI 어댑터를 만들 때는 "진행 중인 요청은 끝까지 보내고 나서 에러로 간다"로 바꿔야 합니다. `docs/design_spec.md`의 알려진 한계에 적어 두었습니다.

**Q16. 페이지 버퍼가 레지스터 배열입니다. 문제가 뭔가요?**
64워드 × 39비트가 전부 플롭이고, 읽기가 조합 MUX라 면적과 타이밍을 둘 다 잡아먹습니다(합성 결과에서 FF와 F7/F8 MUX가 그만큼 나옵니다). 실제 페이지 크기(2KB 이상)로 가려면 동기 읽기 SRAM/BRAM으로 바꾸고, 읽기 지연 한 클럭을 FSM에 넣어야 합니다. 남은 기간의 개선 과제로 잡아 두었습니다(`docs/10_day_plan.md` Day 7).

---

## D. ECC

**Q17. SEC-DED가 어떻게 1비트는 고치고 2비트는 검출하나요?**
Hamming 패리티 6개가 "틀린 비트의 자리 번호"(syndrome)를 만들고, 전체 패리티 1개가 "틀린 비트 수가 홀수인가"를 알려 줍니다.

| syndrome | 전체 패리티 | 판정 |
|---|---|---|
| 0 | 맞음 | 에러 없음 |
| 0 | 틀림 | 전체 패리티 비트 자체가 깨짐 |
| ≠0 | 틀림 | 1비트 에러. syndrome이 가리키는 자리를 뒤집는다 |
| ≠0 | 맞음 | 2비트 에러. 고칠 수 없다 |

**Q18. 3비트가 틀리면요?**
1비트 에러로 오인해서 엉뚱한 비트를 "고칠" 수 있습니다(오정정). SEC-DED의 한계입니다. UVM `aio_ecc_test`에 3비트 케이스가 있고, 이때 RTL이 기준 모델과 똑같이 행동하는지를 봅니다. 실제 NAND에서 BCH/LDPC를 쓰는 이유가 이것입니다.

**Q19. 왜 BCH나 LDPC가 아닌가요?**
10일 안에 인코더·디코더·에러 주입·검증까지 끝낼 수 있는 크기를 골랐습니다. 코어와 ECC의 경계가 `(data, ecc)` 쌍이라 엔진만 바꿀 수 있는 구조입니다. 다만 BCH는 디코딩이 여러 클럭(syndrome → Berlekamp-Massey → Chien search)이라 코어에 "ECC 결과를 기다리는 상태"가 추가돼야 합니다.

**Q20. ECC RTL이 맞다는 것을 어떻게 믿나요?**
세 가지 구현이 서로를 확인합니다. RTL(`secded_ecc_32.sv`), Python 골든 모델(`scripts/ecc_ref.py`), UVM 스코어보드의 SV 기준 모델(`aio_ref_model`, 계산 방식이 RTL과 다름). Python이 만든 벡터 1000개로 RTL과 SV 기준 모델을 각각 검사합니다.

---

## E. 검증

**Q21. 검증 환경 구조를 설명해 보세요.**
APB 에이전트(active)가 레지스터를 두드리고, 메모리 에이전트(reactive)가 DMA에 응답하며 backpressure를 무작위로 겁니다. NAND 핀 모니터(passive)가 핀에서 커맨드 시퀀스를 다시 조립합니다. 스코어보드는 START가 쓰이는 순간 NAND 셀을 backdoor로 읽어 결과를 예측하고, DONE에서 STATUS·카운터·DMA 주소와 데이터·NAND 핀 시퀀스·최종 셀 내용을 전부 비교합니다.

**Q22. 스코어보드가 "예측"한다는 게 무슨 뜻인가요?**
테스트가 기대값을 알려 주지 않습니다. 테스트는 셀을 뒤집기만 하고, 스코어보드가 그 셀을 직접 읽어 기준 ECC 모델로 "이 읽기는 정정 2개, 정정 불가 1개로 끝나야 한다"를 계산합니다. 그래서 무작위 테스트를 그대로 돌릴 수 있습니다.

**Q23. 테스트가 통과했다는 걸 어떻게 믿나요? 검사가 빠져 있을 수도 있잖아요.**
일부러 버그를 넣어 봤습니다(mutation). 펄스 폭을 1클럭으로 줄이면 모델이 tRP/tWP 위반을 찍고, ECC 마스크를 빼면 지운 페이지 테스트가 실패하고, 주소 바이트 순서를 바꾸면 스코어보드가 잡습니다. 결과는 `docs/results.md`에 표로 있습니다.

**Q24. 기능 커버리지에는 무엇을 넣었나요?**
동작 × 결과 코드, 길이(1/중간/최대/0/초과), 주소(블록·페이지의 처음/중간/끝), 한 페이지 안의 정정·정정불가 개수 조합, WP#, backpressure 단계, 앞 동작 → 이번 동작, 그리고 데이터 32비트 자리를 하나씩 다 고쳐 봤는지. 테스트별 DB를 `xcrg`로 합쳐 회귀 전체의 숫자를 봅니다.

**Q25. 방향성(directed) 테스트와 무작위 테스트를 어떻게 나눴나요?**
만들기 어려운 상황(R/B# 고착, watchdog이 스트림 중간에 터짐, WP#, 리셋)은 방향성으로 정확히 만들고, 조합이 많은 것(주소·길이·backpressure·에러 위치)은 무작위에 맡겼습니다. 무작위가 어디까지 갔는지는 커버리지로 확인합니다.

**Q26. 검증하면서 찾은 버그가 있나요?**
시뮬레이션에서 둘, 타이밍 분석에서 하나, 코드 리뷰에서 하나를 찾았습니다. (1) 지운 페이지의 ECC 불일치. (2) READ 도중 PHY가 실패를 보고해도 코어가 받을 경로가 없어서 watchdog까지 기다리던 것 — `ST_NAND_READ`에 `nand_done && nand_fail` 분기를 추가했습니다. (3) 시뮬레이션에서는 통과하던 RE# 3클럭이 실제 I/O 지연에서는 부족한 것 — post-route 분석에서 드러나 `T_PW`를 4로 올렸습니다. (4) watchdog이 대기 중인 DMA 요청을 철회하는 것 — 코드를 읽다 찾았고, 고치지 않고 한계로 문서화했습니다.

---

## F. 합성 / 타이밍

**Q27. 타이밍 제약은 어떻게 잡았나요?**
네 묶음입니다. (1) 클럭 100 MHz. (2) CPU는 멀티사이클이라 PC와 레지스터 파일에서 출발하는 경로에 `set_multicycle_path -setup 3 -hold 2`. (3) NAND 출력은 `set_output_delay`로 모든 핀이 클럭 엣지 뒤 2~13 ns 창 안에 나오게 묶어 핀 간 skew를 11 ns 이하로 제한(클럭 수로 확보한 가장 작은 여유 15 ns보다 작음). NAND 입력 DQ는 입력 지연 34 ns에 4-cycle multicycle. (4) 버튼·스위치·R/B#·UART RX는 2단 동기화기를 거치므로 false path.

**Q27-1. 처음부터 타이밍이 맞았나요?**
아니요. 처음 배치배선에서 setup WNS가 −4.585 ns, 위반 끝점이 1,562개였습니다. 원인이 셋이었습니다. CPU 경로 1,288개는 멀티사이클 CPU를 STA가 1클럭 경로로 본 것이라 multicycle 제약으로 풀었습니다(실제 지연 20.4 ns, 30 ns 안). NAND 출력은 제가 절대 지연을 1~7 ns로 조였던 것이 잘못이었습니다. NAND에는 클럭이 안 가므로 의미가 있는 것은 핀 간 skew뿐이라 제약을 고쳤습니다. 그리고 그 실제 숫자를 넣으니 RE# 3클럭(30 ns)으로는 읽기 데이터가 서기 전에 잡게 돼서 FPGA 빌드의 `T_PW`를 4로 올렸습니다. 결과는 WNS +0.561 ns, 위반 0입니다.

**Q27-2. multicycle 제약이 틀리면 어떻게 되나요? 어떻게 믿나요?**
STA는 통과하는데 칩이 죽습니다. 제약은 STA가 검증해 주지 않으니까요. 그래서 시뮬레이션에 assertion을 넣었습니다: "PC가 바뀐 뒤 2클럭 동안은 PC, 레지스터 파일, APB 마스터가 아무것도 잡지 않는다." 펌웨어가 실행한 8,258개 명령 전부에서 성립했고, 조건을 3클럭으로 조이면 분기 명령 때문에 2,506번 걸립니다. 그래서 3이 정확한 값입니다. 누가 `control_unit`의 상태를 줄이면 이 assertion이 먼저 터집니다.

**Q28. multicycle path와 false path의 차이는?**
multicycle은 "이 경로는 N클럭 안에만 도착하면 된다"이고 여전히 타이밍을 검사합니다. false path는 "검사하지 않는다"입니다. DQ 입력은 4클럭 뒤에 잡는다는 관계가 있으므로 multicycle이고, R/B#는 클럭과 관계가 없고 동기화기가 받으므로 false path입니다. false path를 남용하면 진짜 위반을 가립니다.

**Q28-1. multicycle에 `-hold`는 왜 같이 거나요?**
`-setup N`만 걸면 hold 검사 엣지도 같이 뒤로 밀려서, 도구가 데이터 경로에 (N−1)클럭만큼의 지연을 넣으려고 합니다. 출발과 도착이 같은 클럭인 경우 hold는 원래대로 출발 엣지에서 검사해야 하므로 `-hold N−1`로 되돌립니다.

**Q29. 가장 느린 경로는 어디인가요?**
제약을 고친 뒤의 critical path는 NAND IP 안입니다. PHY가 모은 5바이트(`sh` 레지스터)가 ECC decoder를 지나 코어의 `error_code` CE로 들어가는 경로로, 로직 10단에 여유 +0.561 ns입니다. 줄이는 방법은 둘입니다. ECC 판정 결과를 플롭에 한 번 받는 것(PHY가 한 워드를 모으는 데 수십 클럭을 쓰므로 처리량 손해가 없음), 그리고 page buffer를 BRAM으로 바꿔 플롭 2천여 개의 CE로 가는 고팬아웃 배선을 없애는 것입니다.

**Q30. setup 위반과 hold 위반은 각각 어떻게 고치나요?**
setup: 경로를 짧게(로직 단수 줄이기, 파이프라인 추가, 리타이밍) 하거나 클럭을 느리게. hold: 데이터 경로에 지연을 넣는다(도구가 버퍼를 삽입). 클럭 주파수를 바꿔도 hold는 안 고쳐진다는 점이 핵심입니다.

**Q31. 리셋은 어떻게 처리했나요?**
버튼은 비동기로 들어오므로 `aio_fpga_top`에서 "비동기 assert, 동기 deassert" 동기화기를 거칩니다. 리셋이 클럭 엣지 근처에서 풀리면 플롭마다 풀리는 시점이 갈릴 수 있기 때문입니다. UVM `aio_reset_test`는 READ 데이터 구간 한가운데와 PROGRAM의 DMA 구간에서 리셋을 걸고 그 뒤에 정상 동작하는지 봅니다.

---

## G. 펌웨어 / SoC

**Q32. 펌웨어는 컨트롤러를 어떻게 쓰나요?**
레지스터 넷(ROW, HOST_ADDR, PAGE_WORDS, CONTROL)을 쓰고 STATUS.DONE을 폴링합니다. `sw/main.c`의 `nand_op()` 함수 하나가 전부입니다.

**Q33. 왜 인터럽트를 쓰지 않았나요?**
이 CPU(직접 만든 RV32I 멀티사이클)에 인터럽트가 없습니다. 컨트롤러는 irq를 내보내고 있고 SoC에서는 핀(LED)으로만 나갑니다. CPU에 CSR과 trap을 넣으면 폴링을 없앨 수 있습니다.

**Q34. 펌웨어에 문자열 리터럴이 하나도 없는데 이유가 있나요?**
명령어 ROM이 CPU에 직결이라 데이터 버스로 읽을 수 없습니다(하버드 구조). `.rodata`가 생기면 없는 주소를 읽게 됩니다. 그래서 링커 스크립트에 `ASSERT(SIZEOF(.rodata) == 0)`을 넣어 빌드 단계에서 막았습니다.

---

## 채용 공고 항목 ↔ 이 저장소

| 공고 | 보여 줄 것 |
|---|---|
| NAND Storage 컨트롤러 SoC | `rtl/aio_nand_top.sv`, `rtl/phy/nand_onfi_phy.sv`, `model/nand_model.sv` |
| CPU Subsystem, AMBA Bus | `rtl/soc/aio_soc.sv`, `rtl/soc/periph/apb_master.sv` |
| Memory Controller, DMA | `rtl/aio_nand_dma_ctrl.sv`, `rtl/soc/periph/apb_dpram.sv` |
| RTL 설계 및 Simulation | `scripts/regress.py`, `scripts/run_sim.ps1` |
| IP/SoC Verification 환경 | `testbench/uvm/` |
| SoC Top Simulation | `testbench/tb_aio_soc.sv` + `sw/main.c` |
| Synthesis / Timing Constraint | `syn/aio_fpga_top.xdc`, `syn/impl_fpga.tcl`, `build/impl/*.rpt` |
| Python Verification Script | `scripts/regress.py`, `scripts/ecc_ref.py`, `scripts/mutation.py` |
| SystemVerilog / UVM | `testbench/uvm/` |
