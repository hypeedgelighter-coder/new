"""Flowing two-column PDF layout engine for long-form lecture material.

Content is declared as plain data (see blocks.py helpers); this module measures
each block against the column width, then streams blocks into columns and pages,
breaking automatically.  Landscape A4 so the result doubles as slides.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Sequence

from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

PAGE_W, PAGE_H = landscape(A4)

MARGIN_X = 40.0
MARGIN_TOP = 52.0
MARGIN_BOT = 40.0
COL_GAP = 26.0
COL_W = (PAGE_W - 2 * MARGIN_X - COL_GAP) / 2.0

NAVY = HexColor("#102A43")
BLUE = HexColor("#2563EB")
TEAL = HexColor("#0F766E")
ORANGE = HexColor("#B45309")
RED = HexColor("#C2413A")
PURPLE = HexColor("#6D28D9")
GREEN = HexColor("#15803D")
INK = HexColor("#17212B")
MUTED = HexColor("#52616B")
LINE = HexColor("#CBD5E1")
FAINT = HexColor("#E2E8F0")

PALE_BLUE = HexColor("#EAF2FF")
PALE_TEAL = HexColor("#E7F7F4")
PALE_ORANGE = HexColor("#FFF4DE")
PALE_RED = HexColor("#FDECEA")
PALE_PURPLE = HexColor("#F1ECFF")
PALE_GREEN = HexColor("#ECFDF3")
PAPER = HexColor("#FBFCFE")

CODE_BG = HexColor("#101827")
CODE_FG = HexColor("#E6EDF3")
CODE_MUTED = HexColor("#8FA3B8")
CODE_HL = HexColor("#22375C")

BODY_FONT = "Malgun"
BOLD_FONT = "Malgun-Bold"
MONO_FONT = "Consolas"
MONO_BOLD = "Consolas-Bold"

BODY_SIZE = 9.4
BODY_LEAD = 13.6
CODE_SIZE = 7.0
CODE_LEAD = 10.2


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont(BODY_FONT, r"C:\Windows\Fonts\malgun.ttf"))
    pdfmetrics.registerFont(TTFont(BOLD_FONT, r"C:\Windows\Fonts\malgunbd.ttf"))
    pdfmetrics.registerFont(TTFont(MONO_FONT, r"C:\Windows\Fonts\consola.ttf"))
    pdfmetrics.registerFont(TTFont(MONO_BOLD, r"C:\Windows\Fonts\consolab.ttf"))


# --------------------------------------------------------------------------
# text measurement
# --------------------------------------------------------------------------

def wrap(text: str, font: str, size: float, max_width: float) -> list[str]:
    """Word-wrap with a per-character fallback so Korean runs break cleanly."""
    out: list[str] = []
    for raw in text.split("\n"):
        if not raw:
            out.append("")
            continue
        cur = ""
        for word in raw.split(" "):
            cand = word if not cur else cur + " " + word
            if pdfmetrics.stringWidth(cand, font, size) <= max_width:
                cur = cand
                continue
            if cur:
                out.append(cur)
            if pdfmetrics.stringWidth(word, font, size) <= max_width:
                cur = word
                continue
            piece = ""
            for ch in word:
                if pdfmetrics.stringWidth(piece + ch, font, size) <= max_width:
                    piece += ch
                else:
                    if piece:
                        out.append(piece)
                    piece = ch
            cur = piece
        out.append(cur)
    return out


# --- monospace with Korean -------------------------------------------------
#
# Consolas has no Hangul glyphs, so a Korean comment inside a code block would
# silently render as blank.  Code and ASCII art are therefore drawn run by run:
# Latin runs in Consolas, CJK runs in Malgun scaled to occupy exactly two
# monospace cells.  That keeps the terminal-style column grid intact, which the
# ASCII diagrams depend on.

def _is_wide(ch: str) -> bool:
    o = ord(ch)
    return (0x1100 <= o <= 0x115F or 0x2E80 <= o <= 0xA4CF
            or 0xAC00 <= o <= 0xD7A3 or 0xF900 <= o <= 0xFAFF
            or 0xFE30 <= o <= 0xFE6F or 0xFF00 <= o <= 0xFF60
            or 0xFFE0 <= o <= 0xFFE6)


_HANGUL_EM: list[float] = []


def _hangul_em() -> float:
    """Advance width of one Hangul syllable at 1pt in the body font."""
    if not _HANGUL_EM:
        _HANGUL_EM.append(pdfmetrics.stringWidth("가", BODY_FONT, 100) / 100.0)
    return _HANGUL_EM[0]


def mono_cells(text: str) -> int:
    return sum(2 if _is_wide(ch) else 1 for ch in text)


def mono_width(text: str, size: float) -> float:
    return mono_cells(text) * pdfmetrics.stringWidth("0", MONO_FONT, size)


def mono_shrink(text: str, size: float, max_width: float) -> str:
    if mono_width(text, size) <= max_width:
        return text
    cell = pdfmetrics.stringWidth("0", MONO_FONT, size)
    budget = max_width - 3 * cell
    out, used = "", 0.0
    for ch in text:
        w = (2 if _is_wide(ch) else 1) * cell
        if used + w > budget:
            break
        out += ch
        used += w
    return out + "..."


def draw_mono(c: canvas.Canvas, x: float, y: float, text: str, size: float) -> float:
    """Draw a monospace line that may contain Hangul; returns the end x."""
    cell = pdfmetrics.stringWidth("0", MONO_FONT, size)
    han_size = (2 * cell) / _hangul_em()
    run: list[str] = []
    run_wide = False

    def flush(xx: float) -> float:
        if not run:
            return xx
        if run_wide:
            c.setFont(BODY_FONT, han_size)
            for ch in run:
                c.drawString(xx, y, ch)
                xx += 2 * cell
        else:
            c.setFont(MONO_FONT, size)
            c.drawString(xx, y, "".join(run))
            xx += cell * len(run)
        run.clear()
        return xx

    for ch in text:
        w = _is_wide(ch)
        if run and w != run_wide:
            x = flush(x)
        run_wide = w
        run.append(ch)
    return flush(x)


def shrink(text: str, font: str, size: float, max_width: float) -> str:
    """Truncate with an ellipsis so a single cell never overruns its column."""
    if pdfmetrics.stringWidth(text, font, size) <= max_width:
        return text
    ell = "..."
    budget = max_width - pdfmetrics.stringWidth(ell, font, size)
    out = ""
    for ch in text:
        if pdfmetrics.stringWidth(out + ch, font, size) > budget:
            break
        out += ch
    return out + ell


# --------------------------------------------------------------------------
# block measurement / rendering
#
# Every block is a dict with a "t" key.  measure() returns the height the block
# needs at a given width; draw() paints it with its top-left at (x, y_top).
# --------------------------------------------------------------------------

def _rule_h(_b: dict, _w: float) -> float:
    return 11.0


def _gap_h(b: dict, _w: float) -> float:
    return float(b.get("h", 8))


def _h2_h(b: dict, w: float) -> float:
    return 6 + len(wrap(b["text"], BOLD_FONT, 13, w)) * 17 + 7


def _h3_h(b: dict, w: float) -> float:
    return 4 + len(wrap(b["text"], BOLD_FONT, 10.4, w)) * 14 + 4


def _p_h(b: dict, w: float) -> float:
    size = b.get("size", BODY_SIZE)
    lead = b.get("lead", BODY_LEAD)
    return len(wrap(b["text"], b.get("font", BODY_FONT), size, w)) * lead + 5


def _ul_h(b: dict, w: float) -> float:
    total = 3.0
    for item in b["items"]:
        total += len(wrap(item, BODY_FONT, BODY_SIZE, w - 13)) * BODY_LEAD + 3.5
    return total + 3


def _ol_h(b: dict, w: float) -> float:
    total = 3.0
    for item in b["items"]:
        total += len(wrap(item, BODY_FONT, BODY_SIZE, w - 20)) * BODY_LEAD + 3.5
    return total + 3


def _code_h(b: dict, _w: float) -> float:
    n = len(b["lines"])
    head = 20 if b.get("title") else 6
    return head + n * CODE_LEAD + 10


def _note_h(b: dict, w: float) -> float:
    inner = w - 22
    h = 10.0
    if b.get("title"):
        h += 14
    h += len(wrap(b["text"], BODY_FONT, 8.9, inner)) * 12.6
    return h + 10


def _table_h(b: dict, w: float) -> float:
    cols = _col_widths(b, w)
    h = 20.0  # header
    for row in b["rows"]:
        rh = 0.0
        for cell, cw in zip(row, cols):
            rh = max(rh, len(wrap(str(cell), BODY_FONT, 8.4, cw - 10)) * 11.8)
        h += rh + 8
    return h + 6


def _art_h(b: dict, _w: float) -> float:
    return len(b["lines"]) * 9.6 + 16


def _quiz_h(b: dict, w: float) -> float:
    inner = w - 20
    h = 14.0
    h += len(wrap(b["q"], BOLD_FONT, 9.0, inner)) * 12.6 + 4
    for opt in b.get("options", []):
        h += len(wrap(opt, BODY_FONT, 8.6, inner - 12)) * 12.0 + 2
    h += len(wrap("답 " + b["a"], BODY_FONT, 8.6, inner)) * 12.0 + 6
    return h + 8


def _kv_h(b: dict, w: float) -> float:
    kw = b.get("kw", 92)
    h = 3.0
    for _k, v in b["rows"]:
        h += max(12.4, len(wrap(str(v), BODY_FONT, 8.6, w - kw - 8)) * 12.4) + 4
    return h + 3


MEASURE: dict[str, Callable[[dict, float], float]] = {
    "rule": _rule_h,
    "gap": _gap_h,
    "h2": _h2_h,
    "h3": _h3_h,
    "p": _p_h,
    "ul": _ul_h,
    "ol": _ol_h,
    "code": _code_h,
    "note": _note_h,
    "table": _table_h,
    "art": _art_h,
    "quiz": _quiz_h,
    "kv": _kv_h,
}


def _col_widths(b: dict, w: float) -> list[float]:
    weights = b.get("weights")
    n = len(b["head"])
    if not weights:
        weights = [1.0] * n
    total = sum(weights)
    return [w * x / total for x in weights]


NOTE_STYLE = {
    "info": (PALE_BLUE, BLUE),
    "tip": (PALE_GREEN, GREEN),
    "warn": (PALE_ORANGE, ORANGE),
    "trap": (PALE_RED, RED),
    "key": (PALE_PURPLE, PURPLE),
    "lab": (PALE_TEAL, TEAL),
}


class Renderer:
    def __init__(self, c: canvas.Canvas):
        self.c = c

    def draw(self, b: dict, x: float, y_top: float, w: float) -> None:
        getattr(self, "_d_" + b["t"])(b, x, y_top, w)

    # -- simple blocks ----------------------------------------------------
    def _d_gap(self, b, x, y, w) -> None:
        return

    def _d_rule(self, b, x, y, w) -> None:
        c = self.c
        c.setStrokeColor(FAINT)
        c.setLineWidth(0.8)
        c.line(x, y - 6, x + w, y - 6)

    def _d_h2(self, b, x, y, w) -> None:
        c = self.c
        color = b.get("color", NAVY)
        c.setFillColor(color)
        c.roundRect(x, y - 6 - 14, 3.2, 14, 1.6, stroke=0, fill=1)
        c.setFont(BOLD_FONT, 13)
        yy = y - 6 - 11
        for ln in wrap(b["text"], BOLD_FONT, 13, w - 10):
            c.drawString(x + 10, yy, ln)
            yy -= 17

    def _d_h3(self, b, x, y, w) -> None:
        c = self.c
        c.setFillColor(b.get("color", BLUE))
        c.setFont(BOLD_FONT, 10.4)
        yy = y - 4 - 9
        for ln in wrap(b["text"], BOLD_FONT, 10.4, w):
            c.drawString(x, yy, ln)
            yy -= 14

    def _d_p(self, b, x, y, w) -> None:
        c = self.c
        size = b.get("size", BODY_SIZE)
        lead = b.get("lead", BODY_LEAD)
        font = b.get("font", BODY_FONT)
        c.setFillColor(b.get("color", INK))
        c.setFont(font, size)
        yy = y - size - 1
        for ln in wrap(b["text"], font, size, w):
            c.drawString(x, yy, ln)
            yy -= lead

    def _d_ul(self, b, x, y, w) -> None:
        c = self.c
        color = b.get("color", BLUE)
        yy = y - 3
        for item in b["items"]:
            c.setFillColor(color)
            c.circle(x + 3.2, yy - 5.2, 2.2, stroke=0, fill=1)
            c.setFillColor(INK)
            c.setFont(BODY_FONT, BODY_SIZE)
            ty = yy - BODY_SIZE - 1
            lines = wrap(item, BODY_FONT, BODY_SIZE, w - 13)
            for ln in lines:
                c.drawString(x + 13, ty, ln)
                ty -= BODY_LEAD
            yy -= len(lines) * BODY_LEAD + 3.5

    def _d_ol(self, b, x, y, w) -> None:
        c = self.c
        color = b.get("color", BLUE)
        yy = y - 3
        for i, item in enumerate(b["items"], 1):
            c.setFillColor(color)
            c.circle(x + 5.4, yy - 5.4, 5.4, stroke=0, fill=1)
            c.setFillColor(white)
            c.setFont(BOLD_FONT, 6.6)
            c.drawCentredString(x + 5.4, yy - 7.7, str(i))
            c.setFillColor(INK)
            c.setFont(BODY_FONT, BODY_SIZE)
            ty = yy - BODY_SIZE - 1
            lines = wrap(item, BODY_FONT, BODY_SIZE, w - 20)
            for ln in lines:
                c.drawString(x + 20, ty, ln)
                ty -= BODY_LEAD
            yy -= len(lines) * BODY_LEAD + 3.5

    def _d_code(self, b, x, y, w) -> None:
        c = self.c
        h = _code_h(b, w)
        c.setFillColor(CODE_BG)
        c.setStrokeColor(CODE_BG)
        c.roundRect(x, y - h, w, h, 5, stroke=1, fill=1)
        top = y
        if b.get("title"):
            c.setFillColor(HexColor("#1E2A3D"))
            c.roundRect(x, y - 20, w, 20, 5, stroke=0, fill=1)
            c.rect(x, y - 20, w, 10, stroke=0, fill=1)
            c.setFillColor(HexColor("#C8D6E4"))
            c.setFont(MONO_BOLD, 7.0)
            c.drawString(x + 8, y - 13.5, b["title"])
            top = y - 20
        hl = set(b.get("hl", ()))
        num = b.get("num", False)
        start = int(b.get("start", 1))
        yy = top - 6 - CODE_SIZE
        for i, src in enumerate(b["lines"]):
            lineno = start + i
            if lineno in hl or src in hl:
                c.setFillColor(CODE_HL)
                c.roundRect(x + 4, yy - 2.4, w - 8, CODE_LEAD, 2, stroke=0, fill=1)
            tx = x + 8
            if num:
                c.setFillColor(CODE_MUTED)
                c.setFont(MONO_FONT, CODE_SIZE)
                c.drawRightString(x + 24, yy, str(lineno))
                tx = x + 30
            c.setFillColor(HexColor(b["fg"][i]) if b.get("fg") else CODE_FG)
            draw_mono(c, tx, yy, mono_shrink(src, CODE_SIZE, w - (tx - x) - 8), CODE_SIZE)
            yy -= CODE_LEAD

    def _d_note(self, b, x, y, w) -> None:
        c = self.c
        fill, edge = NOTE_STYLE[b.get("kind", "info")]
        h = _note_h(b, w)
        c.setFillColor(fill)
        c.setStrokeColor(fill)
        c.roundRect(x, y - h, w, h, 5, stroke=1, fill=1)
        c.setFillColor(edge)
        c.roundRect(x, y - h, 3.0, h, 1.5, stroke=0, fill=1)
        yy = y - 12
        if b.get("title"):
            c.setFillColor(edge)
            c.setFont(BOLD_FONT, 8.9)
            c.drawString(x + 12, yy - 1, b["title"])
            yy -= 14
        c.setFillColor(INK)
        c.setFont(BODY_FONT, 8.9)
        for ln in wrap(b["text"], BODY_FONT, 8.9, w - 22):
            c.drawString(x + 12, yy - 1, ln)
            yy -= 12.6

    def _d_table(self, b, x, y, w) -> None:
        c = self.c
        cols = _col_widths(b, w)
        accent = b.get("color", NAVY)
        c.setFillColor(accent)
        c.roundRect(x, y - 20, w, 20, 3, stroke=0, fill=1)
        c.setFillColor(white)
        c.setFont(BOLD_FONT, 8.4)
        cx = x
        for head, cw in zip(b["head"], cols):
            c.drawString(cx + 5, y - 13.2, shrink(str(head), BOLD_FONT, 8.4, cw - 10))
            cx += cw
        yy = y - 20
        for r, row in enumerate(b["rows"]):
            rh = 0.0
            for cell, cw in zip(row, cols):
                rh = max(rh, len(wrap(str(cell), BODY_FONT, 8.4, cw - 10)) * 11.8)
            rh += 8
            if r % 2 == 0:
                c.setFillColor(HexColor("#F1F5F9"))
                c.rect(x, yy - rh, w, rh, stroke=0, fill=1)
            cx = x
            for cell, cw in zip(row, cols):
                c.setFillColor(INK)
                c.setFont(BODY_FONT, 8.4)
                ty = yy - 12
                for ln in wrap(str(cell), BODY_FONT, 8.4, cw - 10):
                    c.drawString(cx + 5, ty, ln)
                    ty -= 11.8
                cx += cw
            yy -= rh
            c.setStrokeColor(FAINT)
            c.setLineWidth(0.5)
            c.line(x, yy, x + w, yy)

    def _d_art(self, b, x, y, w) -> None:
        c = self.c
        h = _art_h(b, w)
        c.setFillColor(b.get("bg", HexColor("#F2F5F9")))
        c.setStrokeColor(LINE)
        c.setLineWidth(0.7)
        c.roundRect(x, y - h, w, h, 4, stroke=1, fill=1)
        c.setFillColor(b.get("color", HexColor("#1F3350")))
        size = b.get("size", 6.5)
        yy = y - 12
        for ln in b["lines"]:
            draw_mono(c, x + 8, yy, mono_shrink(ln, size, w - 16), size)
            yy -= 9.6

    def _d_quiz(self, b, x, y, w) -> None:
        c = self.c
        h = _quiz_h(b, w)
        c.setFillColor(HexColor("#FFFDF5"))
        c.setStrokeColor(ORANGE)
        c.setLineWidth(0.9)
        c.roundRect(x, y - h, w, h, 5, stroke=1, fill=1)
        yy = y - 13
        c.setFillColor(ORANGE)
        c.setFont(BOLD_FONT, 9.0)
        for ln in wrap(b["q"], BOLD_FONT, 9.0, w - 20):
            c.drawString(x + 10, yy, ln)
            yy -= 12.6
        yy -= 4
        c.setFillColor(INK)
        for opt in b.get("options", []):
            c.setFont(BODY_FONT, 8.6)
            for ln in wrap(opt, BODY_FONT, 8.6, w - 32):
                c.drawString(x + 20, yy, ln)
                yy -= 12.0
            yy -= 2
        c.setFillColor(GREEN)
        c.setFont(BOLD_FONT, 8.6)
        for ln in wrap("답 " + b["a"], BODY_FONT, 8.6, w - 20):
            c.drawString(x + 10, yy, ln)
            yy -= 12.0

    def _d_kv(self, b, x, y, w) -> None:
        c = self.c
        kw = b.get("kw", 92)
        yy = y - 3
        for k, v in b["rows"]:
            c.setFillColor(b.get("color", TEAL))
            c.setFont(BOLD_FONT, 8.6)
            c.drawString(x, yy - 9, shrink(str(k), BOLD_FONT, 8.6, kw - 6))
            c.setFillColor(INK)
            c.setFont(BODY_FONT, 8.6)
            ty = yy - 9
            lines = wrap(str(v), BODY_FONT, 8.6, w - kw - 8)
            for ln in lines:
                c.drawString(x + kw, ty, ln)
                ty -= 12.4
            yy -= max(12.4, len(lines) * 12.4) + 4


# --------------------------------------------------------------------------
# document assembly
# --------------------------------------------------------------------------

class Document:
    def __init__(self, path: Path, title: str, subtitle: str):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self.title = title
        self.subtitle = subtitle
        self.c = canvas.Canvas(str(path), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
        self.c.setTitle(title)
        self.c.setAuthor("SystemVerilog 심화 과정")
        self.r = Renderer(self.c)
        self.page = 0
        self.toc: list[tuple[int, str, int]] = []   # (level, text, page)
        self.part = ""
        self.chapter = ""
        self._col = 0
        self._y = 0.0
        self._open = False

    # -- page frame -------------------------------------------------------
    def _frame(self) -> None:
        c = self.c
        c.setFillColor(PAPER)
        c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        c.setFillColor(MUTED)
        c.setFont(BODY_FONT, 7.6)
        if self.chapter:
            c.drawString(MARGIN_X, PAGE_H - 30, self.chapter)
        c.drawRightString(PAGE_W - MARGIN_X, PAGE_H - 30, self.part)
        c.setStrokeColor(LINE)
        c.setLineWidth(0.7)
        c.line(MARGIN_X, PAGE_H - 40, PAGE_W - MARGIN_X, PAGE_H - 40)
        c.line(MARGIN_X, MARGIN_BOT - 12, PAGE_W - MARGIN_X, MARGIN_BOT - 12)
        c.setFillColor(MUTED)
        c.setFont(BODY_FONT, 7.4)
        c.drawString(MARGIN_X, MARGIN_BOT - 24, self.title)
        c.setFillColor(NAVY)
        c.setFont(BOLD_FONT, 8.4)
        c.drawRightString(PAGE_W - MARGIN_X, MARGIN_BOT - 24, str(self.page))
        # faint centre rule between columns
        c.setStrokeColor(HexColor("#EDF1F6"))
        c.setLineWidth(0.7)
        mid = MARGIN_X + COL_W + COL_GAP / 2
        c.line(mid, MARGIN_BOT, mid, PAGE_H - MARGIN_TOP)

    def _new_page(self) -> None:
        if self._open:
            self.c.showPage()
        self.page += 1
        self._frame()
        self._col = 0
        self._y = PAGE_H - MARGIN_TOP
        self._open = True

    def _col_x(self) -> float:
        return MARGIN_X + self._col * (COL_W + COL_GAP)

    def _advance(self, need: float) -> None:
        if self._y - need >= MARGIN_BOT:
            return
        if self._col == 0:
            self._col = 1
            self._y = PAGE_H - MARGIN_TOP
        else:
            self._new_page()

    # -- public API -------------------------------------------------------
    def cover(self, lines: Sequence[str], meta: Sequence[str]) -> None:
        c = self.c
        if self._open:
            c.showPage()
        self.page += 1
        self._open = True
        c.setFillColor(NAVY)
        c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        c.setFillColor(BLUE)
        c.rect(0, PAGE_H - 8, PAGE_W, 8, stroke=0, fill=1)
        c.setFillColor(HexColor("#7DA7F0"))
        c.setFont(BOLD_FONT, 11)
        c.drawString(MARGIN_X + 16, PAGE_H - 92, self.subtitle)
        c.setFillColor(white)
        y = PAGE_H - 150
        for ln in lines:
            c.setFont(BOLD_FONT, 34)
            c.drawString(MARGIN_X + 16, y, ln)
            y -= 46
        c.setStrokeColor(HexColor("#33507C"))
        c.setLineWidth(1.2)
        c.line(MARGIN_X + 16, y + 12, MARGIN_X + 320, y + 12)
        c.setFillColor(HexColor("#AFC6E8"))
        y -= 22
        for m in meta:
            c.setFont(BODY_FONT, 10)
            c.drawString(MARGIN_X + 16, y, m)
            y -= 17
        # park the cursor past the last column so the next add() opens a page
        self._col = 1
        self._y = MARGIN_BOT

    def part_page(self, number: str, title: str, blurb: str, items: Sequence[str]) -> None:
        c = self.c
        if self._open:
            c.showPage()
        self.page += 1
        self._open = True
        self.part = title
        self.chapter = ""
        c.setFillColor(HexColor("#16324F"))
        c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        c.setFillColor(HexColor("#6EA8FF"))
        c.setFont(BOLD_FONT, 13)
        c.drawString(MARGIN_X + 16, PAGE_H - 120, number)
        c.setFillColor(white)
        c.setFont(BOLD_FONT, 30)
        y = PAGE_H - 162
        for ln in wrap(title, BOLD_FONT, 30, PAGE_W - 2 * MARGIN_X - 32):
            c.drawString(MARGIN_X + 16, y, ln)
            y -= 38
        c.setFillColor(HexColor("#B8CDE8"))
        c.setFont(BODY_FONT, 10.5)
        y -= 8
        for ln in wrap(blurb, BODY_FONT, 10.5, 560):
            c.drawString(MARGIN_X + 16, y, ln)
            y -= 15
        y -= 14
        c.setFillColor(HexColor("#8FB2DC"))
        for it in items:
            c.setFont(BODY_FONT, 9.4)
            c.drawString(MARGIN_X + 24, y, "· " + it)
            y -= 14
        self.toc.append((0, f"{number}  {title}", self.page))
        # park the cursor past the last column so the next add() opens a page
        self._col = 1
        self._y = MARGIN_BOT

    def chapter_start(self, number: str, title: str, goals: Sequence[str]) -> None:
        """Open a chapter: always begins a fresh page with a banner."""
        self.chapter = f"{number}  {title}"
        self._new_page()
        self.toc.append((1, f"{number}  {title}", self.page))
        c = self.c
        top = PAGE_H - MARGIN_TOP
        bh = 62.0
        c.setFillColor(HexColor("#EDF3FC"))
        c.setStrokeColor(HexColor("#D5E2F5"))
        c.setLineWidth(0.9)
        c.roundRect(MARGIN_X, top - bh, PAGE_W - 2 * MARGIN_X, bh, 7, stroke=1, fill=1)
        c.setFillColor(BLUE)
        c.roundRect(MARGIN_X, top - bh, 4, bh, 2, stroke=0, fill=1)
        c.setFillColor(BLUE)
        c.setFont(BOLD_FONT, 9.6)
        c.drawString(MARGIN_X + 16, top - 20, number)
        c.setFillColor(NAVY)
        c.setFont(BOLD_FONT, 19)
        c.drawString(MARGIN_X + 16, top - 42, shrink(title, BOLD_FONT, 19, 470))
        c.setFillColor(MUTED)
        c.setFont(BOLD_FONT, 7.8)
        gx = MARGIN_X + 500
        c.drawString(gx, top - 18, "학습 목표")
        c.setFont(BODY_FONT, 8.0)
        c.setFillColor(INK)
        gy = top - 31
        for g in goals[:4]:
            c.drawString(gx, gy, shrink("· " + g, BODY_FONT, 8.0, PAGE_W - MARGIN_X - gx - 8))
            gy -= 11
        self._y = top - bh - 16

    def add(self, blocks: Sequence[dict]) -> None:
        for i, b in enumerate(blocks):
            self._place(b, blocks[i + 1] if i + 1 < len(blocks) else None)

    def _place(self, b: dict, nxt: dict | None = None) -> None:
        w = COL_W
        h = MEASURE[b["t"]](b, w)
        # keep-with-next: a heading never sits alone at the foot of a column.
        # The lookahead has to cover a decent slice of a code block or table,
        # otherwise a heading still strands itself above one that cannot fit.
        if b["t"] in ("h2", "h3") and nxt is not None:
            follow = min(MEASURE[nxt["t"]](nxt, w), 110.0)
            if self._y - (h + follow) < MARGIN_BOT:
                self._advance(h + follow)
        # A block taller than a full column is split only for code/table;
        # everything else is pushed to a fresh column.
        col_h = PAGE_H - MARGIN_TOP - MARGIN_BOT
        if h > col_h and b["t"] == "code":
            for part in _split_code(b, col_h):
                self._place(part)
            return
        if h > col_h and b["t"] == "table":
            for part in _split_table(b, col_h, w):
                self._place(part)
            return
        self._advance(h)
        self.r.draw(b, self._col_x(), self._y, w)
        self._y -= h

    # -- table of contents ------------------------------------------------
    #
    # The TOC sits right after the cover, so emitting it shifts every later
    # page by a fixed amount.  The caller therefore builds twice: pass 1
    # collects entries, toc_page_count() says how many pages they need, and
    # pass 2 re-runs with the entries offset by that count.
    TOC_ROWS_PER_COL = 30

    @classmethod
    def toc_page_count(cls, entries: Sequence[tuple[int, str, int]]) -> int:
        per_page = cls.TOC_ROWS_PER_COL * 2
        return max(1, -(-len(entries) // per_page))

    def toc_pages(self, entries: Sequence[tuple[int, str, int]], offset: int) -> None:
        pages = self.toc_page_count(entries)
        self.part = "목차"
        self.chapter = "Contents"
        rows = list(entries)
        idx = 0
        for _ in range(pages):
            self._new_page()
            c = self.c
            c.setFillColor(NAVY)
            c.setFont(BOLD_FONT, 17)
            c.drawString(MARGIN_X, PAGE_H - MARGIN_TOP - 14, "목  차")
            top0 = PAGE_H - MARGIN_TOP - 40
            for col in range(2):
                x = MARGIN_X + col * (COL_W + COL_GAP)
                y = top0
                for _ in range(self.TOC_ROWS_PER_COL):
                    if idx >= len(rows):
                        break
                    level, text, page = rows[idx]
                    idx += 1
                    shown = page + offset
                    if level == 0:
                        y -= 6
                        c.setFillColor(BLUE)
                        c.setFont(BOLD_FONT, 9.0)
                        c.drawString(x, y, shrink(text, BOLD_FONT, 9.0, COL_W - 34))
                        c.drawRightString(x + COL_W, y, str(shown))
                        y -= 15
                    else:
                        c.setFillColor(INK)
                        c.setFont(BODY_FONT, 8.6)
                        label = shrink(text, BODY_FONT, 8.6, COL_W - 34)
                        c.drawString(x + 10, y, label)
                        c.setFillColor(MUTED)
                        c.setFont(BODY_FONT, 8.0)
                        c.drawRightString(x + COL_W, y, str(shown))
                        lw = pdfmetrics.stringWidth(label, BODY_FONT, 8.6)
                        c.setStrokeColor(HexColor("#DCE3EC"))
                        c.setLineWidth(0.5)
                        c.setDash(1, 2.4)
                        c.line(x + 14 + lw, y + 2, x + COL_W - 18, y + 2)
                        c.setDash()
                        y -= 13.4
        self._col = 1
        self._y = MARGIN_BOT

    def save(self) -> Path:
        if self._open:
            self.c.showPage()
        self.c.save()
        return self.path


def _split_code(b: dict, col_h: float) -> list[dict]:
    head = 20 if b.get("title") else 6
    per = int((col_h - head - 10) // CODE_LEAD)
    out = []
    lines = b["lines"]
    start = int(b.get("start", 1))
    for i in range(0, len(lines), per):
        chunk = dict(b)
        chunk["lines"] = lines[i : i + per]
        chunk["start"] = start + i
        if i:
            chunk["title"] = (b.get("title") or "") + "  (계속)"
        out.append(chunk)
    return out


def _split_table(b: dict, col_h: float, w: float) -> list[dict]:
    out: list[dict] = []
    cur: list[Any] = []
    h = 26.0
    for row in b["rows"]:
        cols = _col_widths(b, w)
        rh = 0.0
        for cell, cw in zip(row, cols):
            rh = max(rh, len(wrap(str(cell), BODY_FONT, 8.4, cw - 10)) * 11.8)
        rh += 8
        if h + rh > col_h and cur:
            part = dict(b)
            part["rows"] = cur
            out.append(part)
            cur = []
            h = 26.0
        cur.append(row)
        h += rh
    if cur:
        part = dict(b)
        part["rows"] = cur
        out.append(part)
    return out
