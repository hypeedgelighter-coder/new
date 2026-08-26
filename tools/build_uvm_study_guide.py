from __future__ import annotations

from pathlib import Path
from typing import Iterable, Sequence

from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(r"D:\work\26_AI_COMP_1")
OUTPUT = ROOT / "output" / "pdf" / "tb_adder_uvm_guide_ko.pdf"

PAGE_W, PAGE_H = landscape(A4)
MARGIN = 34

NAVY = HexColor("#102A43")
BLUE = HexColor("#2563EB")
TEAL = HexColor("#0F766E")
ORANGE = HexColor("#D97706")
RED = HexColor("#C2413A")
PURPLE = HexColor("#6D28D9")
INK = HexColor("#17212B")
MUTED = HexColor("#52616B")
LINE = HexColor("#CBD5E1")
PALE_BLUE = HexColor("#EAF2FF")
PALE_TEAL = HexColor("#E7F7F4")
PALE_ORANGE = HexColor("#FFF4DE")
PALE_RED = HexColor("#FDECEA")
PALE_PURPLE = HexColor("#F1ECFF")
PAPER = HexColor("#F8FAFC")
CODE_BG = HexColor("#101827")
CODE_FG = HexColor("#E6EDF3")
CODE_MUTED = HexColor("#9FB0C0")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("Malgun", r"C:\Windows\Fonts\malgun.ttf"))
    pdfmetrics.registerFont(TTFont("Malgun-Bold", r"C:\Windows\Fonts\malgunbd.ttf"))
    pdfmetrics.registerFont(TTFont("Consolas", r"C:\Windows\Fonts\consola.ttf"))
    pdfmetrics.registerFont(TTFont("Consolas-Bold", r"C:\Windows\Fonts\consolab.ttf"))


def bottom(top: float, height: float = 0) -> float:
    return PAGE_H - top - height


def wrap_text(text: str, font: str, size: float, max_width: float) -> list[str]:
    lines: list[str] = []
    for raw_line in text.split("\n"):
        if not raw_line:
            lines.append("")
            continue
        words = raw_line.split(" ")
        current = ""
        for word in words:
            candidate = word if not current else current + " " + word
            if pdfmetrics.stringWidth(candidate, font, size) <= max_width:
                current = candidate
                continue
            if current:
                lines.append(current)
            current = ""
            if pdfmetrics.stringWidth(word, font, size) <= max_width:
                current = word
                continue
            piece = ""
            for ch in word:
                if pdfmetrics.stringWidth(piece + ch, font, size) <= max_width:
                    piece += ch
                else:
                    if piece:
                        lines.append(piece)
                    piece = ch
            current = piece
        if current:
            lines.append(current)
    return lines


def text_block(
    c: canvas.Canvas,
    text: str,
    x: float,
    top: float,
    width: float,
    *,
    font: str = "Malgun",
    size: float = 10,
    leading: float | None = None,
    color: Color = INK,
) -> float:
    leading = leading or size * 1.45
    c.setFillColor(color)
    c.setFont(font, size)
    y = PAGE_H - top - size
    for line in wrap_text(text, font, size, width):
        c.drawString(x, y, line)
        y -= leading
    return PAGE_H - y


def bullet_list(
    c: canvas.Canvas,
    items: Sequence[str],
    x: float,
    top: float,
    width: float,
    *,
    size: float = 9.2,
    bullet_color: Color = BLUE,
    gap: float = 6,
) -> float:
    cursor = top
    for item in items:
        c.setFillColor(bullet_color)
        c.circle(x + 3, PAGE_H - cursor - 5, 2.4, stroke=0, fill=1)
        cursor = text_block(c, item, x + 12, cursor, width - 12, size=size)
        cursor += gap
    return cursor


def round_box(
    c: canvas.Canvas,
    x: float,
    top: float,
    width: float,
    height: float,
    *,
    fill: Color = white,
    stroke: Color = LINE,
    radius: float = 8,
    line_width: float = 1,
) -> None:
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(line_width)
    c.roundRect(x, bottom(top, height), width, height, radius, stroke=1, fill=1)


def label_box(
    c: canvas.Canvas,
    x: float,
    top: float,
    width: float,
    height: float,
    title: str,
    subtitle: str = "",
    *,
    fill: Color = PALE_BLUE,
    stroke: Color = BLUE,
    title_color: Color = NAVY,
    center: bool = True,
) -> None:
    round_box(c, x, top, width, height, fill=fill, stroke=stroke, line_width=1.2)
    c.setFillColor(title_color)
    c.setFont("Malgun-Bold", 10.2)
    title_y = PAGE_H - top - 18
    if center:
        c.drawCentredString(x + width / 2, title_y, title)
    else:
        c.drawString(x + 10, title_y, title)
    if subtitle:
        c.setFont("Malgun", 7.6)
        c.setFillColor(MUTED)
        sub_y = title_y - 14
        if center:
            c.drawCentredString(x + width / 2, sub_y, subtitle)
        else:
            c.drawString(x + 10, sub_y, subtitle)


def arrow(
    c: canvas.Canvas,
    x1: float,
    top1: float,
    x2: float,
    top2: float,
    *,
    color: Color = BLUE,
    width: float = 1.8,
    dashed: bool = False,
    label: str | None = None,
    label_dx: float = 0,
    label_dy: float = -8,
) -> None:
    y1 = PAGE_H - top1
    y2 = PAGE_H - top2
    c.setStrokeColor(color)
    c.setFillColor(color)
    c.setLineWidth(width)
    c.setDash(5, 3) if dashed else c.setDash()
    c.line(x1, y1, x2, y2)
    c.setDash()
    dx, dy = x2 - x1, y2 - y1
    length = max((dx * dx + dy * dy) ** 0.5, 0.001)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    size = 7
    tip = (x2, y2)
    left = (x2 - ux * size + px * size * 0.55, y2 - uy * size + py * size * 0.55)
    right = (x2 - ux * size - px * size * 0.55, y2 - uy * size - py * size * 0.55)
    path = c.beginPath()
    path.moveTo(*tip)
    path.lineTo(*left)
    path.lineTo(*right)
    path.close()
    c.drawPath(path, stroke=0, fill=1)
    if label:
        c.setFillColor(color)
        c.setFont("Malgun-Bold", 7.4)
        mx = (x1 + x2) / 2 + label_dx
        my = (top1 + top2) / 2 + label_dy
        c.drawCentredString(mx, PAGE_H - my, label)


def section_label(c: canvas.Canvas, text: str, x: float, top: float, color: Color = BLUE) -> None:
    c.setFillColor(color)
    c.setFont("Malgun-Bold", 9)
    c.drawString(x, PAGE_H - top, text)


def code_box(
    c: canvas.Canvas,
    x: float,
    top: float,
    width: float,
    height: float,
    lines: Sequence[tuple[int | str, str]],
    *,
    title: str = "tb_adder.sv",
    highlights: Iterable[int | str] = (),
    font_size: float = 7.1,
) -> None:
    round_box(c, x, top, width, height, fill=CODE_BG, stroke=CODE_BG, radius=6)
    c.setFillColor(HexColor("#1F2B3D"))
    c.roundRect(x, bottom(top, 21), width, 21, 6, stroke=0, fill=1)
    c.rect(x, bottom(top + 12, 9), width, 9, stroke=0, fill=1)
    c.setFillColor(HexColor("#D5E1EC"))
    c.setFont("Consolas-Bold", 7.2)
    c.drawString(x + 9, PAGE_H - top - 14, title)
    highlight_set = set(highlights)
    y = PAGE_H - top - 34
    leading = font_size * 1.48
    for number, source in lines:
        if y < bottom(top, height) + 8:
            break
        if number in highlight_set:
            c.setFillColor(HexColor("#203A63"))
            c.roundRect(x + 6, y - 3, width - 12, leading + 1, 2, stroke=0, fill=1)
        c.setFillColor(CODE_MUTED)
        c.setFont("Consolas", font_size)
        c.drawRightString(x + 31, y, str(number))
        c.setFillColor(CODE_FG)
        c.drawString(x + 39, y, source)
        y -= leading


def phase_chip(c: canvas.Canvas, x: float, top: float, width: float, text: str, color: Color) -> None:
    c.setFillColor(color)
    c.roundRect(x, bottom(top, 24), width, 24, 12, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Malgun-Bold", 8.4)
    c.drawCentredString(x + width / 2, PAGE_H - top - 16, text)


class Guide:
    def __init__(self, output: Path):
        self.output = output
        self.output.parent.mkdir(parents=True, exist_ok=True)
        self.c = canvas.Canvas(str(output), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
        self.page_no = 0

    def start_page(self, title: str, subtitle: str = "") -> None:
        self.page_no += 1
        self.c.setFillColor(PAPER)
        self.c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        self.c.setFillColor(NAVY)
        self.c.setFont("Malgun-Bold", 20)
        self.c.drawString(MARGIN, PAGE_H - 42, title)
        if subtitle:
            self.c.setFillColor(MUTED)
            self.c.setFont("Malgun", 9)
            self.c.drawRightString(PAGE_W - MARGIN, PAGE_H - 39, subtitle)
        self.c.setStrokeColor(LINE)
        self.c.setLineWidth(0.8)
        self.c.line(MARGIN, PAGE_H - 55, PAGE_W - MARGIN, PAGE_H - 55)

    def end_page(self) -> None:
        self.c.setStrokeColor(LINE)
        self.c.line(MARGIN, 25, PAGE_W - MARGIN, 25)
        self.c.setFillColor(MUTED)
        self.c.setFont("Malgun", 7.5)
        self.c.drawString(MARGIN, 13, "tb_adder.sv로 배우는 UVM 기본")
        self.c.drawRightString(PAGE_W - MARGIN, 13, str(self.page_no))
        self.c.showPage()

    def save(self) -> None:
        self.c.save()


def build() -> Path:
    register_fonts()
    g = Guide(OUTPUT)
    c = g.c

    # 1. Cover
    g.start_page("tb_adder.sv로 배우는 UVM 기본", "day26.pdf + 로컬 코드 연결 학습 자료")
    c.setFillColor(BLUE)
    c.roundRect(MARGIN, bottom(82, 6), 112, 6, 3, stroke=0, fill=1)
    c.setFillColor(NAVY)
    c.setFont("Malgun-Bold", 30)
    c.drawString(MARGIN, PAGE_H - 126, "구조를 외우지 말고")
    c.drawString(MARGIN, PAGE_H - 166, "데이터가 흐르는 길로 읽기")
    text_block(
        c,
        "작업 폴더에서 확인된 파일명은 tb_adder.sv입니다. 아래 자료는 이 파일의 실제 줄 번호와 UVM 역할을 1:1로 연결합니다.",
        MARGIN,
        188,
        520,
        size=10.5,
        color=MUTED,
    )

    x_positions = [55, 185, 315, 445, 575, 705]
    names = ["Sequence", "Sequencer", "Driver", "Interface", "Monitor", "Scoreboard"]
    colors = [PURPLE, BLUE, BLUE, TEAL, ORANGE, RED]
    fills = [PALE_PURPLE, PALE_BLUE, PALE_BLUE, PALE_TEAL, PALE_ORANGE, PALE_RED]
    for x, name, color, fill in zip(x_positions, names, colors, fills):
        label_box(c, x, 278, 98, 58, name, fill=fill, stroke=color)
    for left, right, color in [(153, 185, PURPLE), (283, 315, BLUE), (413, 445, BLUE), (543, 575, ORANGE), (673, 705, RED)]:
        arrow(c, left, 307, right, 307, color=color)
    c.setFillColor(MUTED)
    c.setFont("Malgun", 8.5)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 360, "자극 생성 경로 + 관찰/판정 경로를 하나의 순환으로 이해하면 UVM 구성요소가 자연스럽게 연결됩니다.")

    round_box(c, MARGIN, 398, 238, 105, fill=PALE_BLUE, stroke=BLUE)
    section_label(c, "이 자료에서 답할 질문", MARGIN + 14, 421, BLUE)
    bullet_list(c, ["각 class는 왜 존재하는가?", "port/connect는 누가 누구와 연결되는가?", "한 transaction은 시간상 어떻게 움직이는가?"], MARGIN + 15, 436, 210, size=8.4, gap=2)
    round_box(c, 302, 398, 238, 105, fill=PALE_TEAL, stroke=TEAL)
    section_label(c, "핵심 관점", 316, 421, TEAL)
    bullet_list(c, ["component는 계층/phase를 가진다.", "object는 데이터/시나리오다.", "interface는 class 세계와 DUT 핀을 잇는다."], 317, 436, 208, size=8.4, bullet_color=TEAL, gap=2)
    round_box(c, 570, 398, 238, 105, fill=PALE_ORANGE, stroke=ORANGE)
    section_label(c, "현재 코드의 중요한 함정", 584, 421, ORANGE)
    bullet_list(c, ["driver와 monitor가 같은 posedge를 사용한다.", "각 run_phase가 한 번만 동작한다.", "첫 샘플이 이전 값/X가 될 수 있다."], 585, 436, 208, size=8.4, bullet_color=ORANGE, gap=2)
    g.end_page()

    # 2. Big picture
    g.start_page("1. 전체 구조: 두 개의 데이터 흐름", "먼저 화살표만 이해하기")
    section_label(c, "A. 자극을 DUT로 보내는 경로", MARGIN, 78, BLUE)
    top_nodes = [
        (40, "adder_sequence", "L37-61", PALE_PURPLE, PURPLE),
        (185, "adder_sqr", "L193, L203", PALE_BLUE, BLUE),
        (330, "adder_driver", "L65-105", PALE_BLUE, BLUE),
        (475, "adder_if", "L7-15", PALE_TEAL, TEAL),
        (620, "adder DUT", "L272-276", white, NAVY),
    ]
    for x, name, ref, fill, stroke in top_nodes:
        label_box(c, x, 100, 125, 55, name, ref, fill=fill, stroke=stroke)
    arrow(c, 165, 128, 185, 128, color=PURPLE, label="seq_item")
    arrow(c, 310, 128, 330, 128, color=BLUE, label="get/item_done")
    arrow(c, 455, 128, 475, 128, color=BLUE, label="a,b")
    arrow(c, 600, 128, 620, 128, color=TEAL, label="핀 연결")

    section_label(c, "B. DUT 결과를 관찰하고 판정하는 경로", MARGIN, 202, ORANGE)
    label_box(c, 620, 222, 125, 55, "adder DUT", "y = a + b", fill=white, stroke=NAVY)
    label_box(c, 475, 222, 125, 55, "adder_if", "a, b, y", fill=PALE_TEAL, stroke=TEAL)
    label_box(c, 330, 222, 125, 55, "adder_monitor", "L108-147", fill=PALE_ORANGE, stroke=ORANGE)
    label_box(c, 185, 222, 125, 55, "analysis_port", "send.write()", fill=PALE_ORANGE, stroke=ORANGE)
    label_box(c, 40, 222, 125, 55, "scoreboard", "write(data)", fill=PALE_RED, stroke=RED)
    arrow(c, 620, 250, 600, 250, color=TEAL, label="y")
    arrow(c, 475, 250, 455, 250, color=ORANGE, label="sample")
    arrow(c, 330, 250, 310, 250, color=ORANGE, label="broadcast")
    arrow(c, 185, 250, 165, 250, color=RED, label="즉시 호출")

    round_box(c, MARGIN, 318, 242, 176, fill=white, stroke=LINE)
    section_label(c, "정적 HDL 영역", MARGIN + 14, 342, TEAL)
    bullet_list(c, ["module tb_adder_uvm", "adder_if 실체 a_if", "adder DUT", "시뮬레이션 시작 전 이미 존재"], MARGIN + 15, 360, 210, size=8.8, bullet_color=TEAL)
    round_box(c, 300, 318, 242, 176, fill=white, stroke=LINE)
    section_label(c, "동적 UVM component 영역", 314, 342, BLUE)
    bullet_list(c, ["test/env/agent/driver/monitor/scoreboard", "run_test와 factory가 생성", "부모-자식 계층과 phase를 가짐", "`uvm_component_utils 사용"], 315, 360, 210, size=8.8, bullet_color=BLUE)
    round_box(c, 566, 318, 242, 176, fill=white, stroke=LINE)
    section_label(c, "UVM object 영역", 580, 342, PURPLE)
    bullet_list(c, ["seq_item: a,b,y 데이터 묶음", "adder_sequence: 생성 절차", "계층에 상주하지 않음", "`uvm_object_utils 사용"], 581, 360, 210, size=8.8, bullet_color=PURPLE)
    g.end_page()

    # 3. Hierarchy
    g.start_page("2. UVM 계층: 상자 안에 무엇이 들어가나", "component topology와 object를 구분")
    label_box(c, 320, 80, 200, 48, "uvm_test_top : adder_test", "L238-264 / run_test가 생성", fill=PALE_BLUE, stroke=BLUE)
    arrow(c, 420, 128, 420, 153, color=BLUE)
    label_box(c, 320, 154, 200, 48, "ENV : adder_environment", "L214-235", fill=PALE_BLUE, stroke=BLUE)
    arrow(c, 420, 202, 420, 227, color=BLUE)
    label_box(c, 190, 228, 200, 48, "AGT : adder_agent", "L188-211", fill=PALE_BLUE, stroke=BLUE)
    label_box(c, 505, 228, 160, 48, "SCB : scoreboard", "L150-185", fill=PALE_RED, stroke=RED)
    arrow(c, 390, 252, 505, 252, color=RED, dashed=True, label="analysis 연결", label_dy=-8)
    for x, title, ref, fill, stroke in [
        (55, "SQR", "uvm_sequencer", PALE_BLUE, BLUE),
        (205, "DRV", "adder_driver", PALE_BLUE, BLUE),
        (355, "MON", "adder_monitor", PALE_ORANGE, ORANGE),
    ]:
        label_box(c, x, 330, 120, 48, title, ref, fill=fill, stroke=stroke)
        arrow(c, 290, 276, x + 60, 330, color=stroke)
    arrow(c, 175, 354, 205, 354, color=BLUE, label="TLM")

    round_box(c, 690, 82, 118, 300, fill=PALE_PURPLE, stroke=PURPLE)
    section_label(c, "object (계층 밖)", 704, 108, PURPLE)
    label_box(c, 704, 128, 90, 48, "SEQ", "adder_sequence", fill=white, stroke=PURPLE)
    label_box(c, 704, 206, 90, 48, "SEQ_ITEM", "a,b,y", fill=white, stroke=PURPLE)
    arrow(c, 749, 176, 749, 206, color=PURPLE, label="create", label_dx=28, label_dy=-4)
    text_block(c, "SEQ는 test가 handle로 들고 있지만 component child가 아닙니다. 따라서 print_topology 상자에는 나타나지 않습니다.", 703, 280, 92, size=7.6, color=MUTED)

    round_box(c, 40, 420, 768, 80, fill=white, stroke=LINE)
    section_label(c, "생성 코드 읽는 법", 54, 444, BLUE)
    text_block(c, "adder_env = adder_environment::type_id::create(\"ENV\", this);", 54, 458, 390, font="Consolas", size=8.5, color=INK)
    text_block(c, "첫 인자 \"ENV\"는 인스턴스 이름, 두 번째 인자 this는 부모 component입니다. 이 부모 정보가 위의 트리를 만듭니다.", 54, 478, 720, size=8.7, color=MUTED)
    g.end_page()

    # 4. build/connect/config
    g.start_page("3. 생성과 연결: build -> connect -> run", "t=0에서 일어나는 일")
    phases = [(42, "top initial", TEAL), (178, "run_test", PURPLE), (314, "build_phase", BLUE), (470, "connect_phase", ORANGE), (646, "run_phase", RED)]
    for x, text, color in phases:
        phase_chip(c, x, 82, 112 if x != 646 else 118, text, color)
    for (x1, _, color), (x2, _, _) in zip(phases[:-1], phases[1:]):
        arrow(c, x1 + 112, 94, x2 - 5, 94, color=color)

    code_box(c, 40, 132, 245, 142, [(278, "initial begin"), (279, "uvm_config_db#(virtual adder_if)::set("), ("", "    null, \"*\", \"a_vif\", a_if);"), (280, "run_test(\"adder_test\");"), (281, "end")], highlights=[279, 280], font_size=7)
    code_box(c, 303, 132, 248, 142, [(248, "function void build_phase(...);"), (251, "adder_seq = adder_sequence::type_id::create("), ("", "    \"SEQ\", this);"), (252, "adder_env = adder_environment::type_id::create("), ("", "    \"ENV\", this);"), (253, "endfunction")], highlights=[251, 252], font_size=6.8)
    code_box(c, 569, 132, 239, 142, [(206, "function void connect_phase(...);"), (208, "adder_drv.seq_item_port.connect("), ("", "    adder_sqr.seq_item_export);"), (230, "function void connect_phase(...);"), (232, "adder_mon.send.connect(adder_scb.recv);")], highlights=[208, 232], font_size=6.5)

    round_box(c, 40, 310, 368, 184, fill=PALE_TEAL, stroke=TEAL)
    section_label(c, "virtual interface 전달", 55, 335, TEAL)
    text_block(c, "SET (top module, L279)", 55, 350, 155, font="Malgun-Bold", size=9, color=TEAL)
    text_block(c, "null : 설정을 넣는 시작 위치\n\"*\" : 모든 하위 component가 검색 가능\n\"a_vif\" : key 이름\na_if : 실제 interface 인스턴스", 55, 368, 155, size=8.2, color=INK)
    arrow(c, 218, 402, 264, 402, color=TEAL, label="config_db")
    text_block(c, "GET (driver L82-86, monitor L124-128)", 278, 350, 115, font="Malgun-Bold", size=8.6, color=TEAL)
    text_block(c, "this : 현재 component\n\"\" : 현재 위치\n\"a_vif\" : 같은 key\na_vif : 받을 virtual handle", 278, 376, 112, size=7.9, color=INK)

    round_box(c, 426, 310, 382, 184, fill=white, stroke=LINE)
    section_label(c, "왜 phase를 나누나", 441, 335, BLUE)
    bullet_list(c, ["build_phase: 하위 component를 모두 만든다.", "connect_phase: 만들어진 port/export를 잇는다.", "run_phase: 시간 소비 task들이 동시에 움직인다.", "report_phase: 시간이 멈춘 뒤 결과를 요약한다."], 442, 354, 345, size=8.7, bullet_color=BLUE, gap=6)
    g.end_page()

    # 5. Stimulus pipeline
    g.start_page("4. 자극 경로: sequence -> sequencer -> driver", "seq_item 하나가 이동하는 과정")
    code_box(c, 40, 80, 375, 198, [(46, "task body();"), (48, "seq_item::type_id::create(\"SEQ_ITEM\");"), (49, "start_item(adder_seq_item);"), (51, "if (!adder_seq_item.randomize()) begin"), (52, "  `uvm_fatal(\"SEQ\", \"randomized fail\")"), (58, "finish_item(adder_seq_item);"), (59, "endtask")], highlights=[48, 49, 51, 58], font_size=7.4)
    code_box(c, 433, 80, 375, 198, [(90, "task run_phase(uvm_phase phase);"), (94, "seq_item_port.get_next_item(adder_seq_item);"), (96, "@(posedge a_vif.clk);"), (97, "a_vif.a <= adder_seq_item.a;"), (98, "a_vif.b <= adder_seq_item.b;"), (102, "seq_item_port.item_done(adder_seq_item);"), (103, "endtask")], highlights=[94, 96, 97, 98, 102], font_size=7.2)

    steps = [
        (55, "1", "create", "빈 seq_item 생성", PURPLE),
        (185, "2", "start_item", "사용권(grant) 대기", PURPLE),
        (315, "3", "randomize", "a,b 결정", PURPLE),
        (445, "4", "finish_item", "driver 완료까지 대기", BLUE),
        (575, "5", "get_next_item", "driver가 item 수령", BLUE),
        (705, "6", "item_done", "handshake 종료", TEAL),
    ]
    for x, num, name, desc, color in steps:
        c.setFillColor(color)
        c.circle(x, PAGE_H - 335, 15, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont("Malgun-Bold", 9)
        c.drawCentredString(x, PAGE_H - 339, num)
        c.setFillColor(NAVY)
        c.setFont("Consolas-Bold", 8.2)
        c.drawCentredString(x, PAGE_H - 363, name)
        c.setFillColor(MUTED)
        c.setFont("Malgun", 7.2)
        c.drawCentredString(x, PAGE_H - 380, desc)
    for x1, x2 in zip([70, 200, 330, 460, 590], [170, 300, 430, 560, 690]):
        arrow(c, x1, 335, x2, 335, color=LINE, width=1.2)

    round_box(c, 40, 410, 768, 86, fill=PALE_BLUE, stroke=BLUE)
    section_label(c, "핵심: sequencer는 데이터를 직접 핀에 쓰지 않는다", 55, 435, BLUE)
    text_block(c, "sequencer는 sequence와 driver 사이에서 순서와 handshake를 중재합니다. 핀을 실제로 변경하는 주체는 driver이고, a_vif를 통해 interface의 a/b에 값을 씁니다. get_next_item과 item_done은 반드시 짝을 이뤄야 다음 item이 진행됩니다.", 55, 451, 725, size=8.8, color=INK)
    g.end_page()

    # 6. Observation pipeline
    g.start_page("5. 관찰 경로: monitor -> analysis port -> scoreboard", "broadcast는 관찰값을 복사해 전달하는 개념")
    code_box(c, 40, 80, 375, 210, [(135, "adder_seq_item = seq_item::type_id::create("), ("", "    \"SEQ_ITEM\");"), (137, "@(posedge a_vif.clk);"), (138, "adder_seq_item.a = a_vif.a;"), (139, "adder_seq_item.b = a_vif.b;"), (140, "adder_seq_item.y = a_vif.y;"), (141, "send.write(adder_seq_item);")], highlights=[137, 138, 139, 140, 141], font_size=7.2)
    code_box(c, 433, 80, 375, 210, [(162, "function void write(seq_item data);"), (164, "expected_data = data.a + data.b;"), (165, "if (expected_data == data.y) begin"), (168, "  pass_cnt++;"), (169, "end else begin"), (173, "  fail_cnt++;"), (175, "endfunction")], highlights=[164, 165, 168, 173], font_size=7.2)

    label_box(c, 55, 330, 130, 58, "adder_if", "a,b,y 핀", fill=PALE_TEAL, stroke=TEAL)
    label_box(c, 250, 330, 130, 58, "monitor", "sample + pack", fill=PALE_ORANGE, stroke=ORANGE)
    label_box(c, 445, 330, 130, 58, "send", "analysis_port", fill=PALE_ORANGE, stroke=ORANGE)
    label_box(c, 640, 330, 130, 58, "scoreboard", "write(data)", fill=PALE_RED, stroke=RED)
    arrow(c, 185, 359, 250, 359, color=ORANGE, label="posedge")
    arrow(c, 380, 359, 445, 359, color=ORANGE, label="seq_item")
    arrow(c, 575, 359, 640, 359, color=RED, label="connect L232")

    round_box(c, 55, 422, 715, 74, fill=white, stroke=LINE)
    c.setFillColor(ORANGE)
    c.setFont("Malgun-Bold", 9)
    c.drawString(70, PAGE_H - 448, "port / implementation 구분")
    text_block(c, "monitor의 uvm_analysis_port는 발행자이고, scoreboard의 uvm_analysis_imp는 구독자입니다. connect_phase에서 둘을 잇고, send.write(item)을 호출하면 scoreboard.write(item)가 같은 simulation time에 실행됩니다.", 70, 458, 680, size=8.5, color=INK)
    g.end_page()

    # 7. Phases
    g.start_page("6. 이 코드에서 실제로 쓰인 UVM phase", "모든 phase를 외우기보다 callback 위치를 찾기")
    columns = [
        (40, 80, "build_phase", BLUE, "생성 + 설정", ["driver/monitor: config_db get", "agent: DRV/MON/SQR create", "env: AGT/SCB create", "test: SEQ/ENV create"]),
        (235, 80, "connect_phase", ORANGE, "TLM 연결", ["DRV.seq_item_port -> SQR.export", "MON.send -> SCB.recv", "모든 대상이 만들어진 뒤 연결"]),
        (430, 80, "run_phase", TEAL, "시간 소비", ["test: objection + sequence start", "driver: item을 받아 drive", "monitor: 핀 sample", "각 component task는 동시에 실행"]),
        (625, 80, "report_phase", RED, "최종 요약", ["scoreboard가 pass/fail 출력", "transaction이 0개면 uvm_error", "simulation time은 이미 종료"]),
    ]
    for x, top, phase, color, subtitle, items in columns:
        round_box(c, x, top, 175, 224, fill=white, stroke=color)
        c.setFillColor(color)
        c.roundRect(x, bottom(top, 38), 175, 38, 8, stroke=0, fill=1)
        c.rect(x, bottom(top + 30, 8), 175, 8, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont("Consolas-Bold", 10)
        c.drawCentredString(x + 87.5, PAGE_H - top - 24, phase)
        c.setFillColor(MUTED)
        c.setFont("Malgun-Bold", 8.4)
        c.drawCentredString(x + 87.5, PAGE_H - top - 57, subtitle)
        bullet_list(c, items, x + 12, top + 76, 150, size=7.9, bullet_color=color, gap=7)

    section_label(c, "objection이 simulation 종료를 잡아두는 모습", 40, 342, PURPLE)
    c.setStrokeColor(LINE)
    c.setLineWidth(2)
    c.line(70, PAGE_H - 405, 770, PAGE_H - 405)
    c.setFillColor(PURPLE)
    c.rect(170, PAGE_H - 398, 480, 22, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Malgun-Bold", 8)
    c.drawCentredString(410, PAGE_H - 392, "objection count = 1 : run_phase 유지")
    for x, title, ref in [(70, "run 시작", ""), (170, "raise", "L257"), (300, "sequence.start", "L258"), (520, "#100", "L259"), (650, "drop", "L261"), (770, "report", "L177")]:
        c.setFillColor(NAVY)
        c.circle(x, PAGE_H - 405, 4, stroke=0, fill=1)
        c.setFont("Malgun-Bold", 7.3)
        c.drawCentredString(x, PAGE_H - 425, title)
        if ref:
            c.setFillColor(MUTED)
            c.setFont("Malgun", 6.8)
            c.drawCentredString(x, PAGE_H - 439, ref)
    text_block(c, "주의: objection은 test가 끝날 때까지 시간을 보장할 뿐, driver/monitor를 반복 실행시키지는 않습니다.", 40, 468, 760, size=9, color=RED)
    g.end_page()

    # 8. Exact timeline and race
    g.start_page("7. 한 transaction의 시간 순서와 첫 샘플 race", "현재 코드 그대로 따라가기")
    lanes = [("test/sequence", PURPLE), ("driver", BLUE), ("interface/DUT", TEAL), ("monitor", ORANGE), ("scoreboard", RED)]
    x0, x1 = 150, 790
    c.setFillColor(MUTED)
    c.setFont("Malgun", 7.5)
    for x, label in [(165, "0 ns"), (380, "run 진입"), (560, "5 ns posedge"), (750, "약 105 ns")]:
        c.drawCentredString(x, PAGE_H - 84, label)
        c.setStrokeColor(LINE)
        c.setLineWidth(0.7)
        c.line(x, PAGE_H - 92, x, PAGE_H - 366)
    for idx, (name, color) in enumerate(lanes):
        top = 110 + idx * 55
        c.setFillColor(color)
        c.setFont("Malgun-Bold", 8.2)
        c.drawRightString(135, PAGE_H - top - 4, name)
        c.setStrokeColor(LINE)
        c.setLineWidth(1)
        c.line(x0, PAGE_H - top, x1, PAGE_H - top)
    # Events
    events = [
        (165, 110, "config set / run_test", PURPLE),
        (380, 110, "start_item -> randomize", PURPLE),
        (470, 165, "get_next_item 해제", BLUE),
        (560, 165, "a,b <= item (NBA 예약)", BLUE),
        (575, 220, "a,b 갱신 -> y 재계산", TEAL),
        (560, 275, "이전 a,b,y를 읽을 수 있음", ORANGE),
        (560, 330, "즉시 compare", RED),
        (750, 110, "drop objection", PURPLE),
    ]
    for x, top, text, color in events:
        c.setFillColor(color)
        c.circle(x, PAGE_H - top, 5, stroke=0, fill=1)
        c.setFont("Malgun", 7.1)
        anchor = x + 7 if x < 700 else x - 7
        if x < 700:
            c.drawString(anchor, PAGE_H - top + 8, text)
        else:
            c.drawRightString(anchor, PAGE_H - top + 8, text)

    round_box(c, 40, 395, 370, 112, fill=PALE_RED, stroke=RED)
    section_label(c, "왜 첫 로그가 0/X 또는 FAIL일 수 있나", 55, 420, RED)
    text_block(c, "driver와 monitor가 둘 다 같은 posedge에서 깨어납니다. driver는 <=로 NBA 영역에 a,b 갱신을 예약하지만, monitor는 그 전에 현재 값을 읽을 수 있습니다. 따라서 새 item이 아니라 이전 핀 값을 scoreboard로 보낼 수 있습니다.", 55, 438, 340, size=8.2, color=INK)
    round_box(c, 428, 395, 380, 112, fill=PALE_TEAL, stroke=TEAL)
    section_label(c, "학습용으로 가장 단순한 안전 패턴", 443, 420, TEAL)
    text_block(c, "driver는 negedge에 drive하고 monitor는 다음 posedge에 sample합니다. 더 정석적인 방법은 interface clocking block으로 drive/sample skew를 명시하는 것입니다. 이때 DUT가 값을 계산할 delta cycle도 확보됩니다.", 443, 438, 350, size=8.2, color=INK)
    g.end_page()

    # 9. One-shot and repeat
    g.start_page("8. 현재 코드는 '한 번만' 움직인다", "반복 테스트로 확장할 때 바뀌는 지점")
    round_box(c, 40, 80, 236, 170, fill=PALE_PURPLE, stroke=PURPLE)
    section_label(c, "sequence", 55, 105, PURPLE)
    c.setFillColor(NAVY)
    c.setFont("Malgun-Bold", 24)
    c.drawString(55, PAGE_H - 153, "1 item")
    text_block(c, "body()에 repeat가 없으므로 seq_item을 한 번만 만들고 보냅니다.", 55, 170, 200, size=8.5, color=MUTED)
    round_box(c, 303, 80, 236, 170, fill=PALE_BLUE, stroke=BLUE)
    section_label(c, "driver", 318, 105, BLUE)
    c.setFillColor(NAVY)
    c.setFont("Malgun-Bold", 24)
    c.drawString(318, PAGE_H - 153, "1 receive")
    text_block(c, "run_phase에 forever가 없으므로 get/drive/done을 한 번만 수행합니다.", 318, 170, 200, size=8.5, color=MUTED)
    round_box(c, 566, 80, 242, 170, fill=PALE_ORANGE, stroke=ORANGE)
    section_label(c, "monitor", 581, 105, ORANGE)
    c.setFillColor(NAVY)
    c.setFont("Malgun-Bold", 24)
    c.drawString(581, PAGE_H - 153, "1 sample")
    text_block(c, "run_phase에 forever가 없으므로 첫 posedge에서 한 번만 sample합니다.", 581, 170, 205, size=8.5, color=MUTED)

    code_box(c, 40, 286, 368, 210, [(1, "class adder_sequence extends uvm_sequence #(seq_item);"), (2, "  task body();"), (3, "    repeat (10) begin"), (4, "      req = seq_item::type_id::create(\"req\");"), (5, "      start_item(req);"), (6, "      if (!req.randomize()) `uvm_fatal(...);"), (7, "      finish_item(req);"), (8, "    end"), (9, "  endtask"), (10, "endclass")], title="반복 sequence 예시", highlights=[1, 3, 4], font_size=6.8)
    code_box(c, 426, 286, 382, 210, [(1, "task run_phase(uvm_phase phase);"), (2, "  forever begin"), (3, "    seq_item_port.get_next_item(req);"), (4, "    @(negedge a_vif.clk);"), (5, "    a_vif.a <= req.a;"), (6, "    a_vif.b <= req.b;"), (7, "    seq_item_port.item_done();"), (8, "  end"), (9, "endtask")], title="반복 driver 예시", highlights=[2, 3, 4, 7], font_size=6.9)
    g.end_page()

    # 10. Diagnostic checklist
    g.start_page("9. 이 코드에서 바로 확인할 5가지", "구조 이해 + 디버깅 포인트")
    checks = [
        ("1", "동일 posedge race", "driver의 NBA drive와 monitor sample이 충돌할 수 있습니다. 첫 샘플이 이전 값/X이면 구조 문제가 아니라 timing 문제부터 확인합니다.", RED, PALE_RED),
        ("2", "one-shot 구조", "sequence, driver, monitor 모두 한 번만 수행합니다. 여러 vector를 기대했다면 repeat/forever가 필요합니다.", ORANGE, PALE_ORANGE),
        ("3", "DUT 정의와 y 폭", "현재 08_25 프로젝트 폴더에서는 module adder 정의가 검색되지 않았습니다. 08_24 adder를 쓴다면 y가 8-bit이고 interface/expected는 9-bit라 overflow 비교가 어긋날 수 있습니다.", TEAL, PALE_TEAL),
        ("4", "타입이 지정된 sequence", "class adder_sequence extends uvm_sequence #(seq_item) 형태가 더 안전합니다. sequencer/driver/item 타입이 컴파일 단계에서 맞는지 확인할 수 있습니다.", BLUE, PALE_BLUE),
        ("5", "FAIL의 severity", "현재 mismatch도 `uvm_info로 출력합니다. 자동 회귀 테스트에서는 mismatch에 `uvm_error를 써야 최종 오류 수에 반영됩니다.", PURPLE, PALE_PURPLE),
    ]
    top = 82
    for num, title, body, color, fill in checks:
        round_box(c, 40, top, 768, 76, fill=fill, stroke=color)
        c.setFillColor(color)
        c.circle(70, PAGE_H - top - 38, 18, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont("Malgun-Bold", 11)
        c.drawCentredString(70, PAGE_H - top - 42, num)
        c.setFillColor(NAVY)
        c.setFont("Malgun-Bold", 10)
        c.drawString(102, PAGE_H - top - 25, title)
        text_block(c, body, 102, top + 34, 686, size=8.1, color=INK)
        top += 84
    g.end_page()

    # 11. Final map
    g.start_page("10. 30초 요약: 이 파일을 읽는 순서", "줄 번호를 따라 다시 보기")
    rows = [
        ("0", "interface", "L7-15", "class와 DUT 핀 사이의 공동 신호 묶음", TEAL),
        ("1", "seq_item", "L18-33", "a,b,y를 담는 transaction 데이터", PURPLE),
        ("2", "sequence", "L37-61", "item 생성, randomize, sequencer에 전달", PURPLE),
        ("3", "driver", "L65-105", "item을 실제 interface a,b로 drive", BLUE),
        ("4", "monitor", "L108-147", "interface a,b,y를 관찰해 item으로 포장", ORANGE),
        ("5", "scoreboard", "L150-185", "expected=a+b와 actual y를 비교", RED),
        ("6", "agent", "L188-211", "sequencer + driver + monitor를 한 묶음으로 구성", BLUE),
        ("7", "environment", "L214-235", "agent + scoreboard를 구성하고 연결", BLUE),
        ("8", "test", "L238-264", "시나리오 시작과 objection 제어", PURPLE),
        ("9", "top module", "L266-284", "clock/DUT/interface/config_db/run_test 시작점", TEAL),
    ]
    top = 76
    for num, name, ref, desc, color in rows:
        c.setFillColor(color)
        c.circle(55, PAGE_H - top - 13, 10, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont("Malgun-Bold", 7.5)
        c.drawCentredString(55, PAGE_H - top - 16, num)
        c.setFillColor(NAVY)
        c.setFont("Consolas-Bold", 9)
        c.drawString(78, PAGE_H - top - 16, name)
        c.setFillColor(MUTED)
        c.setFont("Consolas", 7.8)
        c.drawString(190, PAGE_H - top - 16, ref)
        c.setFont("Malgun", 8.3)
        c.drawString(270, PAGE_H - top - 16, desc)
        c.setStrokeColor(LINE)
        c.setLineWidth(0.5)
        c.line(78, PAGE_H - top - 25, 805, PAGE_H - top - 25)
        top += 42

    round_box(c, 40, 500, 768, 34, fill=NAVY, stroke=NAVY)
    c.setFillColor(white)
    c.setFont("Malgun-Bold", 9.2)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 522, "한 문장으로: sequence가 만든 item을 driver가 DUT에 넣고, monitor가 결과를 다시 item으로 만들어 scoreboard가 판정한다.")
    g.end_page()

    g.save()
    return OUTPUT


if __name__ == "__main__":
    result = build()
    print(result)
