# ============================================================================
# aio_soc 펌웨어 빌드
#
#   make            : fw.hex 생성 ($readmemh 용, 32bit 워드 하나당 한 줄)
#   make INJECT=0   : 에러 주입 단계를 뺀 보드용
#   make dump       : 디스어셈블 확인
#   make clean
#
#   이 PC 에서는 (Git Bash 기준)
#       PATH=/c/msys64/ucrt64/bin:/c/msys64/usr/bin:$PATH make
# ============================================================================

CROSS   ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size

INJECT  ?= 1

ARCH    := -march=rv32i -mabi=ilp32 -mno-relax

# -fno-jump-tables : switch 가 .rodata 에 점프 테이블을 만들지 못하게 한다
#                    (ROM 은 데이터 버스로 못 읽는다)
CFLAGS  := $(ARCH) -Os -ffreestanding -nostdlib -nostartfiles -fno-builtin \
           -fno-common -fno-jump-tables -Wall -Wextra -DINJECT=$(INJECT)
LDFLAGS := -T link.ld -Wl,--no-relax -Wl,-Map,fw.map

# Windows/MSYS 에서 TMP 가 C:\WINDOWS 로 잡혀 gcc 가 임시파일을 못 만드는 일이 있다.
export TMPDIR := .
export TMP    := .
export TEMP   := .

SRCS    := crt0.S main.c
HDRS    := aio_nand_regs.h
TARGET  := fw

.PHONY: all dump clean

all: $(TARGET).hex

$(TARGET).elf: $(SRCS) $(HDRS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@
	@$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin
	@od -An -tx4 -v $< | tr -s ' ' '\n' | grep -v '^$$' > $@
	@echo "[INFO] $@ : $$(wc -l < $@) word"

dump: $(TARGET).elf
	$(OBJDUMP) -d -M no-aliases $<

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).map
