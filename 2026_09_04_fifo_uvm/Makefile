# ============================================================
# VCS + UVM + Verdi Makefile   (fifo UVM)
#   make            : compile + run
#   make cov        : coverage report (urg) 생성
#   make verdi_cov  : Verdi 로 coverage 보기
#   make wave       : wave.fsdb 보기
#   make TB=tb_fifo : 예전 직접 구동 testbench 로 전환
# ============================================================

SHELL := /bin/bash

VCS   ?= vcs
VERDI ?= verdi
URG   ?= urg

TB        ?= tb_fifo_uvm
TOP       := $(TB)
SIMV      := simv
WAVE      := wave.fsdb
COV_DIR   := simv.vdb
COV_RPT   := urgReport
DEBUG_DIR := .verdi_debug

TEST ?= fifo_test
VERB ?= UVM_MEDIUM
SEED ?= 1

# line+cond+fsm+tgl+branch : code coverage
# covergroup(기능 커버리지)은 별도 옵션 없이 simv.vdb 에 같이 쌓인다
CM_OPTS := -cm line+cond+fsm+tgl+branch -cm_dir ./$(COV_DIR)

VCS_OPTS := \
	-full64 \
	-sverilog \
	-debug_access+all \
	-kdb \
	-ntb_opts uvm-1.2 \
	-timescale=1ns/1ps \
	$(CM_OPTS) \
	+incdir+./testbench

SRCS := \
	./rtl/fifo.sv \
	./testbench/$(TB).sv

SIM_OPTS := \
	+UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=$(VERB) \
	+ntb_random_seed=$(SEED) \
	$(CM_OPTS)

.PHONY: all comp run cov verdi_cov wave debug clean

all: run

# VCS compile
comp:
	$(VCS) $(VCS_OPTS) $(SRCS) \
		-top $(TOP) \
		-o $(SIMV) \
		-l comp.log

# batch simulation (wave.fsdb 생성)
run: comp
	./$(SIMV) $(SIM_OPTS) -l sim.log

# coverage report : urgReport/dashboard.html 확인
cov:
	@test -d "$(COV_DIR)" || { \
		echo "[ERROR] $(COV_DIR) 가 없습니다. 먼저 make run 을 실행하세요."; \
		exit 1; \
	}
	$(URG) -dir $(COV_DIR) -report $(COV_RPT)
	@echo "[INFO] $(COV_RPT)/dashboard.html 를 열어보세요."

# Verdi 로 coverage 보기
verdi_cov:
	$(VERDI) -cov -covdir $(COV_DIR) &

# wave.fsdb 확인
wave:
	@test -f "$(CURDIR)/$(WAVE)" || { \
		echo "[ERROR] $(WAVE) 가 없습니다. 먼저 make run 을 실행하세요."; \
		exit 1; \
	}
	$(VERDI) -ssf "$(CURDIR)/$(WAVE)" &

# interactive simulation (breakpoint + live waveform)
debug: comp
	mkdir -p $(DEBUG_DIR)
	./$(SIMV) \
		-gui=verdi \
		$(SIM_OPTS) \
		+fsdbfile+$(CURDIR)/$(DEBUG_DIR)/inter.fsdb \
		-l debug.log

clean:
	rm -rf \
		$(SIMV) \
		$(SIMV).daidir \
		$(SIMV).vdb \
		$(SIMV).cst \
		$(COV_RPT) \
		csrc \
		DVEfiles \
		ucli.key \
		AN.DB \
		verdiLog \
		vc_hdrs.h \
		.verdi_debug \
		comp.log \
		sim.log \
		debug.log \
		*.vpd \
		*.vdb \
		*.fsdb \
		novas.*
