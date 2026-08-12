# new

26ai_camp 저장소와 병합/정리한 Verilog 학습 프로젝트 모음입니다.

## 폴더 안내

아래 목록은 날짜순으로 정리되어 있으며, 각 폴더에는 해당 프로젝트의 **Verilog 소스/테스트벤치 파일만** 모아두었습니다 (Vivado 프로젝트 부속 파일 제외).

| 폴더 | 파일 | 비고 |
|---|---|---|
| [01_project_1](./01_project_1) | [202.v](./01_project_1/202.v) | 초기 연습 |
| [02_project_2](./02_project_2) | [counter_10000.v](./02_project_2/counter_10000.v), [fnd_controller.v](./02_project_2/fnd_controller.v) | 초기 연습 |
| [03_project_3](./03_project_3) | [fnd_conroller.v](./03_project_3/fnd_conroller.v) | 초기 연습 |
| [04_practice_2](./04_practice_2) | [1.v](./04_practice_2/1.v), [a.v](./04_practice_2/a.v), [fnd_controller.v](./04_practice_2/fnd_controller.v) | 초기 연습 |
| [05_2026-07-15_practice](./05_2026-07-15_practice) | [practice1.v](./05_2026-07-15_practice/practice1.v), [sim_practice1.v](./05_2026-07-15_practice/sim_practice1.v) | 7/15 practice |
| [06_2026-07-15_gates](./06_2026-07-15_gates) | [gates.v](./06_2026-07-15_gates/gates.v), [tb_gates.v](./06_2026-07-15_gates/tb_gates.v) | 7/15 논리게이트 |
| [07_2026-07-16_practice](./07_2026-07-16_practice) | [adder_practice.v](./07_2026-07-16_practice/adder_practice.v), [tb_adder_practice.v](./07_2026-07-16_practice/tb_adder_practice.v), [tb_full_adder.v](./07_2026-07-16_practice/tb_full_adder.v) | 7/16 practice |
| [08_2026-07-16_adder](./08_2026-07-16_adder) | [adder.v](./08_2026-07-16_adder/adder.v), [tb_adder.v](./08_2026-07-16_adder/tb_adder.v) | 7/16 adder |
| [09_2026-07-17_multiply](./09_2026-07-17_multiply) | [multiply.v](./09_2026-07-17_multiply/multiply.v), [tb_multiply.v](./09_2026-07-17_multiply/tb_multiply.v) | 7/17 multiply |
| [10_2026-07-20_practice](./10_2026-07-20_practice) | [fnd_adder.v](./10_2026-07-20_practice/fnd_adder.v) | 7/20 practice |
| [11_2026-07-20_adder_fnd](./11_2026-07-20_adder_fnd) | [adder_practice.v](./11_2026-07-20_adder_fnd/adder_practice.v), [fnd_controller.v](./11_2026-07-20_adder_fnd/fnd_controller.v) | 7/20 adder+fnd |
| [12_2026-07-21_adder_fnd](./12_2026-07-21_adder_fnd) | [tb_clkdiv.v](./12_2026-07-21_adder_fnd/tb_clkdiv.v) | 7/21 clkdiv |
| [13_2026-07-21_new](./13_2026-07-21_new) | [fnd_adder.v](./13_2026-07-21_new/fnd_adder.v), [fnd_controller.v](./13_2026-07-21_new/fnd_controller.v), [tb_fnd_adder.v](./13_2026-07-21_new/tb_fnd_adder.v) | 7/21 fnd_adder |
| [14_2026-07-22](./14_2026-07-22) | [control_unit.v](./14_2026-07-22/control_unit.v), [counter_10000.v](./14_2026-07-22/counter_10000.v), [fnd_controller.v](./14_2026-07-22/fnd_controller.v), [tb_10000_counter.v](./14_2026-07-22/tb_10000_counter.v) | 7/22 10000 counter |
| [15_2026-07-22_nonblocking](./15_2026-07-22_nonblocking) | [mux.v](./15_2026-07-22_nonblocking/mux.v), [nonblocking.v](./15_2026-07-22_nonblocking/nonblocking.v) | 7/22 nonblocking |
| [16_2026-07-23_moore_fsm](./16_2026-07-23_moore_fsm) | [fsm_moore_led01.v](./16_2026-07-23_moore_fsm/fsm_moore_led01.v), [tb_fsm_moore_led01.v](./16_2026-07-23_moore_fsm/tb_fsm_moore_led01.v) | 7/23 moore FSM |
| [17_2026-07-24](./17_2026-07-24) | [dd.v](./17_2026-07-24/dd.v) | 7/24 |
| [18_drafts](./18_drafts) | [top_counter_10000_draft.v](./18_drafts/top_counter_10000_draft.v), [tb_10000_counter_draft.v](./18_drafts/tb_10000_counter_draft.v), [내가_혼자해본거_망함_ㅜㅜ.v](./18_drafts/%EB%82%B4%EA%B0%80_%ED%98%BC%EC%9E%90%ED%95%B4%EB%B3%B8%EA%B1%B0_%EB%A7%9D%ED%95%A8_%E3%85%9C%E3%85%9C.v), [하다만거.v](./18_drafts/%ED%95%98%EB%8B%A4%EB%A7%8C%EA%B1%B0.v) | 미완성 draft 코드 모음 |
| [19_2026-08-13_sr04](./19_2026-08-13_sr04) | [sr04_controller.v](./19_2026-08-13_sr04/sr04_controller.v), [fnd_controller.v](./19_2026-08-13_sr04/fnd_controller.v), [btn_debounce.v](./19_2026-08-13_sr04/btn_debounce.v), [top_sr04.v](./19_2026-08-13_sr04/top_sr04.v), [tb_sr04.v](./19_2026-08-13_sr04/tb_sr04.v) | 8/13 HC-SR04 초음파거리센서 + FND 출력 |

## 원본 Vivado 프로젝트

위 정리된 폴더들의 원본 Vivado 프로젝트 폴더(빌드 산출물 포함)는 저장소 하단에 원래 이름 그대로 보존되어 있습니다 (예: `2026_07_22`, `2026_7_15_gates`, `practice_2` 등). 코드 내용은 위 정리 폴더와 동일하며, 삭제하지 않고 그대로 남겨두었습니다.
