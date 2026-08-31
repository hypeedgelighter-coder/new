"""SystemVerilog 심화 과정 강의자료 PDF 빌더.

두 번 렌더링한다.  1차는 목차 항목과 각 항목의 페이지 번호를 모으고,
2차는 표지 뒤에 목차를 끼워 넣은 뒤 그만큼 밀린 페이지 번호로 다시 그린다.
목차 페이지 수는 항목 수만으로 정해지므로 두 패스의 결과가 정확히 일치한다.

    python build_sv_course.py [출력경로]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lecture.engine import Document, register_fonts
from lecture.preface import PREFACE

TITLE = "SystemVerilog 심화 과정"
SUBTITLE = "대학생 대상 · 검증 방법론 중심"


def _parts() -> list:
    from lecture import (part1_language, part2_oop, part3_verification,
                         part4_uvm, part5_labs, part6_advanced,
                         part7_extended, part7_appendix)
    return [part1_language, part2_oop, part3_verification, part4_uvm,
            part5_labs, part6_advanced, part7_extended, part7_appendix]


def render(path: Path, toc_entries=None, offset: int = 0) -> Document:
    doc = Document(path, TITLE, SUBTITLE)
    doc.cover(
        ["SystemVerilog", "심화 과정"],
        [
            "RTL 기술에서 UVM 검증 방법론까지",
            "",
            "대상   전자 · 컴퓨터공학 3-4학년 / 검증 입문 대학원생",
            "선수   Verilog HDL, 디지털 논리회로",
            "환경   Xilinx Vivado 2020.2 · UVM 1.2",
            "구성   8개 파트 · 59개 장 · 실습 과제 90여 개",
        ],
    )
    if toc_entries is not None:
        doc.toc_pages(toc_entries, offset)

    doc.part = "서문"
    doc.chapter_start(PREFACE["number"], PREFACE["title"], PREFACE["goals"])
    doc.add(PREFACE["body"])

    for mod in _parts():
        meta = mod.PART
        doc.part_page(meta["number"], meta["title"], meta["blurb"], meta["items"])
        for ch in mod.CHAPTERS:
            doc.chapter_start(ch["number"], ch["title"], ch["goals"])
            doc.add(ch["body"])
    return doc


def build(out: Path) -> tuple[Path, int]:
    register_fonts()
    scratch = out.parent / (".pass1_" + out.name)

    pass1 = render(scratch)
    pass1.save()
    entries = pass1.toc
    toc_pages = Document.toc_page_count(entries)

    final = render(out, toc_entries=entries, offset=toc_pages)
    final.save()
    try:
        scratch.unlink()
    except OSError:
        pass
    return out, final.page


if __name__ == "__main__":
    target = (Path(sys.argv[1]) if len(sys.argv) > 1
              else Path.home() / "Desktop" / "SystemVerilog_심화과정_강의자료.pdf")
    path, pages = build(target)
    print(f"{path}\n{pages} pages")
