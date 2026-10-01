#ifndef AIO_NAND_REGS_H
#define AIO_NAND_REGS_H

#include <stdint.h>

#define AIO_NAND_CONTROL       0x000u
#define AIO_NAND_STATUS        0x004u
#define AIO_NAND_ROW           0x008u
#define AIO_NAND_HOST_ADDR     0x00Cu
#define AIO_NAND_PAGE_WORDS    0x010u
#define AIO_NAND_TIMEOUT       0x014u
#define AIO_NAND_CORR_COUNT    0x018u
#define AIO_NAND_UNCORR_COUNT  0x01Cu
#define AIO_NAND_ERROR_CODE    0x020u
#define AIO_NAND_IRQ_ENABLE    0x024u
#define AIO_NAND_ID            0x0FCu

#define AIO_CTRL_START         (1u << 0)
#define AIO_CTRL_OP_PROGRAM    (0u << 1)
#define AIO_CTRL_OP_READ       (1u << 1)
#define AIO_CTRL_OP_ERASE      (2u << 1)
#define AIO_CTRL_CLEAR_STATUS  (1u << 8)

#define AIO_STATUS_BUSY        (1u << 0)
#define AIO_STATUS_DONE        (1u << 1)
#define AIO_STATUS_IRQ         (1u << 2)
#define AIO_STATUS_ERROR       (1u << 3)
#define AIO_STATUS_UNCORR      (1u << 4)

static inline void aio_nand_write(uintptr_t base, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(base + offset) = value;
}

static inline uint32_t aio_nand_read(uintptr_t base, uint32_t offset)
{
    return *(volatile uint32_t *)(base + offset);
}

#endif
