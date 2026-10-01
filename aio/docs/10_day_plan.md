# 10-Day Completion and Interview Plan

저장소에는 이제 코어, ONFI PHY, 핀 레벨 NAND 모델, SoC 통합, 펌웨어, UVM 환경, 회귀·mutation 스크립트, FPGA 구현 흐름이 들어 있다. 남은 10일은 기능을 더 얹는 데 쓰지 않는다. **전부를 자기 말로 설명할 수 있게 만들고, 한 군데는 직접 고쳐서 전후 숫자를 만드는 데** 쓴다.

면접관이 확인하려는 것은 "이 코드가 있느냐"가 아니라 "이 사람이 이해하고 있느냐"다. 그래서 매일의 완료 기준을 "읽었다"가 아니라 "안 보고 설명한다 / 직접 바꿔서 결과를 봤다"로 잡았다.

| Day | 할 일 | 직접 해 볼 것 | 완료 기준 |
|---:|---|---|---|
| 1 | 전체 그림 + NAND 기초. `README.md`, `docs/nand_onfi_notes.md` | `python scripts\regress.py`를 직접 돌린다. `tb_aio_nand_top`을 xsim GUI로 열어 PROGRAM 한 번의 파형을 본다 | 80h-주소-데이터-10h-R/B#-70h를 파형에서 손가락으로 짚는다. NAND 규칙 세 가지를 안 보고 말한다 |
| 2 | PHY. `rtl/phy/nand_onfi_phy.sv` 전체 | `aio_nand_top.sv`의 `T_PW`를 1로, `T_WAIT`를 4로 바꿔 `--only top_pin`을 돌려 본다. 어떤 위반이 몇 건 나오는지 본 뒤 되돌린다 | PHY의 상태 16개를 종이에 그린다. tWB를 기다려야 하는 이유를 설명한다 |
| 3 | 코어. `rtl/aio_nand_dma_ctrl.sv` 전체 | `tb_aio_nand_dma_ctrl` 파형에서 `mem_req_valid/ready`가 엇갈릴 때 `word_index`가 멈춰 있는 구간을 캡처한다 | PROGRAM/READ/ERASE의 상태 전이를 종이에 그린다. 9절 "알려진 한계" 표의 각 줄을 코드에서 찾는다 |
| 4 | ECC. `rtl/ecc/secded_ecc_32.sv`, `scripts/ecc_ref.py` | 8-bit 데이터로 Hamming 코드를 손으로 만들어 1-bit 에러를 고쳐 본다. `ecc_ref.py`에 3-bit 에러 실험을 몇 줄 추가해 오정정 비율을 세어 본다 | syndrome과 overall parity 조합 표를 안 보고 쓴다. 지운 페이지 문제와 0x67 마스크를 설명한다 |
| 5 | SoC + 펌웨어. `rtl/soc/aio_soc.sv`, `apb_dpram.sv`, `sw/main.c` | `main.c`에 단계를 하나 추가한다(예: 다른 페이지에 다른 패턴을 쓰고 읽기). `sw`에서 `make` → `--only soc_fw` | 펌웨어가 레지스터 네 개를 쓰는 순간부터 NAND 핀이 움직일 때까지를 신호 이름으로 따라간다 |
| 6 | UVM 환경. `testbench/uvm/` (pkg의 include 순서대로) | 시퀀스를 하나 추가한다(예: `PAGE_WORDS`를 1부터 최대까지 하나씩 올리며 PROGRAM/READ). 테스트로 등록하고 `regress.py`의 `UVM_TESTS`에 넣는다 | 스코어보드가 START와 DONE에서 각각 무엇을 하는지 설명한다. 에이전트가 active / reactive / passive인 이유를 말한다 |
| 7 | 합성·타이밍. `syn/aio_fpga_top.xdc`, `build/impl/*.rpt` | **구조 개선 과제**: page buffer를 레지스터 배열에서 동기 읽기 RAM으로 바꾼다(아래 안내) | critical path의 시작·끝·로직 단수를 말한다. XDC의 제약 네 묶음이 각각 왜 있는지 설명한다 |
| 8 | 개선 과제 마무리 | 회귀 전부 PASS를 다시 확인하고, 합성을 다시 돌려 전후 표를 만든다 | `docs/results.md`에 "전: FF n개 / BRAM 0 → 후: FF m개 / BRAM 1, WNS 변화"가 들어간다 |
| 9 | 발표 연습. `docs/interview_qna.md` | 5분 발표를 녹화한다. Q&A를 가리고 답해 본다 | 막힌 질문을 표시하고 그 부분 코드를 다시 읽는다 |
| 10 | 처음부터 재현 | 저장소를 다른 폴더에 복사해 `regress.py`, `mutation.py`, `run_impl.ps1`을 순서대로 돌린다 | 세 개 다 통과. 이력서·자기소개서 문구를 실제 숫자로 채운다 |

## Day 7 개선 과제 안내 (코드는 직접 짠다)

지금의 `page_data[]` / `page_ecc[]`는 플롭 배열이고 `page_data[word_index]`를 조합으로 읽는다. 합성 보고서에서 FF 수천 개와 F7/F8 MUX 수백 개로 나온다. 이것을 Block RAM으로 추론되게 바꾼다.

생각할 순서:

1. **무엇이 막고 있나.** BRAM은 읽기가 한 클럭 늦게 나온다(동기 읽기). 지금 FSM은 주소를 준 그 클럭에 데이터를 쓴다(`nand_w_data = page_data[word_index]`, `mem_req_wdata = page_data[word_index]`).
2. **어디를 바꿔야 하나.** 버퍼를 읽는 상태는 둘뿐이다: `ST_NAND_PROGRAM`과 `ST_DMA_WRITE`. 두 곳 모두 "handshake가 성립하면 다음 워드"인 구조다.
3. **선택지.** (a) 워드마다 "주소 주기 → 데이터 받기" 두 상태로 나눈다. 단순하지만 워드당 한 클럭 느려진다. (b) 다음 주소를 미리 준다(prefetch): handshake가 성립하는 클럭에 `word_index + 1`을 RAM에 넣어 둔다. 빠르지만 첫 워드와 stall 처리를 조심해야 한다. `apb_dpram`이 APB의 SETUP 사이클을 이용하는 방식, PHY가 `sh` 레지스터에 워드를 받아 두는 방식을 참고한다.
4. **리셋.** RAM에는 리셋이 없다. 지금 코드가 리셋에서 버퍼를 지우는지, 안 지워도 되는지 확인한다.
5. **추론 확인.** 합성 보고서의 `Block RAM Tile`이 0에서 1로 바뀌었는지 본다. 안 바뀌면 읽기가 아직 조합이거나 쓰기 포트가 둘 이상인 것이다.
6. **검증.** 인터페이스가 그대로라면 테스트벤치를 하나도 고치지 않고 회귀가 전부 통과해야 한다. 통과하지 않으면 그것이 곧 디버깅 연습이다.

면접에서는 이렇게 말할 수 있게 된다: "합성 보고서에서 page buffer가 플롭으로 풀린 것을 보고 동기 읽기 RAM으로 바꿨습니다. 읽기 지연 한 클럭을 FSM에서 이렇게 흡수했고, FF가 n개에서 m개로 줄고 BRAM 하나가 생겼습니다. 테스트벤치는 고치지 않았고 회귀가 그대로 통과했습니다."

## 5분 발표 흐름

1. **문제** (30초): NAND는 덮어쓸 수 없고 비트가 틀린다. CPU가 페이지를 안전하게 옮기려면 컨트롤러가 필요하다
2. **구조** (1분): CPU → APB → 코어(레지스터·DMA·버퍼·ECC) → PHY → 핀. 층을 나눈 이유
3. **한 번의 PROGRAM** (1분): 펌웨어가 레지스터 네 개를 쓴다 → DMA가 RAM에서 가져온다 → ECC를 붙인다 → 80h-주소-데이터-10h → R/B# → status
4. **검증** (1분 30초): 네 단계. 예측 스코어보드. 커버리지 100%. mutation으로 검사기를 검사. 통합하면서 찾은 문제(지운 페이지 ECC, READ 중 실패 경로)
5. **합성·타이밍** (30초): 자원, WNS, critical path, I/O 제약을 잡은 방식
6. **한계와 다음 단계** (30초): SEC-DED → BCH/LDPC, 레지스터 버퍼 → SRAM, 단순 DMA → AXI, async → NV-DDR/Toggle, FTL

## 자주 나올 질문 다섯 개

전체 목록과 답은 [interview_qna.md](interview_qna.md)에 있다. 아래 다섯은 거의 확실히 나온다고 보고 준비한다.

**왜 LDPC가 아닌 SEC-DED인가?**
10일 프로젝트에서 알고리즘 이름만 넣기보다 encoder/decoder와 fault injection을 끝에서 끝까지 검증하려고 작고 완결된 SEC-DED를 골랐다. 실제 NAND에는 BCH/LDPC가 필요하고, 코어와 ECC의 경계가 `(data, ecc)` 쌍이라 엔진을 바꿀 수 있다. 다만 BCH는 디코딩이 여러 클럭이라 FSM에 대기 상태가 하나 더 필요하다.

**왜 DMA가 AXI4가 아닌가?**
데이터 이동 FSM과 backpressure·에러 경로를 먼저 검증하려고 한 번에 하나만 요청하는 단순 포트를 썼다. 다음 단계는 burst를 지원하는 AXI4 master 어댑터다. 그때 watchdog이 대기 중인 요청을 철회하는 지금 동작은 고쳐야 한다(AXI에서는 valid를 내릴 수 없다).

**2-bit 에러 데이터도 host memory에 쓰는 이유는?**
지금 정책은 에러 개수를 소프트웨어에 보고하면서 원본 데이터를 그대로 넘기는 디버그 친화적 방식이다. 제품이라면 read-retry(읽기 전압을 바꿔 다시 읽기)를 먼저 시도하고, 그래도 안 되면 상위(FTL)에 알린다.

**가장 위험한 timing path는?**
`docs/results.md`의 post-route 보고서에 있는 경로를 직접 읽고 답한다. 시작 플롭, 끝 플롭, 로직 단수, 왜 긴지, 어떻게 줄일지.

**전원이 나가면?**
코어 범위 밖이다. 다만 PROGRAM은 10h가 나가기 전에 끊기면 셀이 하나도 안 바뀐다는 것을 검증했다(watchdog 중단 테스트). 10h 이후에 끊기면 페이지가 반쯤 쓰인 상태가 될 수 있고, 그것을 복구하는 것은 FTL의 일이다(메타데이터 저널, 전원 인가 시 스캔).
