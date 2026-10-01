# =============================================================================
# crt0.S : 리셋 직후 C 로 넘어가기 전까지   (cpu/sw/crt0.S 그대로)
#
#   1) sp 를 RAM 꼭대기로.
#   2) .bss 를 0 으로 민다.
#   3) main 호출. 돌아오면 제자리 무한 루프 (halt).
#
#   RV32I 만 쓴다 (M/A/C 확장 없음).
# =============================================================================
    .section .text.init, "ax"
    .global _start

_start:
    # ---- 스택 ----
    lui  sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)

    # ---- .bss = 0 ----
    la   t0, _bss_start
    la   t1, _bss_end
bss_loop:
    bgeu t0, t1, bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    bss_loop
bss_done:

    # ---- C ----
    call main

halt:
    j    halt
