#!/usr/bin/env python3
"""Mutation check: 검증 환경이 정말로 버그를 잡는지 확인한다.

테스트가 전부 PASS 라는 사실만으로는 "설계가 맞다" 와 "검사가 빠져 있다" 를
구분할 수 없다. 그래서 RTL 에 일부러 버그를 하나씩 심고(mutant), 회귀가
그것을 FAIL 로 잡아내는지(killed) 본다. 하나라도 통과해 버리면(survived)
검증 환경에 구멍이 있다는 뜻이다.

    python scripts/mutation.py              전부
    python scripts/mutation.py --only M3    이름에 M3 이 든 것만
    python scripts/mutation.py --list

원본 소스는 건드리지 않는다. build/mutation/<id>/ 에 복사본을 만들어 거기서 고친다.
결과 : build/mutation/report.md
"""

from __future__ import annotations

import argparse
import shutil
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import regress

REAL_ROOT = Path(__file__).resolve().parent.parent
MUT_OUT = REAL_ROOT / "build" / "mutation"


@dataclass
class Mutant:
    mid: str
    what: str               # 심은 버그 (사람이 읽는 설명)
    file: str
    old: str
    new: str
    jobs: list[str]         # 이 버그를 잡아야 하는 테스트들 (regress 의 job 이름)


MUTANTS = [
    Mutant("M01", "PHY: WE#/RE# 펄스를 3 클럭 -> 1 클럭으로 (tWP/tRP/tREA 위반)",
           "rtl/aio_nand_top.sv",
           "parameter int T_PW             = 3,",
           "parameter int T_PW             = 1,",
           ["top_pin", "uvm_smoke"]),
    Mutant("M02", "PHY: 확정 커맨드 뒤 대기를 16 -> 4 클럭으로 (tWB 전에 R/B# 를 본다)",
           "rtl/aio_nand_top.sv",
           "parameter int T_WAIT           = 16,",
           "parameter int T_WAIT           = 4,",
           ["top_pin", "uvm_smoke"]),
    Mutant("M03", "PHY: 지운 페이지용 ECC 마스크 제거",
           "rtl/phy/nand_onfi_phy.sv",
           "ECC_ERASED_MASK = 7'h67;",
           "ECC_ERASED_MASK = 7'h00;",
           ["top_pin", "uvm_smoke"]),
    Mutant("M04", "PHY: row 주소 바이트 순서를 바꿈 (엉뚱한 페이지에 접근)",
           "rtl/phy/nand_onfi_phy.sv",
           "3'd2:    addr_byte = row_q[7:0];",
           "3'd2:    addr_byte = row_q[15:8];",
           ["top_pin", "uvm_smoke"]),
    Mutant("M05", "PHY: NAND status 의 FAIL / WP 비트를 무시",
           "rtl/phy/nand_onfi_phy.sv",
           "fail_q      <= cyc_rdata[0] || !cyc_rdata[7];",
           "fail_q      <= 1'b0;",
           ["top_pin", "uvm_err"]),
    Mutant("M06", "PHY: 읽기 스트림이 끊겨도 정리(FFh)하지 않음",
           "rtl/phy/nand_onfi_phy.sv",
           """                    end else if (&stall_cnt) begin
                        op_q    <= OP_RESET;
                        quiet_q <= 1'b1;
                        state   <= P_CMD1;
                    end else stall_cnt <= stall_cnt + 1'b1;
                end

                P_DONE: begin""",
           """                    end else stall_cnt <= stall_cnt + 1'b1;
                end

                P_DONE: begin""",
           ["top_pin", "uvm_err"]),
    Mutant("M07", "PHY: 데이터 바이트를 높은 쪽부터 내보냄 (엔디안 뒤집힘)",
           "rtl/phy/nand_onfi_phy.sv",
           "P_W_BYTE:   begin cyc_req = 1'b1; cyc_kind = KIND_WDATA; cyc_wdata = sh[7:0];   end",
           "P_W_BYTE:   begin cyc_req = 1'b1; cyc_kind = KIND_WDATA; cyc_wdata = sh[15:8];  end",
           ["top_pin", "uvm_smoke"]),
    Mutant("M08", "코어: ECC 자리 에러를 고친 횟수에 세지 않음",
           "rtl/aio_nand_dma_ctrl.sv",
           "if ((ecc_status == 2'd1) || (ecc_status == 2'd2))",
           "if (ecc_status == 2'd1)",
           ["top_pin", "uvm_ecc"]),
    Mutant("M09", "코어: DMA 주소를 워드당 2 씩 증가 (4 여야 한다)",
           "rtl/aio_nand_dma_ctrl.sv",
           "mem_req_addr = active_host_addr + (word_index << 2);",
           "mem_req_addr = active_host_addr + (word_index << 1);",
           ["core_txn", "uvm_smoke"]),
    Mutant("M10", "코어: READ 중 PHY 실패를 받는 경로 제거",
           "rtl/aio_nand_dma_ctrl.sv",
           "if (nand_done && nand_fail) begin\n                        error_code <= ERR_NAND_FAIL;\n                        error_sticky <= 1'b1;\n                        state <= ST_ERROR;\n                    end else if (nand_r_valid && nand_r_ready) begin",
           "if (nand_r_valid && nand_r_ready) begin",
           ["top_pin", "uvm_err"]),
    Mutant("M11", "코어: 정정 불가 워드가 있어도 에러 코드를 남기지 않음",
           "rtl/aio_nand_dma_ctrl.sv",
           "error_code <= ERR_ECC;",
           "error_code <= ERR_NONE;",
           ["core_txn", "uvm_ecc"]),
    Mutant("M12", "코어: 잘못된 길이 검사에서 상한을 빼먹음",
           "rtl/aio_nand_dma_ctrl.sv",
           "if ((page_words_reg == 0) || (page_words_reg > MAX_PAGE_WORDS)) begin",
           "if (page_words_reg == 0) begin",
           ["core_txn", "uvm_err"]),
    Mutant("M13", "ECC: 2 bit 에러를 '에러 없음' 으로 판정",
           "rtl/ecc/secded_ecc_32.sv",
           "        end else begin\n            status_o = ECC_UNCORRECTABLE;",
           "        end else begin\n            status_o = ECC_CLEAN;",
           ["ecc_unit", "ecc_vectors", "uvm_ecc"]),
    Mutant("M14", "ECC: encoder 의 overall parity 를 뒤집음 (encoder/decoder 가 같이 틀리지 않는 경우)",
           "rtl/ecc/secded_ecc_32.sv",
           "ecc_o[6] = ^enc_code;",
           "ecc_o[6] = ~^enc_code;",
           ["ecc_unit", "ecc_vectors"]),
    Mutant("M15", "SoC: RAM 의 DMA 포트가 주소 비트를 한 칸 밀려서 봄",
           "rtl/soc/periph/apb_dpram.sv",
           "assign b_idx         = mem_req_addr[AW+1:2];",
           "assign b_idx         = mem_req_addr[AW:1];",
           ["soc_fw"]),
    Mutant("M16", "SoC: 주소 디코더가 NAND 컨트롤러 영역을 잘못 잡음",
           "rtl/soc/periph/apb_master.sv",
           "if(paddr[27:12] == 16'h0000) psel[SLV_NAND] = 1'b1;",
           "if(paddr[27:12] == 16'h0001) psel[SLV_NAND] = 1'b1;",
           ["soc_fw"]),
]


def make_shadow(m: Mutant) -> Path:
    shadow = MUT_OUT / m.mid
    shutil.rmtree(shadow, ignore_errors=True)
    shadow.mkdir(parents=True)
    for d in ("rtl", "model", "testbench", "flist", "scripts"):
        shutil.copytree(REAL_ROOT / d, shadow / d,
                        ignore=shutil.ignore_patterns("__pycache__"))
    (shadow / "sw").mkdir()
    shutil.copyfile(REAL_ROOT / "sw" / "fw.hex", shadow / "sw" / "fw.hex")

    target = shadow / m.file
    text = target.read_text(encoding="utf-8")
    if text.count(m.old) != 1:
        sys.exit(f"{m.mid}: 바꿀 자리를 정확히 한 군데 찾지 못했다 ({text.count(m.old)} 군데) : {m.file}")
    target.write_text(text.replace(m.old, m.new), encoding="utf-8", newline="\n")
    return shadow


def run_mutant(m: Mutant, vbin: Path) -> dict:
    shadow = make_shadow(m)
    regress.ROOT = shadow
    regress.OUT = shadow / "out"
    regress.prepare_inputs(sys.executable)

    jobs = [j for j in regress.make_jobs(1) if j.name in m.jobs]
    broken = {}
    for name in dict.fromkeys(j.build for j in jobs):
        why = regress.do_build(regress.BUILDS[name], vbin)
        if why:
            broken[name] = why

    killers = []
    survived_in = []
    for job in jobs:
        if job.build in broken:
            killers.append((job.name, broken[job.build]))
            continue
        r = regress.run_job(job, vbin, cov=False)
        if r["status"] == "FAIL":
            killers.append((job.name, "; ".join(r["reasons"])))
        else:
            survived_in.append(job.name)
    return {"id": m.mid, "what": m.what, "file": m.file,
            "killed": bool(killers), "killers": killers, "survived_in": survived_in}


def write_report(results: list[dict], secs: float) -> None:
    n_killed = sum(r["killed"] for r in results)
    lines = ["# Mutation check", "",
             f"- killed : **{n_killed} / {len(results)}**",
             f"- wall time : {secs:.0f} s", "",
             "| id | 심은 버그 | 결과 | 잡아낸 테스트 (이유) | 못 잡은 테스트 |",
             "|---|---|:---:|---|---|"]
    for r in results:
        killers = "<br>".join(f"`{n}` : {why}" for n, why in r["killers"]) or "-"
        missed = ", ".join(f"`{n}`" for n in r["survived_in"]) or "-"
        lines.append(f"| {r['id']} | {r['what']} | {'killed' if r['killed'] else '**SURVIVED**'} "
                     f"| {killers} | {missed} |")
    MUT_OUT.mkdir(parents=True, exist_ok=True)
    (MUT_OUT / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    regress.utf8_when_redirected()
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--only", help="이름에 이 문자열이 든 mutant 만 (쉼표로 여러 개)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--vivado-bin")
    args = ap.parse_args()

    mutants = MUTANTS
    if args.only:
        keys = [k.strip() for k in args.only.split(",") if k.strip()]
        mutants = [m for m in MUTANTS if any(k in m.mid for k in keys)]
    if args.list:
        for m in mutants:
            print(f"{m.mid}  {m.what}  [{', '.join(m.jobs)}]")
        return 0

    vbin = regress.find_vivado_bin(args.vivado_bin)
    started = time.time()
    results = []
    for m in mutants:
        print(f"[{m.mid}] {m.what} ...", end=" ", flush=True)
        r = run_mutant(m, vbin)
        results.append(r)
        if r["killed"]:
            print("killed by " + ", ".join(n for n, _ in r["killers"])
                  + (f"  (missed by {', '.join(r['survived_in'])})" if r["survived_in"] else ""))
        else:
            print("SURVIVED")

    write_report(results, time.time() - started)
    n_killed = sum(r["killed"] for r in results)
    print("-" * 72)
    print(f"{n_killed} / {len(results)} killed   report : {MUT_OUT / 'report.md'}")
    return 0 if n_killed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
