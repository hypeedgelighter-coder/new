# Verilog 실습 코드 모음

이 저장소는 26ai_camp에서 진행한 Verilog 실습 코드를 날짜/주제별 폴더로 정리한 것입니다. 각 폴더는 Vivado 프로젝트 전체 또는 핵심 소스 파일만 포함하고 있으며, 아래 표에서 각 폴더의 설계 파일과 테스트벤치를 바로 확인할 수 있습니다.

| 폴더 | 설계 파일 | 테스트벤치 | 비고 |
|---|---|---|---|
| [2026_07_15_practice](2026_07_15_practice) | practice1.v | sim_practice1.v | 논리 게이트 실습 |
| [2026_07_16_adder](2026_07_16_adder) | adder.v | tb_adder.v | 4비트 가산기 |
| [2026_07_16_practice](2026_07_16_practice) | adder_practice.v | tb_adder_practice.v, tb_full_adder.v | 반가산기/전가산기 연습 |
| [2026_07_20_adder_fnd](2026_07_20_adder_fnd) | fnd_controller.v, adder_practice.v | - | FND 컨트롤러 + 가산기 |
| [2026_07_20_practice](2026_07_20_practice) | fnd_adder.v | - | FND 가산기 연습 |
| [2026_07_21_adder_fnd](2026_07_21_adder_fnd) | (Vivado 프로젝트 소스) | tb_clkdiv.v, tb_clkdiv_func_synth.v | 클럭 분주기 |
| [2026_07_21_new](2026_07_21_new) | fnd_adder.v, fnd_controller.v | tb_fnd_adder.v | FND 가산기 (Vivado 프로젝트) |
| [2026_07_22](2026_07_22) | control_unit.v, counter_10000.v, fnd_controller.v | tb_10000_counter.v | 10000진 카운터 (Vivado 프로젝트, 최종본) |
| [2026_07_22_nonblocking](2026_07_22_nonblocking) | nonblocking.v, mux.v | - | Nonblocking 할당 실습 |
| [2026_07_23_moore_fsm](2026_07_23_moore_fsm) | fsm_moore_led01.v | tb_fsm_moore_led01.v | Moore FSM (LED) |
| [2026_07_24](2026_07_24) | dd.v | - | 실습 |
| [2026_7_15_gates](2026_7_15_gates) | gates.v | tb_gates.v | 논리 게이트 (26ai_camp 버전으로 교체됨) |
| [practice_2](practice_2) | 1.v, a.v, fnd_controller.v | - | 연습 |
| [project_1](project_1) | 202.v | - | 연습 |
| [project_2](project_2) | counter_10000.v, fnd_controller.v | - | 10000진 카운터 (Vivado 프로젝트) |
| [project_3](project_3) | fnd_conroller.v | - | FND 컨트롤러 연습 |
| [project_7_17_multiply](project_7_17_multiply) | multiply.v | tb_multiply.v | 곱셈기 |
| [drafts](drafts) | top_counter_10000_draft.v, 내가_혼자해본거_망함_ㅜㅜ.v, 하다만거.v | tb_10000_counter_draft.v | 26ai_camp에 있던 초안/미완성 코드 (2026_07_22 최종본 이전 버전) |

> drafts 폴더는 26ai_camp 저장소 루트에 있던 확장자 없는 초안 파일들에 `.v` 확장자를 붙여 옮긴 것으로, 코드 내용은 원본 그대로입니다.
