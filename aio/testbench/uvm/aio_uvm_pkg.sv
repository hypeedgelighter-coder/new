`timescale 1ns/1ps

// =============================================================================
// aio_uvm_pkg : UVM 검증 환경을 한 패키지로 묶는다
//
//   읽는 순서 (아래 include 순서와 같다)
//     aio_defs.svh        상수, 트랜잭션, 설정 객체
//     aio_agents.svh      APB 에이전트 / DMA 메모리 에이전트 / NAND 핀 모니터
//     aio_scoreboard.svh  기준 ECC 모델 + 예측 스코어보드
//     aio_env.svh         기능 커버리지 + 환경 조립
//     aio_seq_lib.svh     시퀀스 (자극)
//     aio_test_lib.svh    테스트
//
//   interface 는 패키지에 넣을 수 없어서 aio_uvm_if.sv 에 따로 있다.
//   (그 파일이 이 패키지보다 먼저 컴파일돼야 한다)
// =============================================================================
package aio_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 스코어보드가 analysis 입력을 셋 받는다. write() 가 하나뿐이면 구분이 안 되므로
    // 접미사를 붙여 write_apb / write_mem / write_nand 로 나눈다.
    `uvm_analysis_imp_decl(_apb)
    `uvm_analysis_imp_decl(_mem)
    `uvm_analysis_imp_decl(_nand)

    `include "aio_defs.svh"
    `include "aio_agents.svh"
    `include "aio_scoreboard.svh"
    `include "aio_env.svh"
    `include "aio_seq_lib.svh"
    `include "aio_test_lib.svh"
endpackage
