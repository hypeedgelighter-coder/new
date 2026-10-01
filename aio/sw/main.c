/* ============================================================================
 * main.c : aio_soc 에서 도는 NAND 컨트롤러 셀프 테스트 펌웨어
 *
 *   CPU(RV32I) 가 APB 로 NAND 컨트롤러 레지스터를 두드려서
 *   ERASE -> 빈 페이지 확인 -> PROGRAM -> READ -> 에러 정정 확인 까지 돈다.
 *   데이터는 컨트롤러가 DMA 로 RAM 에서 직접 가져가고 가져온다.
 *   이 코드는 "어디서 / 얼마나 / 무엇을" 만 시킨다.
 *
 *   [결과 보는 법]
 *     UART : "AIO" 로 시작해서 단계가 통과할 때마다 한 글자씩, 끝에 "PASS"
 *            실패하면 "F" + 실패한 단계 번호(16진 두 자리)
 *     GPO  : 0x11 / 0x12 = 테스트벤치에게 "지금 비트를 깨 달라" 고 알리는 신호
 *            0xA5 = 전부 통과,  0xE0 | 단계 = 실패
 *
 *   [에러는 누가 넣나]
 *     이 컨트롤러는 ECC 를 끌 수 없어서 펌웨어가 스스로 비트를 깰 수 없다.
 *     그래서 GPO 에 단계 번호를 쓰면 테스트벤치가 NAND 모델의 셀을 뒤집는다.
 *     (실제 보드에서는 그 단계가 "에러 없음" 으로 나오므로 CORR 검사에서 멈춘다.
 *      보드용으로는 INJECT 를 0 으로 빌드한다 : make INJECT=0)
 *
 *   [제약]
 *     - 명령어 ROM 은 데이터 버스로 못 읽는다.
 *       -> 문자열 리터럴 / 초기값 있는 전역변수 / switch 점프 테이블 금지
 *          (link.ld 의 ASSERT 가 잡는다)
 *     - RV32I 뿐이다. 곱셈 / 나눗셈 명령이 없다.
 * ========================================================================= */

#include <stdint.h>
#include "aio_nand_regs.h"

#ifndef INJECT
#define INJECT 1
#endif

#define REG(a)          (*(volatile uint32_t *)(a))

#define GPO_ODR         REG(0x20000100u)
#define UART_SR         REG(0x20000300u)
#define UART_TXD        REG(0x20000304u)
#define UART_TX_BUSY    (1u << 2)

#define NAND_BASE       0x30000000u
#define AIO_NAND_ID_VALUE   0x41494F31u     /* "AIO1" */
#define AIO_CTRL_OP_RESET   (3u << 1)       /* PHY 확장 : NAND 에 FFh */

#define PAGE_WORDS      64u                 /* 256 byte. RTL 의 MAX_PAGE_WORDS 와 같다 */
#define PAGES_PER_BLOCK 64u
#define TEST_ROW        (1u * PAGES_PER_BLOCK + 3u)     /* block 1, page 3 */

/* 테스트벤치와 약속한 단계 번호 */
#define STAGE_INJECT_1BIT   0x11u
#define STAGE_INJECT_2BIT   0x12u
#define STAGE_PASS          0xA5u
#define STAGE_FAIL          0xE0u

/* .bss 에 잡힌다 = RAM. 컨트롤러가 DMA 로 직접 읽고 쓰는 곳이다. */
static uint32_t src_buf[PAGE_WORDS];
static uint32_t dst_buf[PAGE_WORDS];

/* ---------------------------------------------------------------------------
 * UART
 * ------------------------------------------------------------------------- */
static void uart_putc(char c)
{
    while (UART_SR & UART_TX_BUSY)
        ;
    UART_TXD = (uint32_t)(unsigned char)c;
}

static void uart_hex8(uint32_t v)
{
    for (int shift = 4; shift >= 0; shift -= 4) {
        uint32_t nib = (v >> shift) & 0xFu;
        uart_putc((char)(nib < 10u ? '0' + nib : 'A' + nib - 10u));
    }
}

static void fail(uint32_t step)
{
    uart_putc('F');
    uart_hex8(step);
    uart_putc('\n');
    GPO_ODR = STAGE_FAIL | (step & 0x0Fu);
    for (;;)
        ;
}

/* ---------------------------------------------------------------------------
 * NAND 드라이버 : 레지스터 네 개 쓰고 DONE 을 기다리는 것이 전부다
 * ------------------------------------------------------------------------- */
static uint32_t nand_op(uint32_t op, uint32_t row, uint32_t *buf, uint32_t words)
{
    uint32_t status;

    aio_nand_write(NAND_BASE, AIO_NAND_ROW, row);
    aio_nand_write(NAND_BASE, AIO_NAND_HOST_ADDR, (uint32_t)(uintptr_t)buf);
    aio_nand_write(NAND_BASE, AIO_NAND_PAGE_WORDS, words);
    aio_nand_write(NAND_BASE, AIO_NAND_CONTROL,
                   AIO_CTRL_CLEAR_STATUS | op | AIO_CTRL_START);

    do {
        status = aio_nand_read(NAND_BASE, AIO_NAND_STATUS);
    } while (!(status & AIO_STATUS_DONE));

    return status;
}

static uint32_t nand_erase(uint32_t row)
{
    return nand_op(AIO_CTRL_OP_ERASE, row, src_buf, PAGE_WORDS);   /* ERASE 는 블록 단위다 */
}

static uint32_t nand_program(uint32_t row, uint32_t *buf)
{
    return nand_op(AIO_CTRL_OP_PROGRAM, row, buf, PAGE_WORDS);
}

static uint32_t nand_read(uint32_t row, uint32_t *buf)
{
    return nand_op(AIO_CTRL_OP_READ, row, buf, PAGE_WORDS);
}

/* ---------------------------------------------------------------------------
 * 테스트 패턴 : xorshift32. 곱셈이 없어도 되고, 워드마다 값이 다 다르다.
 * ------------------------------------------------------------------------- */
static uint32_t xorshift32(uint32_t x)
{
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
}

static void fill_pattern(uint32_t *buf, uint32_t seed)
{
    uint32_t x = seed;
    for (uint32_t i = 0; i < PAGE_WORDS; i++) {
        x = xorshift32(x);
        buf[i] = x;
    }
}

static void fill_const(uint32_t *buf, uint32_t value)
{
    for (uint32_t i = 0; i < PAGE_WORDS; i++)
        buf[i] = value;
}

static int same(const uint32_t *a, const uint32_t *b)
{
    for (uint32_t i = 0; i < PAGE_WORDS; i++)
        if (a[i] != b[i])
            return 0;
    return 1;
}

static int all_ones(const uint32_t *a)
{
    for (uint32_t i = 0; i < PAGE_WORDS; i++)
        if (a[i] != 0xFFFFFFFFu)
            return 0;
    return 1;
}

int main(void)
{
    uint32_t st;

    uart_putc('A');
    uart_putc('I');
    uart_putc('O');
    uart_putc(' ');

    /* ---- 0. 컨트롤러가 거기 있는가 ---- */
    if (aio_nand_read(NAND_BASE, AIO_NAND_ID) != AIO_NAND_ID_VALUE)
        fail(0);
    aio_nand_write(NAND_BASE, AIO_NAND_TIMEOUT, 2000000u);  /* watchdog : 넉넉히 */
    aio_nand_write(NAND_BASE, AIO_NAND_IRQ_ENABLE, 1u);

    /* ---- 1. ERASE ---- */
    st = nand_erase(TEST_ROW);
    if (st & AIO_STATUS_ERROR)
        fail(1);
    uart_putc('E');

    /* ---- 2. 지운 페이지는 0xFFFFFFFF 이고 ECC 에러가 없어야 한다 ---- */
    fill_const(dst_buf, 0u);
    st = nand_read(TEST_ROW, dst_buf);
    if ((st & AIO_STATUS_ERROR) || !all_ones(dst_buf))
        fail(2);
    if (aio_nand_read(NAND_BASE, AIO_NAND_CORR_COUNT) != 0u)
        fail(2);
    uart_putc('B');

    /* ---- 3. PROGRAM ---- */
    fill_pattern(src_buf, 0x2026A100u);
    st = nand_program(TEST_ROW, src_buf);
    if (st & AIO_STATUS_ERROR)
        fail(3);
    uart_putc('P');

    /* ---- 4. READ : 쓴 그대로 돌아오는가 ---- */
    fill_const(dst_buf, 0u);
    st = nand_read(TEST_ROW, dst_buf);
    if ((st & AIO_STATUS_ERROR) || !same(src_buf, dst_buf))
        fail(4);
    if (aio_nand_read(NAND_BASE, AIO_NAND_CORR_COUNT) != 0u)
        fail(4);
    uart_putc('R');

#if INJECT
    /* ---- 5. 1 bit 에러 : 고쳐서 돌아오고, 고쳤다고 세어야 한다 ---- */
    GPO_ODR = STAGE_INJECT_1BIT;        /* 테스트벤치가 셀 하나를 뒤집는다 */
    fill_const(dst_buf, 0u);
    st = nand_read(TEST_ROW, dst_buf);
    if ((st & AIO_STATUS_ERROR) || !same(src_buf, dst_buf))
        fail(5);
    if (aio_nand_read(NAND_BASE, AIO_NAND_CORR_COUNT) != 1u)
        fail(5);
    uart_putc('1');

    /* ---- 6. 같은 워드에 2 bit 에러 : 고쳤다고 하면 안 되고 에러로 보고해야 한다 ---- */
    GPO_ODR = STAGE_INJECT_2BIT;
    st = nand_read(TEST_ROW, dst_buf);
    if (!(st & AIO_STATUS_UNCORR) || !(st & AIO_STATUS_ERROR))
        fail(6);
    if (aio_nand_read(NAND_BASE, AIO_NAND_UNCORR_COUNT) != 1u)
        fail(6);
    if (aio_nand_read(NAND_BASE, AIO_NAND_ERROR_CODE) != 4u)
        fail(6);
    if (aio_nand_read(NAND_BASE, AIO_NAND_CORR_COUNT) != 1u)   /* 5 번의 1 bit 은 그대로 있다 */
        fail(6);
    uart_putc('2');
#endif

    /* ---- 7. 다시 ERASE 하면 깨진 셀도 같이 사라진다 ---- */
    st = nand_erase(TEST_ROW);
    if (st & AIO_STATUS_ERROR)
        fail(7);
    st = nand_read(TEST_ROW, dst_buf);
    if ((st & AIO_STATUS_ERROR) || !all_ones(dst_buf))
        fail(7);

    uart_putc(' ');
    uart_putc('P');
    uart_putc('A');
    uart_putc('S');
    uart_putc('S');
    uart_putc('\n');
    GPO_ODR = STAGE_PASS;

    return 0;
}
