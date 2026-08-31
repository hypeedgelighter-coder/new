from pathlib import Path

from reportlab.lib.colors import HexColor, white
from reportlab.pdfgen import canvas

from build_uvm_study_guide import (
    BLUE,
    CODE_BG,
    INK,
    LINE,
    MARGIN,
    MUTED,
    NAVY,
    ORANGE,
    PAGE_H,
    PAGE_W,
    PALE_BLUE,
    PALE_ORANGE,
    PALE_PURPLE,
    PALE_RED,
    PALE_TEAL,
    PAPER,
    PURPLE,
    RED,
    TEAL,
    arrow,
    bottom,
    bullet_list,
    code_box,
    label_box,
    register_fonts,
    round_box,
    section_label,
    text_block,
)


OUTPUT = Path(r"C:\Users\kccistc\Desktop\UVM_Registry_Factory_Phase.pdf")


class DesktopGuide:
    def __init__(self, output: Path):
        output.parent.mkdir(parents=True, exist_ok=True)
        self.output = output
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
        self.c.drawString(MARGIN, 13, "tb_adder.sv - Registry / Factory / Phase")
        self.c.drawRightString(PAGE_W - MARGIN, 13, str(self.page_no))
        self.c.showPage()

    def save(self) -> None:
        self.c.save()


def build() -> Path:
    register_fonts()
    guide = DesktopGuide(OUTPUT)
    c = guide.c

    # Page 1: complete mental model
    guide.start_page("UVM Registry - Factory - Phase 실행 흐름", "tb_adder.sv 코드와 1:1 연결")
    section_label(c, "1. 타입을 명단에 등록", 42, 82, PURPLE)
    label_box(c, 42, 98, 200, 75, "Registry", fill=PALE_PURPLE, stroke=PURPLE)
    text_block(
        c,
        "`uvm_component_utils(adder_test)\n`uvm_component_utils(adder_driver)\n`uvm_object_utils(adder_sequence)",
        55,
        126,
        175,
        font="Consolas",
        size=7.4,
        color=INK,
    )

    section_label(c, "2. 생성 요청", 320, 82, BLUE)
    label_box(c, 320, 98, 200, 75, "Factory", fill=PALE_BLUE, stroke=BLUE)
    text_block(c, "run_test(\"adder_test\")\ntype_id::create(\"ENV\", this)", 337, 130, 166, font="Consolas", size=7.5, color=INK)

    section_label(c, "3. component tree 완성", 598, 82, TEAL)
    label_box(c, 598, 98, 200, 75, "Topology", fill=PALE_TEAL, stroke=TEAL)
    text_block(c, "TEST -> ENV -> AGT\n             -> DRV / MON / SQR\n       -> SCB", 615, 128, 166, font="Consolas", size=7.2, color=INK)

    arrow(c, 242, 136, 320, 136, color=PURPLE, label="create 요청")
    arrow(c, 520, 136, 598, 136, color=BLUE, label="instance")

    section_label(c, "4. UVM phase scheduler가 생성된 component를 실행", 42, 222, BLUE)
    phases = [
        (42, "build_phase", "생성 + config get", BLUE, PALE_BLUE),
        (238, "connect_phase", "TLM port 연결", ORANGE, PALE_ORANGE),
        (434, "run_phase", "task 동시 실행", TEAL, PALE_TEAL),
        (630, "report_phase", "최종 결과 요약", RED, PALE_RED),
    ]
    for x, title, desc, color, fill in phases:
        label_box(c, x, 242, 168, 62, title, desc, fill=fill, stroke=color)
    arrow(c, 210, 273, 238, 273, color=BLUE)
    arrow(c, 406, 273, 434, 273, color=ORANGE)
    arrow(c, 602, 273, 630, 273, color=TEAL)

    round_box(c, 42, 340, 756, 92, fill=PALE_PURPLE, stroke=PURPLE)
    section_label(c, "Object 분기: sequence는 component phase를 자동 실행하지 않음", 58, 365, PURPLE)
    label_box(c, 60, 380, 150, 38, "SEQ object", "L251", fill=white, stroke=PURPLE)
    arrow(c, 210, 399, 315, 399, color=PURPLE, label="adder_seq.start(...) L258")
    label_box(c, 315, 380, 175, 38, "sequence.body()", "L46-59", fill=white, stroke=PURPLE)
    arrow(c, 490, 399, 595, 399, color=PURPLE, label="create / randomize")
    label_box(c, 595, 380, 175, 38, "SEQ_ITEM object", "a, b, y", fill=white, stroke=PURPLE)

    round_box(c, 42, 462, 756, 52, fill=NAVY, stroke=NAVY)
    c.setFillColor(white)
    c.setFont("Malgun-Bold", 10)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 484, "utils = 타입 등록   |   type_id::create = Factory 생성   |   phase = 생성된 component 자동 callback")
    c.setFont("Malgun", 8)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 502, "sequence.body는 phase가 아니라 test.run_phase 안의 start() 호출로 실행")
    guide.end_page()

    # Page 2: registration and factory code mapping
    guide.start_page("Registry와 Factory 코드 연결", "등록 코드와 생성 코드를 분리해서 보기")
    code_box(
        c,
        42,
        80,
        360,
        206,
        [
            (18, "class seq_item extends uvm_sequence_item;"),
            (27, "`uvm_object_utils_begin(seq_item)"),
            (28, "  `uvm_field_int(a, UVM_DEFAULT)"),
            (31, "`uvm_object_utils_end"),
            (37, "class adder_sequence extends uvm_sequence;"),
            (39, "`uvm_object_utils(adder_sequence)"),
            (65, "class adder_driver extends uvm_driver #(seq_item);"),
            (67, "`uvm_component_utils(adder_driver)"),
            (238, "class adder_test extends uvm_test;"),
            (239, "`uvm_component_utils(adder_test)"),
        ],
        title="A. Registry 등록 - 인스턴스 생성 아님",
        highlights=[27, 39, 67, 239],
        font_size=6.6,
    )
    code_box(
        c,
        438,
        80,
        360,
        206,
        [
            (280, "run_test(\"adder_test\");"),
            (251, "adder_seq = adder_sequence::type_id::create("),
            ("", "    \"SEQ\", this);"),
            (252, "adder_env = adder_environment::type_id::create("),
            ("", "    \"ENV\", this);"),
            (201, "adder_drv = adder_driver::type_id::create("),
            ("", "    \"DRV\", this);"),
            (202, "adder_mon = adder_monitor::type_id::create("),
            ("", "    \"MON\", this);"),
            (203, "adder_sqr = uvm_sequencer#(seq_item)::type_id::create("),
            ("", "    \"SQR\", this);"),
        ],
        title="B. Factory 생성 - Registry에서 타입 조회",
        highlights=[280, 251, 252, 201, 202, 203],
        font_size=6.25,
    )

    section_label(c, "Factory가 만드는 component 계층", 42, 326, BLUE)
    label_box(c, 315, 344, 210, 44, "uvm_test_top : adder_test", "run_test가 Factory로 생성", fill=PALE_BLUE, stroke=BLUE)
    arrow(c, 420, 388, 420, 408, color=BLUE)
    label_box(c, 315, 409, 210, 44, "ENV : adder_environment", "test.build_phase L252", fill=PALE_BLUE, stroke=BLUE)
    arrow(c, 420, 453, 420, 473, color=BLUE)
    label_box(c, 170, 474, 210, 40, "AGT : adder_agent", "env.build_phase L226", fill=PALE_BLUE, stroke=BLUE)
    label_box(c, 535, 474, 150, 40, "SCB", "env.build_phase L227", fill=PALE_RED, stroke=RED)
    arrow(c, 380, 494, 535, 494, color=RED, dashed=True, label="analysis 연결")

    round_box(c, 42, 344, 190, 110, fill=PALE_PURPLE, stroke=PURPLE)
    section_label(c, "SEQ는 다른 경우", 58, 369, PURPLE)
    text_block(c, "adder_seq도 Factory가 생성하지만 uvm_object입니다. test의 component child가 아니며 build/connect/run phase가 자동 호출되지 않습니다.", 58, 384, 158, size=7.8, color=INK)
    guide.end_page()

    # Page 3: phase runtime
    guide.start_page("Phase는 언제, 누가 실행하는가", "자동 callback과 직접 호출을 구분")
    entries = [
        ("build_phase", "UVM 자동", "0 ns / top-down", "하위 component 생성, config_db get", BLUE, PALE_BLUE),
        ("connect_phase", "UVM 자동", "0 ns / bottom-up", "sequencer-driver, monitor-scoreboard 연결", ORANGE, PALE_ORANGE),
        ("run_phase", "UVM 자동", "시간 진행 / 동시 실행", "test, driver, monitor task 실행", TEAL, PALE_TEAL),
        ("sequence.body", "start() 직접 호출", "test.run_phase 내부", "seq_item 생성, randomize, 전달", PURPLE, PALE_PURPLE),
        ("report_phase", "UVM 자동", "run 종료 후", "scoreboard PASS/FAIL 요약", RED, PALE_RED),
    ]
    top = 82
    for phase, caller, timing, purpose, color, fill in entries:
        round_box(c, 42, top, 756, 66, fill=fill, stroke=color)
        c.setFillColor(color)
        c.setFont("Consolas-Bold", 10)
        c.drawString(58, PAGE_H - top - 25, phase)
        c.setFillColor(NAVY)
        c.setFont("Malgun-Bold", 8.5)
        c.drawString(235, PAGE_H - top - 25, caller)
        c.setFillColor(MUTED)
        c.setFont("Malgun", 7.8)
        c.drawString(370, PAGE_H - top - 25, timing)
        c.setFillColor(INK)
        c.setFont("Malgun", 8.2)
        c.drawString(58, PAGE_H - top - 49, purpose)
        top += 75

    code_box(
        c,
        42,
        466,
        756,
        78,
        [
            (257, "phase.raise_objection(this);"),
            (258, "adder_seq.start(adder_env.adder_agt.adder_sqr);  // body() 직접 실행"),
            (259, "#100;"),
            (261, "phase.drop_objection(this);"),
        ],
        title="test.run_phase - 자동 호출된 phase 안에서 object를 직접 시작",
        highlights=[257, 258, 261],
        font_size=7.2,
    )
    guide.end_page()

    guide.save()
    return OUTPUT


if __name__ == "__main__":
    print(build())
