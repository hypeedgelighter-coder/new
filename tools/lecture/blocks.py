"""Terse constructors for the content blocks the engine renders.

Chapters are written as flat lists of these, e.g.

    [h2("팩토리"), p("..."), code("seq_item.sv", CODE), note("함정", "...", "trap")]
"""

from __future__ import annotations

from typing import Sequence


def h2(text: str, **kw) -> dict:
    return {"t": "h2", "text": text, **kw}


def h3(text: str, **kw) -> dict:
    return {"t": "h3", "text": text, **kw}


def p(text: str, **kw) -> dict:
    return {"t": "p", "text": text, **kw}


def lead(text: str, **kw) -> dict:
    """Slightly larger opening paragraph."""
    return {"t": "p", "text": text, "size": 10.0, "lead": 14.6, **kw}


def small(text: str, **kw) -> dict:
    return {"t": "p", "text": text, "size": 8.4, "lead": 11.8, **kw}


def ul(*items: str, **kw) -> dict:
    return {"t": "ul", "items": list(items), **kw}


def ol(*items: str, **kw) -> dict:
    return {"t": "ol", "items": list(items), **kw}


def code(title: str | None, src: str, *, num: bool = False, hl: Sequence[int] = (), **kw) -> dict:
    lines = src.split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return {"t": "code", "title": title, "lines": lines, "num": num, "hl": list(hl), **kw}


def art(src: str, **kw) -> dict:
    lines = src.split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return {"t": "art", "lines": lines, **kw}


def note(title: str, text: str, kind: str = "info") -> dict:
    return {"t": "note", "title": title, "text": text, "kind": kind}


def trap(title: str, text: str) -> dict:
    return {"t": "note", "title": title, "text": text, "kind": "trap"}


def tip(title: str, text: str) -> dict:
    return {"t": "note", "title": title, "text": text, "kind": "tip"}


def key(title: str, text: str) -> dict:
    return {"t": "note", "title": title, "text": text, "kind": "key"}


def warn(title: str, text: str) -> dict:
    return {"t": "note", "title": title, "text": text, "kind": "warn"}


def lab(title: str, text: str) -> dict:
    return {"t": "note", "title": title, "text": text, "kind": "lab"}


def table(head: Sequence[str], rows: Sequence[Sequence[str]], weights: Sequence[float] | None = None, **kw) -> dict:
    return {"t": "table", "head": list(head), "rows": [list(r) for r in rows],
            "weights": list(weights) if weights else None, **kw}


def kv(rows: Sequence[tuple[str, str]], kw_width: float = 92, **kwargs) -> dict:
    return {"t": "kv", "rows": [tuple(r) for r in rows], "kw": kw_width, **kwargs}


def quiz(q: str, options: Sequence[str], a: str) -> dict:
    return {"t": "quiz", "q": q, "options": list(options), "a": a}


def rule() -> dict:
    return {"t": "rule"}


def gap(h: float = 8) -> dict:
    return {"t": "gap", "h": h}
