/* ============================================================================
 * aio_soc 링커 스크립트   (cpu/sw/link.ld 에서 ROM 크기만 키웠다)
 *
 *   ROM : 0x0000_0000 ~  명령어 전용. instruction_rom 이 CPU 에 직결이라
 *                        데이터 버스(APB)로는 읽을 수 없다.
 *                        -> .rodata 나 .data 가 생기면 프로그램이 조용히 틀린다.
 *                           아래 ASSERT 두 개가 링크 단계에서 잡아 준다.
 *   RAM : 0x1000_0000 ~  4KB. APB 슬레이브 0 번이자 DMA 의 목적지.
 *                        스택은 이 영역의 맨 위(0x1000_1000)에서 아래로 자란다.
 * ========================================================================= */

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K    /* instruction_rom 1024 word */
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K    /* apb_dpram 1024 word       */
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);             /* 0x1000_1000 */

SECTIONS
{
    .text :
    {
        KEEP(*(.text.init))     /* crt0 의 _start 가 반드시 주소 0 이어야 한다 */
        *(.text*)
        . = ALIGN(4);
    } > ROM

    .rodata :
    {
        *(.rodata*)
        *(.srodata*)
        . = ALIGN(4);
    } > ROM

    .data :
    {
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
    } > RAM

    .bss :
    {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) *(.riscv.attributes) }
}

ASSERT(SIZEOF(.rodata) == 0, "link.ld: .rodata 가 비어 있지 않다. ROM 은 데이터 버스로 못 읽는다 (문자열 리터럴 / const 배열 / 점프 테이블 금지).")
ASSERT(SIZEOF(.data) == 0, "link.ld: .data 가 비어 있지 않다. ROM->RAM 복사 루틴이 없으므로 초기값 있는 전역변수는 못 쓴다.")
