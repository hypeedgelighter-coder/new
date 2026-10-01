#!/usr/bin/env python3
"""AIO NAND controller regression runner (Vivado xsim).

한 번에 전부 돌리고, 로그를 읽어 PASS/FAIL 을 판정하고, 표로 요약한다.

    python scripts/regress.py                 전부
    python scripts/regress.py --list          무엇이 도는지만 본다
    python scripts/regress.py --only uvm      이름에 'uvm' 이 든 것만
    python scripts/regress.py --seeds 5       무작위 테스트를 seed 5 개로
    python scripts/regress.py --no-cov        커버리지 병합 생략

결과물 : build/regress/report.md, report.json, <build>/<job>.log, cov_report/

판정 규칙 (하나라도 어기면 FAIL)
  - 로그에 그 테스트의 PASS 문구가 있어야 한다
  - 로그에 금지 문구(Fatal / UVM_ERROR 1 건 이상 / NAND 타이밍 위반 ...)가 없어야 한다
  - 시뮬레이터가 정상 종료해야 한다
"PASS 문구가 있다" 만 보면 에러가 찍히고도 끝까지 간 경우를 놓친다. 둘 다 본다.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "regress"

# 어떤 테스트에서든 나오면 안 되는 것
FORBIDDEN = [
    (r"^Fatal:", "simulator $fatal"),
    (r"^Error:", "simulator $error / assertion"),
    # 메시지 줄은 "UVM_ERROR <파일>(줄) @ 시각: ..." 꼴이고, 맨 끝 요약 줄은
    # "UVM_ERROR :    0" 꼴이다. 요약의 0 은 걸리면 안 되므로 둘을 따로 본다.
    (r"^UVM_ERROR [^:]", "UVM_ERROR"),
    (r"^UVM_FATAL [^:]", "UVM_FATAL"),
    (r"UVM_ERROR :\s+[1-9]", "UVM_ERROR (summary)"),
    (r"UVM_FATAL :\s+[1-9]", "UVM_FATAL (summary)"),
    (r"NAND_MODEL VIOLATION", "NAND timing/protocol violation"),
    (r"FATAL_ERROR", "simulator crash"),
]


@dataclass
class Build:
    """xvlog + xelab 한 번. 같은 snapshot 을 여러 Job 이 돌려 쓴다."""
    name: str
    flists: list[str]
    tops: list[str]
    uvm: bool = False
    incdirs: list[str] = field(default_factory=list)


@dataclass
class Job:
    name: str
    build: str
    top: str
    expect: str                     # 로그에 있어야 하는 정규식
    uvm_test: str | None = None
    seed: int | None = None
    needs: list[str] = field(default_factory=list)      # 실행 디렉터리에 있어야 하는 파일
    group: str = ""


BUILDS = {
    "legacy": Build("legacy", ["sim.f"], ["tb_secded_ecc_32", "tb_aio_nand_dma_ctrl"]),
    "eccvec": Build("eccvec", ["ecc_vec.f"], ["tb_ecc_vectors"]),
    "pin": Build("pin", ["top_pin.f"], ["tb_aio_nand_top"]),
    "soc": Build("soc", ["soc.f", "tb_soc.f"], ["tb_aio_soc"]),
    "uvm": Build("uvm", ["uvm.f"], ["tb_aio_uvm"], uvm=True, incdirs=["testbench/uvm"]),
}

UVM_TESTS = ["aio_smoke_test", "aio_ecc_test", "aio_err_test", "aio_bp_test", "aio_reset_test"]


def make_jobs(seeds: int) -> list[Job]:
    jobs = [
        Job("ecc_unit", "legacy", "tb_secded_ecc_32",
            r"PASS: ECC RTL exhaustive single-bit regression", group="block"),
        Job("ecc_vectors", "eccvec", "tb_ecc_vectors",
            r"PASS: ECC RTL matches \d+ Python golden vectors",
            needs=["ecc_vectors.txt"], group="block"),
        Job("core_txn", "legacy", "tb_aio_nand_dma_ctrl",
            r"PASS: 8 end-to-end scenarios completed", group="core"),
        Job("top_pin", "pin", "tb_aio_nand_top",
            r"PASS: \d+ pin-level scenarios completed, 0 NAND timing violations", group="ip"),
    ]
    for test in UVM_TESTS:
        jobs.append(Job(f"uvm_{test[4:-5]}", "uvm", "tb_aio_uvm", r"UVM TEST PASSED",
                        uvm_test=test, seed=1, needs=["ecc_vectors.txt"], group="uvm"))
    for seed in range(1, seeds + 1):
        jobs.append(Job(f"uvm_rand_s{seed}", "uvm", "tb_aio_uvm", r"UVM TEST PASSED",
                        uvm_test="aio_rand_test", seed=seed, needs=["ecc_vectors.txt"],
                        group="uvm"))
    jobs.append(Job("soc_fw", "soc", "tb_aio_soc", r"PASS: firmware self-test on aio_soc",
                    needs=["fw.hex"], group="soc"))
    return jobs


# -----------------------------------------------------------------------------
# 도구 찾기 / 실행
# -----------------------------------------------------------------------------
def find_vivado_bin(arg: str | None) -> Path:
    candidates = []
    if arg:
        candidates.append(Path(arg))
    if os.environ.get("XILINX_VIVADO"):
        candidates.append(Path(os.environ["XILINX_VIVADO"]) / "bin")
    which = shutil.which("xvlog") or shutil.which("xvlog.bat")
    if which:
        candidates.append(Path(which).parent)
    candidates.append(Path("C:/Xilinx/Vivado/2020.2/bin"))
    for c in candidates:
        if (c / "xvlog.bat").exists() or (c / "xvlog").exists():
            return c
    sys.exit("xvlog 를 찾지 못했다. --vivado-bin 으로 Vivado 의 bin 디렉터리를 알려 달라.")


def tool(vbin: Path, name: str) -> str:
    bat = vbin / f"{name}.bat"
    return str(bat if bat.exists() else vbin / name)


def run(cmd: list[str], cwd: Path, log: Path) -> tuple[int, float]:
    start = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        proc = subprocess.run(cmd, cwd=cwd, stdout=f, stderr=subprocess.STDOUT,
                              stdin=subprocess.DEVNULL)
    return proc.returncode, time.time() - start


def read_flist(name: str) -> list[str]:
    files = []
    for line in (ROOT / "flist" / name).read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(str(ROOT / line))
    return files


def do_build(b: Build, vbin: Path) -> str | None:
    """성공하면 None, 실패하면 이유."""
    wd = OUT / b.name
    wd.mkdir(parents=True, exist_ok=True)

    cmd = [tool(vbin, "xvlog"), "-sv"]
    if b.uvm:
        cmd += ["-L", "uvm"]
    for inc in b.incdirs:
        cmd += ["-i", str(ROOT / inc)]
    for fl in b.flists:
        cmd += read_flist(fl)
    rc, _ = run(cmd, wd, wd / "compile.log")
    text = (wd / "compile.log").read_text(errors="replace")
    if rc != 0 or re.search(r"^ERROR:", text, re.M):
        return "xvlog failed (see compile.log)"

    for top in b.tops:
        cmd = [tool(vbin, "xelab"), "--timescale", "1ns/1ps"]
        if b.uvm:
            cmd += ["-L", "uvm"]
        cmd += [top, "-s", f"{top}_snap"]
        rc, _ = run(cmd, wd, wd / f"elab_{top}.log")
        text = (wd / f"elab_{top}.log").read_text(errors="replace")
        if rc != 0 or re.search(r"^ERROR:", text, re.M):
            return f"xelab {top} failed (see elab_{top}.log)"
    return None


def prepare_inputs(py: str) -> None:
    """시뮬레이션이 읽는 파일을 만든다 : Python 골든 벡터."""
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run([py, str(ROOT / "scripts" / "ecc_ref.py"), "gen",
                    str(OUT / "ecc_vectors.txt"), "1000", "2026"],
                   check=True, stdout=subprocess.DEVNULL)


def stage_needs(job: Job, wd: Path) -> None:
    for name in job.needs:
        src = OUT / name if (OUT / name).exists() else ROOT / "sw" / name
        shutil.copyfile(src, wd / name)
    if job.uvm_test:
        (wd / "uvm_test.txt").write_text(job.uvm_test + "\n")


def run_job(job: Job, vbin: Path, cov: bool) -> dict:
    wd = OUT / job.build
    stage_needs(job, wd)
    log = wd / f"{job.name}.log"
    cmd = [tool(vbin, "xsim"), f"{job.top}_snap", "-runall", "-log", f"{job.name}.xsim.log"]
    if job.seed is not None:
        cmd += ["-sv_seed", str(job.seed)]
    if cov and job.uvm_test:
        cmd += ["-cov_db_name", job.name]
    rc, secs = run(cmd, wd, log)
    text = log.read_text(errors="replace")

    reasons = []
    if rc != 0:
        reasons.append(f"simulator exit code {rc}")
    if not re.search(job.expect, text):
        reasons.append("PASS signature missing")
    for pattern, what in FORBIDDEN:
        hits = re.findall(pattern, text, re.M)
        if hits:
            reasons.append(f"{what} x{len(hits)}")

    info = {"name": job.name, "group": job.group, "seed": job.seed,
            "status": "FAIL" if reasons else "PASS", "reasons": reasons,
            "seconds": round(secs, 1), "log": str(log.relative_to(ROOT)).replace("\\", "/")}
    info.update(extract_metrics(text))
    return info


def extract_metrics(text: str) -> dict:
    """로그에서 보고서에 넣을 숫자를 뽑는다. 없으면 없는 대로 둔다."""
    m: dict = {}
    hit = re.search(r"\$finish called at time : (\d+) (\w+)", text)
    if hit:
        m["sim_time"] = f"{hit.group(1)} {hit.group(2)}"
    hit = re.search(r"\[SB\] ops=(\d+) .*checks=(\d+)", text)
    if hit:
        m["ops"] = int(hit.group(1))
        m["checks"] = int(hit.group(2))
    hit = re.search(r"functional coverage : operations ([\d.]+)%\s+ecc ([\d.]+)%", text)
    if hit:
        m["cov_op"] = float(hit.group(1))
        m["cov_ecc"] = float(hit.group(2))
    hit = re.search(r"PASS: (\d+) (?:pin-level|end-to-end) scenarios", text)
    if hit:
        m["scenarios"] = int(hit.group(1))
    hit = re.search(r"matches (\d+) Python golden vectors", text)
    if hit:
        m["vectors"] = int(hit.group(1))
    hit = re.search(r"single-bit regression \((\d+) checks\)", text)
    if hit:
        m["checks"] = int(hit.group(1))
    return m


def merge_coverage(vbin: Path) -> dict | None:
    """UVM 테스트들의 기능 커버리지 DB 를 xcrg 로 합쳐 하나의 숫자로 만든다."""
    wd = OUT / "uvm"
    if not (wd / "xsim.covdb").exists():
        return None
    rep = OUT / "cov_report"
    shutil.rmtree(rep, ignore_errors=True)
    shutil.rmtree(wd / "xsim.covdb" / "xcrg_mdb", ignore_errors=True)
    cmd = [tool(vbin, "xcrg"), "-dir", "xsim.covdb", "-report_format", "text",
           "-report_dir", str(rep), "-nolog"]
    rc, _ = run(cmd, wd, OUT / "xcrg.log")
    if rc != 0:
        return None
    report = rep / "xcrg_report.txt"
    if not report.exists():
        return None
    body = report.read_text(errors="replace")
    result: dict = {"report": str(report.relative_to(ROOT)).replace("\\", "/"), "holes": []}

    # xcrg 의 text 보고서는 쉼표로 나뉜 표다.
    #   "Coverage Score            :, 99.3056"
    #   "aio_uvm_pkg::aio_coverage::cg_op   ,98.6111 ,1 ,..."
    #   "cp_op   ,cg_op_obj.cg_op_cp_op ,4 ,0 ,4 ,100 ,..."   (이름, 태그, 기대, 미달, 달성, 퍼센트)
    hit = re.search(r"Coverage Score\s*:,\s*([\d.]+)", body)
    if hit:
        result["total"] = float(hit.group(1))
    for label, key in (("cg_op", "cov_op"), ("cg_ecc", "cov_ecc")):
        hit = re.search(rf"::{label}\s*,\s*([\d.]+)", body)
        if hit:
            result[key] = float(hit.group(1))
    seen = set()
    for hit in re.finditer(r"^\s*((?:cp|x)_\w+)\s*,\s*(\S+?)\s*,\s*(\d+)\s*,\s*\d+\s*,\s*(\d+)\s*,\s*([\d.]+)",
                           body, re.M):
        name, tag, expected, covered, pct = hit.groups()
        if float(pct) < 100.0 and tag not in seen:
            seen.add(tag)
            result["holes"].append(f"{name} {covered}/{expected} ({float(pct):.1f}%)")
    return result


# -----------------------------------------------------------------------------
# 보고서
# -----------------------------------------------------------------------------
def fmt_detail(r: dict) -> str:
    parts = []
    if "scenarios" in r:
        parts.append(f"{r['scenarios']} scenarios")
    if "vectors" in r:
        parts.append(f"{r['vectors']} vectors")
    if "ops" in r:
        parts.append(f"{r['ops']} ops")
    if "checks" in r:
        parts.append(f"{r['checks']:,} checks")
    if "cov_op" in r:
        parts.append(f"cov op {r['cov_op']:.0f}% / ecc {r['cov_ecc']:.0f}%")
    if r["reasons"]:
        parts.append("; ".join(r["reasons"]))
    return ", ".join(parts)


def write_report(results: list[dict], cov: dict | None, total_secs: float) -> None:
    n_pass = sum(r["status"] == "PASS" for r in results)
    lines = ["# Regression report", "",
             f"- result : **{n_pass} / {len(results)} PASS**",
             f"- wall time : {total_secs:.0f} s",
             f"- checks performed by scoreboards/testbenches : "
             f"{sum(r.get('checks', 0) for r in results):,}", ""]
    if cov:
        lines += ["## Merged functional coverage (all UVM tests)", ""]
        for key, label in (("cov_op", "operations (cg_op)"), ("cov_ecc", "ECC (cg_ecc)"),
                           ("total", "total")):
            if key in cov:
                lines.append(f"- {label} : {cov[key]:.1f}%")
        if cov.get("holes"):
            lines.append("- holes : " + "; ".join(cov["holes"]))
        else:
            lines.append("- holes : none (every coverpoint and cross is at 100%)")
        lines += [f"- report : `{cov['report']}`", ""]
    lines += ["## Tests", "", "| test | level | seed | result | sim time | wall (s) | detail |",
              "|---|---|---:|:---:|---:|---:|---|"]
    for r in results:
        lines.append(f"| {r['name']} | {r['group']} | {r['seed'] if r['seed'] is not None else '-'} "
                     f"| {r['status']} | {r.get('sim_time', '-')} | {r['seconds']} | {fmt_detail(r)} |")
    (OUT / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / "report.json").write_text(
        json.dumps({"results": results, "coverage": cov, "seconds": round(total_secs, 1)}, indent=2),
        encoding="utf-8")


def utf8_when_redirected() -> None:
    """파일로 받을 때는 UTF-8 로 쓴다. (한글 윈도의 기본값 cp949 로 쓰면 다른 도구에서 깨진다)"""
    if not sys.stdout.isatty():
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def main() -> int:
    utf8_when_redirected()
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--only", help="이름에 이 문자열이 든 테스트만 (쉼표로 여러 개)")
    ap.add_argument("--seeds", type=int, default=3, help="무작위 테스트 seed 개수 (기본 3)")
    ap.add_argument("--list", action="store_true", help="목록만 출력")
    ap.add_argument("--no-cov", action="store_true", help="커버리지 DB 병합 생략")
    ap.add_argument("--vivado-bin", help="Vivado bin 디렉터리")
    args = ap.parse_args()

    jobs = make_jobs(args.seeds)
    if args.only:
        keys = [k.strip() for k in args.only.split(",") if k.strip()]
        jobs = [j for j in jobs if any(k in j.name for k in keys)]
    if args.list:
        for j in jobs:
            print(f"{j.name:18s} {j.group:6s} top={j.top}" + (f" test={j.uvm_test}" if j.uvm_test else ""))
        return 0
    if not jobs:
        print("돌릴 테스트가 없다")
        return 2

    vbin = find_vivado_bin(args.vivado_bin)
    started = time.time()
    print(f"vivado : {vbin}")
    print(f"output : {OUT}")

    prepare_inputs(sys.executable)
    if (OUT / "uvm" / "xsim.covdb").exists():
        shutil.rmtree(OUT / "uvm" / "xsim.covdb", ignore_errors=True)

    results = []
    broken: dict[str, str] = {}
    for name in dict.fromkeys(j.build for j in jobs):
        print(f"[build] {name} ...", flush=True)
        why = do_build(BUILDS[name], vbin)
        if why:
            broken[name] = why
            print(f"        {why}")

    for job in jobs:
        if job.build in broken:
            r = {"name": job.name, "group": job.group, "seed": job.seed, "status": "FAIL",
                 "reasons": [broken[job.build]], "seconds": 0.0, "log": "-"}
        else:
            print(f"[run]   {job.name} ...", end=" ", flush=True)
            r = run_job(job, vbin, not args.no_cov)
            print(f"{r['status']}  ({r['seconds']} s)  {fmt_detail(r)}", flush=True)
        results.append(r)

    cov = None
    if not args.no_cov and any(j.uvm_test for j in jobs) and "uvm" not in broken:
        cov = merge_coverage(vbin)

    total = time.time() - started
    write_report(results, cov, total)

    n_pass = sum(r["status"] == "PASS" for r in results)
    print("-" * 72)
    if cov:
        shown = ", ".join(f"{k}={cov[k]:.1f}%" for k in ("total", "cov_op", "cov_ecc") if k in cov)
        print(f"merged functional coverage : {shown or '(see report)'}")
        if cov.get("holes"):
            print("coverage holes : " + "; ".join(cov["holes"]))
    print(f"{n_pass} / {len(results)} PASS   ({total:.0f} s)   report : {OUT / 'report.md'}")
    return 0 if n_pass == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
