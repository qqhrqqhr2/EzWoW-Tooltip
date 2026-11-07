#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Tooltip (docs/images/ui_*.png, settings_*.png).

The tooltip cards and the settings window are rebuilt from the sizes, coordinates,
colours and strings in the addon code (UI/OptionsWindow.lua layout, Theme, option texts
and owner notes, Data/Defaults.lua, Core/Locales.lua tooltip line texts), in game
pixels x scale. The 3D model and icons are simplified drawings; every name is made up.

usage: python scripts/make_readme_images.py .
Renders with a local headless Chrome (set CHROME=<path> if it is not found).
"""
import base64
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PAGE_W = 1600

# ---------------------------------------------------------------------------
# Small readers for the Lua code
# ---------------------------------------------------------------------------


def read(root, rel):
    return (root / rel).read_text(encoding="utf-8")


def find_file(root, *names):
    """First existing file of names (case-insensitive on every system)."""
    for name in names:
        p = root / name
        if p.exists():
            return p
        parent = p.parent
        if parent.exists():
            for q in parent.iterdir():
                if q.name.lower() == p.name.lower():
                    return q
    raise FileNotFoundError(names)


def rgb_list(body):
    return [float(v) for v in body.split(",") if v.strip()]


def lua_table(src, start_pattern):
    """Text of the Lua table that starts at start_pattern (balanced braces)."""
    m = re.search(start_pattern, src)
    if not m:
        raise ValueError(start_pattern)
    i = src.index("{", m.start())
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
    raise ValueError("unbalanced " + start_pattern)


def lua_strings(block):
    """key = "value" pairs of a Lua table body (plain keys and ["keys"])."""
    out = {}
    for k1, k2, v in re.findall(r'(?:^|[\s,{])(?:(\w+)|\["((?:[^"\\]|\\.)*)"\])\s*=\s*"((?:[^"\\]|\\.)*)"', block, re.M):
        out[k1 or k2] = unlua(v)
    return out


def unlua(v):
    return v.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def toc_version(root):
    for p in root.glob("*.toc"):
        m = re.search(r"^## Version:\s*(\S+)", p.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    return ""


def css(c, alpha=None, mul=1.0):
    r, g, b = (round(min(1, v * mul) * 255) for v in c[:3])
    a = alpha if alpha is not None else (c[3] if len(c) > 3 else 1)
    return f"rgba({r},{g},{b},{a:.2f})"


def hexc(c):
    return "#%02x%02x%02x" % tuple(round(v * 255) for v in c[:3])


def esc(s):
    return html.escape(str(s), quote=False)


def wow(s):
    """Game text -> HTML: |cffRRGGBB..|r colours, |n / \\n line breaks, icons dropped."""
    s = esc(s)
    s = re.sub(r"\|T[^|]*\|t", "", s)
    s = re.sub(r"\|A[^|]*\|a", "", s)
    out, depth = [], 0
    pos = 0
    for m in re.finditer(r"\|c[0-9a-fA-F]{2}([0-9a-fA-F]{6})|\|r", s):
        out.append(s[pos:m.start()])
        if m.group(0) == "|r":
            if depth:
                out.append("</span>")
                depth -= 1
        else:
            out.append(f'<span style="color:#{m.group(1)}">')
            depth += 1
        pos = m.end()
    out.append(s[pos:])
    out.append("</span>" * depth)
    return "".join(out).replace("|n", "<br>").replace("\n", "<br>")


# ---------------------------------------------------------------------------
# Page parts (game px x S -> page px)
# ---------------------------------------------------------------------------
S = 1.3


def px(v):
    return f"{v * S:.2f}px"


OUTLINE = "text-shadow:-1px 0 #000,1px 0 #000,0 -1px #000,0 1px #000,0 0 2px #000;"
SHADOW = "text-shadow:1px 1px 0 #000,0 0 2px rgba(0,0,0,.8);"

# client colours used by several mock-ups
QUALITY = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee", 5: "#ff8000"}
CLASS_HEX = {"WARRIOR": "#c69b6d", "PALADIN": "#f48cba", "HUNTER": "#aad372", "ROGUE": "#fff468", "PRIEST": "#ffffff",
             "SHAMAN": "#0070dd", "MAGE": "#3fc7eb", "WARLOCK": "#8788ee", "DRUID": "#ff7c0a"}
GOLD = "#ffd100"

THEME = {
    "bg": (0.071, 0.094, 0.122, 0.97), "bgSub": (0.114, 0.157, 0.192, 0.96), "border": (0.204, 0.298, 0.357, 1),
    "text": (0.929, 0.957, 0.969, 1), "muted": (0.655, 0.725, 0.773, 1), "accent": (0.5, 0.8, 0.9, 1),
}


def page_css(call):
    return f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: {PAGE_W}px; overflow: hidden; }}
body {{ background: #0e141a; font-family: 'Noto Sans KR','Malgun Gothic',sans-serif; color: #edf4f7; position: relative; }}
.sky {{ position: absolute; left: 0; top: 0; width: {PAGE_W}px; height: 100%;
  background: radial-gradient(ellipse at 25% 0%, #1d2b38 0%, #151f28 45%, #10171d 75%, #0c1115 100%); }}
.hills {{ position: absolute; left: 0; bottom: 0; width: {PAGE_W}px; height: 260px; }}
.page {{ position: relative; padding: 34px 50px 0; }}
h1 {{ color: {call}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }}
h1 .badge {{ font-size: 15px; background: {call}; color: #10161c; padding: 2px 9px; border-radius: 5px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.abs {{ position: absolute; }}
.t {{ position: absolute; white-space: nowrap; line-height: 1.15; }}
.call {{ position: absolute; width: 30px; height: 30px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #10161c; box-shadow: 0 0 0 2px {call}55; z-index: 60; }}
.notes {{ position: absolute; }}
.note {{ display: flex; gap: 12px; margin-bottom: 11px; font-size: 16px; line-height: 1.5; color: #dfe6ea; }}
.note .n {{ flex: none; width: 28px; height: 28px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; }}
.note b {{ color: #fff; }}
.foot {{ position: absolute; color: #7d8d98; font-size: 13.5px; line-height: 1.5; }}
.fit {{ display: inline-block; white-space: nowrap; }}
.tip {{ position: absolute; z-index: 30; }}
.tip .row {{ display: flex; justify-content: space-between; gap: 18px; white-space: nowrap; }}
"""


HILLS = ('<svg class="hills" viewBox="0 0 1600 260" preserveAspectRatio="none">'
         '<path d="M0 150 C 220 70 420 90 640 140 C 860 190 1060 60 1300 80 C 1440 92 1540 120 1600 130 V260 H0 Z" fill="#141c23" opacity=".9"/>'
         '<path d="M0 210 C 260 160 520 170 800 205 C 1080 240 1340 170 1600 190 V260 H0 Z" fill="#0b1014"/></svg>')

FIT_JS = """
<script>
document.querySelectorAll('[data-fit]').forEach(function (e) {
  var max = parseFloat(e.dataset.fit), min = parseFloat(e.dataset.min || 8);
  var fs = parseFloat(getComputedStyle(e).fontSize);
  while (e.scrollWidth > max && fs > min) { fs -= 0.25; e.style.fontSize = fs + 'px'; }
  if (e.scrollWidth > max) { e.style.maxWidth = max + 'px'; e.style.overflow = 'hidden'; e.style.textOverflow = 'ellipsis'; }
});
// place the footnote under the lowest element, then record the page height
var bottom = 0;
document.querySelectorAll('.page *, body > .abs, body > .notes, body > .call, body > .tip').forEach(function (e) {
  var r = e.getBoundingClientRect(); if (r.height > 0 && r.bottom > bottom) bottom = r.bottom;
});
var foot = document.querySelector('.foot');
if (foot) { foot.style.top = (bottom + 26) + 'px'; bottom = foot.getBoundingClientRect().bottom; }
document.body.setAttribute('data-h', Math.ceil(bottom + 34));
document.body.style.height = Math.ceil(bottom + 34) + 'px';
</script>
"""


def box(x, y, w, h, style="", inner=""):
    return f'<div class="abs" style="left:{px(x)};top:{px(y)};width:{px(w)};height:{px(h)};{style}">{inner}</div>'


def text(x, y, s, size, color="#fff", anchor="left", style="", fit=None, shadow=SHADOW):
    """Font string; y is the vertical centre (game px)."""
    tr = {"left": "translate(0,-50%)", "right": "translate(-100%,-50%)", "center": "translate(-50%,-50%)"}[anchor]
    inner = s if fit is None else f'<span class="fit" data-fit="{fit * S:.1f}" data-min="{size * 0.7 * S:.1f}">{s}</span>'
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};'
            f'transform:{tr};{shadow}{style}">{inner}</div>')


def text_top(x, y, s, size, color="#fff", width=None, style="", shadow=SHADOW):
    """Font string anchored at its top-left (TOPLEFT points)."""
    w = f"width:{px(width)};white-space:normal;" if width else ""
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};line-height:1.3;'
            f'{w}{shadow}{style}">{s}</div>')


class Window:
    """A flat EzWoW style window: header strip, accent line, icon, title, sub title, close box."""

    def __init__(self, th, w, h, title, sub="", icon=None, header=56, close=22, close_off=10, title_color=None):
        self.th, self.w, self.h = th, w, h
        self.p = []
        acc = css(th["accent"], 1)
        if header:
            self.p.append(box(1, 1, w - 2, header, f"background:{css(th['bgSub'], .98)}"))
            self.p.append(box(1, header - 1, w - 2, 2, f"background:{acc}"))
            if icon:
                self.p.append(f'<img class="abs" src="{icon}" style="left:{px(14)};top:{px(14)};width:{px(28)};height:{px(28)}">')
            self.p.append(text_top(48, 10, esc(title), 16, title_color or acc))
            if sub:
                self.p.append(text_top(48, 32, sub, 10, css(th["muted"]), width=w - 120))
            if close:
                self.button(w - 1 - close_off - close, close_off + 1, close, close, "X", size=12)

    def add(self, s):
        self.p.append(s)

    def section(self, x, y, label, width=None, line_dy=18):
        acc = css(self.th["accent"], 1)
        self.p.append(text_top(x, y, label, 13, acc))
        w = width if width else self.w - x - 20
        self.p.append(box(x, y + line_dy, w, 1, f"background:{css(self.th['border'], .85)}"))

    def check(self, x, y, label, on, size=24, label_w=180, font=12, disabled=False, color=None):
        mark = (f'<div class="t" style="left:{px(size * 0.1)};top:{px(-size * 0.12)};font-size:{px(size * 0.9)};color:#ffd200;'
                f'text-shadow:0 0 1px #000,1px 1px 0 #6b4a00">&#10004;</div>') if on else ""
        b = size * 0.72
        o = (size - b) / 2
        alpha = ";opacity:.55" if disabled else ""
        self.p.append(box(x + o, y + o, b, b, f"border:1px solid #6d6a5d;background:#191919;border-radius:2px;overflow:visible{alpha}", mark))
        col = color or css(self.th["muted"] if disabled else self.th["text"])
        self.p.append(text(x + size + 4, y + size / 2, label, font, col, fit=label_w))

    def radio(self, x, y, label, on, size=22, label_w=150, font=12):
        dot = box(size * .32, size * .32, size * .36, size * .36, "border-radius:50%;background:#ffd200;box-shadow:0 0 3px #ffb000") if on else ""
        self.p.append(box(x + 2, y + 2, size - 4, size - 4, "border:1px solid #7a7a7a;border-radius:50%;background:#151515", dot))
        self.p.append(text(x + size + 4, y + size / 2, label, font, css(self.th["text"]), fit=label_w))

    def button(self, x, y, w, h, label, accent=False, size=12, color=None, bg=None, border=None):
        th = self.th
        bgc = bg or css(th["bgSub"])
        bd = border or (css(th["accent"]) if accent else css(th["border"]))
        col = color or (css(th["accent"]) if accent else css(th["text"]))
        self.p.append(box(x, y, w, h, f"background:{bgc};border:1px solid {bd};display:flex;align-items:center;justify-content:center",
                          f'<span class="fit" data-fit="{(w - 10) * S:.1f}" data-min="{size * .7 * S:.1f}" '
                          f'style="font-size:{px(size)};color:{col};{SHADOW}">{label}</span>'))

    def stepper(self, x, y, label, value, minus_dx, plus_dx, bw=25, bh=25, label_dy=6, label_w=84, value_color=None, font=12):
        self.p.append(text_top(x, y + label_dy, f'<span class="fit" data-fit="{label_w * S:.1f}" data-min="{9 * S:.1f}">{label}</span>',
                               font, css(self.th["text"])))
        self.button(x + minus_dx, y, bw, bh, "-", size=14)
        self.button(x + plus_dx, y, bw, bh, "+", size=14)
        cx = x + minus_dx + bw / 2 + (plus_dx - minus_dx) / 2
        self.p.append(text(cx, y + bh / 2, value, font, value_color or css(self.th["text"]), anchor="center"))

    def html(self, ox, oy, extra_style=""):
        th = self.th
        return (f'<div class="abs" style="left:{ox}px;top:{oy}px;width:{px(self.w)};height:{px(self.h)};background:{css(th["bg"])};'
                f'border:1px solid {css(th["border"])};box-shadow:0 10px 40px rgba(0,0,0,.45);{extra_style}">' + "".join(self.p) + "</div>")


def tooltip(x, y, lines, border="#344c5b", width=None, pad=10, bg="rgba(18,24,31,.95)", gloss=True, bar=None, font=12,
            title_size=14, left_pad=0, z=30, extra=""):
    """A tooltip card at page px (x, y). lines: list of str | (left, right) | ("gap",); first line is the title.
    Strings are already HTML. bar: (fraction, colour, label) drawn along the bottom."""
    rows = []
    for i, ln in enumerate(lines):
        fs = title_size if i == 0 else font
        if ln == ("gap",):
            rows.append(f'<div style="height:{px(font * .7)}"></div>')
        elif isinstance(ln, tuple):
            rows.append(f'<div class="row" style="font-size:{px(fs)};line-height:1.42"><span>{ln[0]}</span><span>{ln[1]}</span></div>')
        else:
            rows.append(f'<div style="font-size:{px(fs)};line-height:1.42;white-space:nowrap">{ln}</div>')
    w = f"width:{px(width)};" if width else ""
    glo = (f'<div class="abs" style="left:0;right:0;top:0;height:{px(26)};background:linear-gradient(to bottom,rgba(255,255,255,.07),'
           f'rgba(255,255,255,0))"></div>') if gloss else ""
    bar_h = ""
    bottom_pad = pad
    if bar:
        frac, col, label = bar
        bottom_pad = pad + 10
        bar_h = (f'<div class="abs" style="left:{px(1)};right:{px(1)};bottom:{px(1)};height:{px(8)};background:rgba(0,0,0,.6)">'
                 f'<div class="abs" style="left:0;top:0;bottom:0;width:{frac * 100:.1f}%;background:{col}"></div>'
                 f'<div class="abs" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:{px(7.5)};color:#fff;{OUTLINE}">{label}</div></div>')
    return (f'<div class="tip" style="left:{x:.0f}px;top:{y:.0f}px;{w}background:{bg};border:1px solid {border};'
            f'padding:{px(pad)} {px(pad)} {px(bottom_pad)} {px(pad + left_pad)};{SHADOW}z-index:{z};{extra}">'
            f'{glo}{"".join(rows)}{bar_h}</div>')


def callouts(points):
    return "".join(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>' for i, (x, y) in enumerate(points, 1))


def notes_html(notes, start=1):
    return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{esc(a)}</b> — {b}</div></div>'
                   for i, (a, b) in enumerate(notes))


def notes_block(x, y, w, notes, start=1):
    return f'<div class="notes" style="left:{x:.0f}px;top:{y:.0f}px;width:{w:.0f}px">{notes_html(notes, start)}</div>'


def heading(title, lead, badge=None):
    b = f' <span class="badge">{esc(badge)}</span>' if badge else ""
    return f'<div class="page"><h1>{esc(title)}{b}</h1><div class="lead">{lead}</div></div>'


def icon_data(path):
    return "data:image/png;base64," + base64.b64encode(Path(path).read_bytes()).decode()


# simple square icon art (stands in for game icons)
ICON_ART = {
    "potion": ("#3a1418", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#d8323c"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "mana": ("#121e3e", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#3d7cf0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "elixir": ("#14301e", '<path d="M44 12 H56 V40 L74 80 H26 L44 40 Z" fill="#5fd05a"/><rect x="40" y="8" width="20" height="8" fill="#b08860"/>'),
    "stone": ("#1c2a1c", '<path d="M50 12 L80 40 L62 86 H38 L20 40 Z" fill="#62e07a"/><path d="M50 12 L62 40 L50 86 L38 40 Z" fill="#a8f5b4"/>'),
    "helm": ("#2a2a30", '<path d="M18 64 C18 30 34 16 50 16 C66 16 82 30 82 64 L72 80 H28 Z" fill="#a8adb8"/><rect x="30" y="50" width="40" height="10" fill="#2a2a30"/>'),
    "glove": ("#2a2420", '<path d="M30 86 V44 L26 22 H36 L40 40 V16 H48 V40 V12 H56 V40 V16 H64 V44 L74 34 L80 40 L66 62 V86 Z" fill="#b58a5a"/>'),
    "ring": ("#2a2418", '<circle cx="50" cy="56" r="24" fill="none" stroke="#e8c050" stroke-width="10"/><path d="M42 26 L50 14 L58 26 L50 34 Z" fill="#6ad0ff"/>'),
    "sword": ("#202830", '<path d="M70 14 L84 16 L86 30 L44 72 L30 58 Z" fill="#cfd8e0"/><path d="M26 54 L46 74 L40 80 L20 60 Z" fill="#b08040"/><path d="M28 72 L18 82" stroke="#806030" stroke-width="8"/>'),
    "food": ("#3a2412", '<ellipse cx="50" cy="58" rx="30" ry="20" fill="#c87838"/><circle cx="64" cy="40" r="12" fill="#f0e0c0"/>'),
    "drink": ("#14283a", '<path d="M30 20 H70 L64 84 H36 Z" fill="#8fd0f0" opacity=".85"/><rect x="30" y="20" width="40" height="10" fill="#e0f4ff"/>'),
    "bandage": ("#2c2c2c", '<rect x="18" y="38" width="64" height="26" rx="12" fill="#e8e0d0" transform="rotate(-35 50 50)"/>'),
    "hearth": ("#1a2a3a", '<circle cx="50" cy="50" r="26" fill="#7fd0ff"/><circle cx="50" cy="50" r="12" fill="#e0f6ff"/>'),
    "pet": ("#2a2018", '<ellipse cx="50" cy="62" rx="26" ry="18" fill="#d8a060"/><circle cx="66" cy="38" r="14" fill="#d8a060"/><path d="M60 26 L62 14 L70 24 Z M72 28 L80 18 L80 32 Z" fill="#a06a30"/><circle cx="70" cy="38" r="3" fill="#201008"/>'),
    "pick": ("#2a2a2a", '<path d="M20 30 C40 14 64 14 82 30 L76 36 C62 26 42 26 26 36 Z" fill="#bcc4cc"/><rect x="46" y="28" width="8" height="58" fill="#8a6030"/>'),
    "herb": ("#1c3018", '<path d="M50 86 V40" stroke="#5a9040" stroke-width="6"/><ellipse cx="36" cy="44" rx="14" ry="8" fill="#70c050" transform="rotate(-30 36 44)"/><ellipse cx="64" cy="40" rx="14" ry="8" fill="#70c050" transform="rotate(30 64 40)"/><circle cx="50" cy="28" r="10" fill="#e070d0"/>'),
    "fire": ("#3a1a0a", '<path d="M50 12 C62 34 80 44 70 70 A22 22 0 0 1 30 70 C22 50 40 40 42 26 C48 36 50 30 50 12 Z" fill="#ff8a2a"/><path d="M50 46 C58 58 62 64 56 76 A10 10 0 0 1 42 74 C40 64 48 58 50 46 Z" fill="#ffe070"/>'),
    "holy": ("#3a3010", '<circle cx="50" cy="50" r="20" fill="#ffe680"/><path d="M50 10 V30 M50 70 V90 M10 50 H30 M70 50 H90 M22 22 L36 36 M64 64 L78 78 M22 78 L36 64 M64 36 L78 22" stroke="#ffe680" stroke-width="6"/>'),
    "shield": ("#1e2836", '<path d="M50 10 L84 22 C84 56 72 78 50 90 C28 78 16 56 16 22 Z" fill="#7aa4d8"/><path d="M50 22 L72 30 C72 54 64 70 50 78 Z" fill="#b8d4f4"/>'),
    "shadow": ("#1e1430", '<circle cx="50" cy="50" r="28" fill="#8a5ad8"/><circle cx="50" cy="50" r="14" fill="#2a1840"/>'),
    "frost": ("#14283a", '<path d="M50 12 V88 M17 31 L83 69 M17 69 L83 31" stroke="#bfe6ff" stroke-width="9" stroke-linecap="round"/>'),
    "nature": ("#203a1c", '<path d="M50 84 C20 70 18 36 50 14 C82 36 80 70 50 84 Z" fill="#7cd060"/><path d="M50 84 V30" stroke="#2a5a1c" stroke-width="5"/>'),
    "arcane": ("#2a1840", '<path d="M50 14 L58 42 L86 50 L58 58 L50 86 L42 58 L14 50 L42 42 Z" fill="#d79cff"/>'),
    "claw": ("#3a1414", '<path d="M25 80 L45 20 M45 82 L62 22 M65 84 L80 28" stroke="#ff6a5a" stroke-width="9" stroke-linecap="round"/>'),
    "bear": ("#2e2014", '<circle cx="50" cy="56" r="26" fill="#8a5a30"/><circle cx="30" cy="30" r="10" fill="#8a5a30"/><circle cx="70" cy="30" r="10" fill="#8a5a30"/><circle cx="42" cy="52" r="4" fill="#1a0a00"/><circle cx="58" cy="52" r="4" fill="#1a0a00"/>'),
    "cat": ("#3a2a1a", '<path d="M24 82 L24 34 L36 18 L44 34 L56 34 L64 18 L76 34 L76 82 Z" fill="#c9965a"/><circle cx="40" cy="50" r="5" fill="#2a1a0a"/><circle cx="60" cy="50" r="5" fill="#2a1a0a"/>'),
    "heal": ("#14301e", '<rect x="40" y="18" width="20" height="64" fill="#8cf08c"/><rect x="18" y="40" width="64" height="20" fill="#8cf08c"/>'),
    "book": ("#2a1e14", '<rect x="20" y="16" width="60" height="70" rx="4" fill="#8a4a2a"/><rect x="28" y="16" width="6" height="70" fill="#5a2a14"/><rect x="40" y="30" width="30" height="6" fill="#e8c890"/>'),
    "scroll": ("#2e2616", '<rect x="24" y="22" width="52" height="56" fill="#e8d8a8"/><rect x="18" y="16" width="64" height="10" rx="5" fill="#b89860"/><rect x="18" y="74" width="64" height="10" rx="5" fill="#b89860"/><path d="M34 40 H66 M34 52 H66 M34 64 H56" stroke="#8a6a3a" stroke-width="4"/>'),
    "flask": ("#2a1a3a", '<circle cx="50" cy="60" r="24" fill="#b070f0"/><rect x="42" y="14" width="16" height="26" fill="#b070f0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "thread": ("#1a2840", '<rect x="34" y="16" width="32" height="68" rx="6" fill="#d8b070"/><rect x="30" y="30" width="40" height="40" fill="#3a78d8"/>'),
    "hammer": ("#2a2a2a", '<rect x="22" y="18" width="56" height="22" rx="3" fill="#a0a8b0"/><rect x="45" y="40" width="10" height="46" fill="#8a6030"/>'),
    "fish": ("#10304a", '<path d="M14 50 C30 26 62 26 74 50 C62 74 30 74 14 50 Z" fill="#7fb8e0"/><path d="M74 50 L90 34 V66 Z" fill="#7fb8e0"/><circle cx="30" cy="46" r="4" fill="#0a1a2a"/>'),
    "gear": ("#26303a", '<circle cx="50" cy="50" r="22" fill="none" stroke="#c0c8d0" stroke-width="12" stroke-dasharray="9 6"/><circle cx="50" cy="50" r="10" fill="#c0c8d0"/>'),
    "bolt": ("#24204a", '<path d="M56 10 L26 56 H48 L40 90 L76 40 H54 Z" fill="#ffe14a"/>'),
    "chest": ("#2a1e10", '<rect x="18" y="38" width="64" height="42" fill="#9a6a30"/><path d="M18 38 C18 18 82 18 82 38 Z" fill="#b8843c"/><rect x="44" y="44" width="12" height="14" fill="#e8c050"/>'),
    "arrow": ("#2a2418", '<path d="M18 82 L72 28" stroke="#c8a870" stroke-width="7"/><path d="M64 20 L84 16 L80 36 Z" fill="#c0c8d0"/><path d="M18 82 L26 66 M18 82 L34 74" stroke="#e8e0d0" stroke-width="5"/>'),
    "kick": ("#2e1c14", '<path d="M30 20 L48 20 L54 56 L80 64 L78 80 L34 80 Z" fill="#c9965a"/>'),
    "stealth": ("#1a1a24", '<circle cx="50" cy="50" r="30" fill="#4a4a6a"/><path d="M26 50 C38 34 62 34 74 50 C62 66 38 66 26 50 Z" fill="#1a1a24"/><circle cx="50" cy="50" r="8" fill="#9aa0d0"/>'),
}


def icon_svg(kind):
    bg, shape = ICON_ART[kind]
    return (f'<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="display:block">'
            f'<defs><linearGradient id="sh_{kind}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".18"/>'
            f'<stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs>'
            f'<rect width="100" height="100" fill="{bg}"/>{shape}<rect width="100" height="100" fill="url(#sh_{kind})"/></svg>')


def icon_box(x, y, size, kind, border="#000", style=""):
    return box(x, y, size, size, f"border:1px solid {border};overflow:hidden;{style}", icon_svg(kind))


# ---------------------------------------------------------------------------
# Rendering (local headless Chrome)
# ---------------------------------------------------------------------------
def find_chrome():
    cands = [os.environ.get("CHROME"), r"C:\Program Files\Google\Chrome\Application\chrome.exe",
             r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
             shutil.which("chrome"), shutil.which("google-chrome"), shutil.which("chromium")]
    for c in cands:
        if c and Path(c).exists():
            return c
    sys.exit("Chrome not found (set CHROME=<path to chrome>)")


def chrome_args(chrome, tmp):
    return [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
            f"--user-data-dir={Path(tmp) / 'chrome_profile'}", "--virtual-time-budget=3000"]


def render(chrome, body, call, out_png, tmp):
    doc = (f'<!doctype html><html><head><meta charset="utf-8"><style>{page_css(call)}</style></head>'
           f'<body><div class="sky"></div>{HILLS}{body}{FIT_JS}</body></html>')
    page = Path(tmp) / (out_png.stem + ".html")
    page.write_text(doc, encoding="utf-8")
    # pass 1: let the page measure itself, pass 2: screenshot at that height
    dom = subprocess.run(chrome_args(chrome, tmp) + ["--window-size=1600,4000", "--dump-dom", page.as_uri()],
                         check=True, capture_output=True, timeout=120).stdout.decode("utf-8", "replace")
    m = re.search(r'data-h="(\d+)"', dom)
    height = int(m.group(1)) if m else 1200
    subprocess.run(chrome_args(chrome, tmp) + [f"--window-size={PAGE_W},{height}", f"--screenshot={out_png}", page.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    return height


def run_pages(root, pages, call):
    """pages: list of (file stem, function returning page body html)."""
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    chrome = find_chrome()
    tmp = tempfile.mkdtemp(prefix="ezwow_readme_")
    try:
        for stem, fn in pages:
            png = out / f"{stem}.png"
            h = render(chrome, fn(), call, png, tmp)
            print("wrote", png, h)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# EzWoW - Tooltip
# ---------------------------------------------------------------------------
TITLE = "EzWoW - Tooltip"


def load(root):
    ow = read(root, "UI/OptionsWindow.lua")
    loc = read(root, "Core/Locales.lua")
    dflt = read(root, "Data/Defaults.lua")
    th = {k: rgb_list(v) for k, v in re.findall(r"(\w+)\s*=\s*\{\s*([\d.,\s]+)\}", lua_table(ow, r"local Theme = \{"))}
    th["bgSub"] = th["bgSub"]
    th["muted"] = th["muted"]
    # option strings: L_EN, LOCALES.koKR and the lines added after the tables
    L = {"en": lua_strings(lua_table(ow, r"local L_EN = \{")), "ko": lua_strings(lua_table(ow, r"koKR = setmetatable\(\{"))}
    for k, v in re.findall(r'^L_EN\.(\w+) = "((?:[^"\\]|\\.)*)"', ow, re.M):
        L["en"][k] = unlua(v)
    for k, v in re.findall(r'^LOCALES\.koKR\.(\w+) = "((?:[^"\\]|\\.)*)"', ow, re.M):
        L["ko"][k] = unlua(v)
    for lang in ("ko",):
        for k, v in L["en"].items():
            L[lang].setdefault(k, v)
    extra = lua_table(loc, r"local EXTRA_LOCALE = \{")
    EL = {"ko": lua_strings(lua_table(extra, r"koKR = \{")), "en": lua_strings(lua_table(extra, r"enUS = \{"))}
    owners = dict(re.findall(r'\["(EzWoW-\w+)"\] = "([^"]+)"', lua_table(ow, r"local OWNER_TITLES = \{")))

    # layout of the settings window, straight from launchConfigWindow
    size = re.search(r'configFrame:SetSize\((\d+), (\d+)\)', ow)
    layout = {"W": int(size.group(1)), "H": int(size.group(2))}
    body = ow[ow.index("function SettingsDialog.launchConfigWindow"):ow.index("refreshLabels = function")]
    labels = dict((v, k) for v, k in re.findall(r'fitFontStringToWidth\((\w+), SettingsDialog\.resolveOptionsLocaleText\("(\w+)"\)', ow))
    layout["sections"] = [(labels[v], int(x), -int(y), int(w)) for v, x, y, w in
                          re.findall(r"local (\w+) = createSectionDivider\((\d+), (-?\d+), (\d+)\)", body)]
    layout["steppers"] = [(labels[a], int(x), -int(y)) for a, _, x, y in
                          re.findall(r"local (\w+), (\w+) = createValueStepper\((\d+), (-?\d+)", body)]
    layout["buttons"] = {v: (int(x), -int(y), int(w), int(h), acc == "true") for v, _, x, y, w, h, acc in
                         re.findall(r"local (\w+), (\w+) = createStyledButton\((\d+), (-?\d+), (\d+), (\d+), (true|false)", body)}
    bx = re.search(r"local bx = (\d+) \+ columnIndex \* (\d+)", body)
    by = re.search(r"local byVal = (-?\d+) - rowWidget \* (\d+)", body)
    bs = re.search(r"createStyledButton\(bx, byVal, (\d+), (\d+)", body)
    layout["dirs"] = (int(bx.group(1)), int(bx.group(2)), -int(by.group(1)), int(by.group(2)), int(bs.group(1)), int(bs.group(2)))
    layout["dirKeys"] = re.findall(r'localeKey = "(dir\w+)"', lua_table(ow, r"local CURSOR_DIR_ORDER = \{"))
    div = re.search(r'colDivider:SetPoint\("TOPLEFT", configFrame, "TOPLEFT", (\d+), (-?\d+)\)\s*colDivider:SetSize\((\d+), (\d+)\)', body)
    layout["divider"] = (int(div.group(1)), -int(div.group(2)), int(div.group(3)), int(div.group(4)))
    checks = []
    parts = body.split("createStyledCheckbox(")[2:]   # [0] is before the first call, [1] the definition
    for seg in parts:
        m = re.match(r"(\d+), (-?\d+), (\d+), \"(\w+)\",\s*function\(\) return (.+?) end", seg, re.S)
        if not m:
            continue
        owner = re.search(r'"(EzWoW-\w+)"', seg.split("createStyled")[0])
        checks.append({"x": int(m.group(1)), "y": -int(m.group(2)), "w": int(m.group(3)), "key": m.group(4),
                       "read": m.group(5).strip(), "owner": owner.group(1) if owner else None})
    layout["checks"] = checks
    return {"th": th, "L": L, "EL": EL, "owners": owners, "layout": layout, "defaults": dflt,
            "icon": icon_data(find_file(root, "Media/Icon.png")), "version": toc_version(root)}


def default_value(dsrc, expr):
    """Evaluates the read expression of a check box against Data/Defaults.lua."""
    m = re.search(r"(?:addon\.db|EzWoW_TooltipDB)\.((?:\w+\.)*\w+)(?:\s*(~=|==)\s*(false|true|\"\w+\"))?\s*$", expr.split(" and ")[-1])
    path, op, val = m.group(1).split("."), m.group(2), m.group(3)
    v = None
    if "anchor" in path:      # anchor("cursor", { ... }) helper with its defaults
        base = dict(re.findall(r"(\w+) = (true|false),", lua_table(dsrc, r"local function anchor")))
        extra = re.search(r"anchor\s*=\s*anchor\(\"\w+\", \{([^}]*)\}\)", dsrc)
        base.update(dict(re.findall(r"(\w+) = (true|false)", extra.group(1))))
        v = base.get(path[-1])
    else:
        block = dsrc
        for name in path[:-1]:
            block = lua_table(block, rf"\b{name}\s*=\s*\{{")
        mm = re.search(rf"^\s*{path[-1]}\s*=\s*(true|false|\"\w+\")", block, re.M)
        v = mm.group(1) if mm else None
    if op == "~=":
        return v != val
    if op == "==":
        return v == val
    return v == "true"


def tag(label, value, lab_col="A7B9C5"):
    return f'<span style="color:#4BC8E8">◆</span> <span style="color:#{lab_col}">{esc(label)}:</span> {value}'


T = {
    "ko": {
        "lead": "다크 카드 스킨 툴팁에 아이템 레벨 · 특성 · 위협 수준 · 획득처 · 수집 상태 · 보유 수량 · 경매장 시세 · 채집 숙련도를 함께 표시",
        "pName": "블루셰이드", "pSurname": "모래바람", "pTitle": "수호자", "pGuild": "&lt;새벽의 등불&gt; 기사단원",
        "pLine": "28 레벨 인간 성기사 (플레이어)", "zone": "그늘숲", "talent": "신성 (21/5/0)", "mount": "갈색 말",
        "target": "대상", "tName": "잿빛서리", "by": "들꽃노래", "by2": "검은송곳",
        "npc": "덤불숲 강도", "npcLine": "13 레벨 정예 인간형", "cast": "어둠의 화살", "npcTarget": "블루셰이드",
        "alive": "3분 12초", "npcId": "NPC ID",
        "node": "은엽수 덤불", "nodeSub": "약초", "herb": "약초 채집",
        "item": "이끼바위 어깨보호대", "itemEn": "Mossrock Shoulderguards", "bind": "획득 시 귀속", "slot": ("어깨", "판금"),
        "armor": "방어구 214", "stats": ["+6 힘", "+5 체력"], "dur": "내구도 60 / 60", "req": "최소 요구 레벨: 26",
        "src1": "던전 · 통곡의 동굴 (12%)", "src2": "퀘스트 · 사라진 순찰대", "coll": "형상 미수집",
        "eq": "현재 착용 중", "eqItem": "낡은 판금 어깨보호구", "eqArmor": "방어구 150", "eqStat": "+3 힘", "itemId": "아이템 ID",
        "reag": "은엽수", "reagEn": "Peacebloom Leaf", "reagType": "제작 재료",
        "usedIn": "연금술 (11개) · 요리 (1개)", "aura": "신의 권능: 인내", "auraDesc": "체력이 증가합니다.", "spellId": "주문 ID",
        "auraCaster": "잿빛서리",
        "notes": [
            ("카드 스킨 · 3D 모델", "다크 슬레이트 배경, 직각 테두리, 위쪽 광택, 아래쪽 체력 바(수치). 테두리 색은 직업 · NPC 우호도 · 아이템 품질 · 퀘스트 난이도. 3D 모델은 툴팁 왼쪽 여백에 표시."),
            ("플레이어", "칭호 · 이름 성 · 길드, 아이템 레벨, 특성 배분, 탈것, 이동 속도, 대상의 대상, 이 대상을 선택한 파티원, PvP 계급."),
            ("NPC", "지금 시전 중인 주문, 내 위협 수준(%)·탱킹, 대상, 생존 시간 · 위상, 드랍 수집 추적, NPC ID."),
            ("채집 숙련도", "약초 · 광맥 · 가죽 벗길 수 있는 시체에 필요한 숙련도와 내 숙련도를 난이도 색(빨강 · 주황 · 노랑 · 초록 · 회색)으로."),
            ("아이템 · 착용 장비 비교", "한 · 영 이름, 획득처, 수집 상태, 보유 수량, 상점 판매가, 경매장 시세, ID. 옵션을 켜면 Shift 없이 착용 장비 비교 툴팁이 함께 뜹니다(기본 꺼짐)."),
            ("재료", "이 재료를 쓰는 제조법 수(재료 사용처). EzWoW - Profession Recipes가 이 줄을 보여 주면 그쪽에 맡기고 겹쳐 쓰지 않습니다."),
            ("오라", "버프 · 디버프를 건 사람(직업 색)과 주문 ID."),
        ],
        "foot": "애드온 코드의 크기 · 색상 · 문구로 재현한 예시 화면입니다. 이름 · 길드 · 숫자는 지어낸 예시이고, 3D 모델 자리에는 그림을 넣었습니다. EzWoW - Best Gear Finder가 장비의 획득처 블록을 보여 줄 때는 이 애드온의 획득처 줄을 생략합니다.",
        "sLead": "/ezt · 외형, 표시 위치 · 전투, 유닛 확장 정보, 아이템 · 주문 · 상점 편의",
        "sTitle": "설정창",
        "sNotes": [
            ("언어 · 테두리", "언어는 상자를 눌러 목록에서 고릅니다. 테두리는 직각 / 기본."),
            ("일반 · 외형", "툴팁 크기 50~200%, 배경 투명도, 광택, 서서히 사라지기, 드롭다운 스킨(/reload), 캐릭터별 설정."),
            ("위치 · 전투", "마우스 따라가기(6방향) / 게임 기본 / 고정 위치(/ezt static로 끌어서 지정). 전투 중 숨기기 · 기본 위치, 유닛 프레임 위 기본 위치."),
            ("유닛", "테두리 색, 3D 모델, 특성, 아이템 레벨, PvP 계급, 대상의 대상, 나를 선택한 파티원, 탈것, 이동 속도, 시전 · 위협, NPC 추적, 죽은 대상 회색, 체력 수치, 이슈 리포터 숨김, 체력바 높이(0~16), 채집 숙련도."),
            ("아이템 · 상점", "획득처, 수집 상태, 보유 수량, 겹침 · 판매가, 품질 · 퀘스트 테두리, 아이콘, 시전자, ID, 경매장 시세(버튼으로 갱신), 한 · 영 이름, 잡템 판매 · 자동 수리, 채팅 링크 툴팁, Shift 없이 착용 장비 비교."),
            ("기본값 복원 · 후원", "모든 설정을 처음 값으로(/ezt reset과 같음)."),
        ],
        "sFoot": "애드온 코드의 창 크기 · 좌표 · 색상 · 문구로 재현한 예시 화면입니다. 체크 상태는 기본값이며, 회색 줄(잡템 판매 · 자동 수리 · 이슈 리포터)은 EzWoW - Bags · EzWoW - Error Catcher가 함께 설치되어 그쪽에서 설정하는 경우의 모습입니다.",
    },
    "en": {
        "lead": "Dark card tooltips with item level, talents, threat, sources, collection status, owned count, AH price and gathering skill",
        "pName": "Blueshade", "pSurname": "Sandwind", "pTitle": "Warden", "pGuild": "&lt;Dawnlantern&gt; Knight",
        "pLine": "Level 28 Human Paladin (Player)", "zone": "Duskwood", "talent": "Holy (21/5/0)", "mount": "Brown Horse",
        "target": "Target", "tName": "Ashfrost", "by": "Wildsong", "by2": "Darkfang",
        "npc": "Thicket Bandit", "npcLine": "Level 13 Elite Humanoid", "cast": "Shadow Bolt", "npcTarget": "Blueshade",
        "alive": "3m 12s", "npcId": "NPC ID",
        "node": "Silverleaf Bush", "nodeSub": "Herb", "herb": "Herbalism",
        "item": "Mossrock Shoulderguards", "itemEn": "이끼바위 어깨보호대", "bind": "Binds when picked up", "slot": ("Shoulder", "Plate"),
        "armor": "214 Armor", "stats": ["+6 Strength", "+5 Stamina"], "dur": "Durability 60 / 60", "req": "Requires Level 26",
        "src1": "Dungeon · Wailing Caverns (12%)", "src2": "Quest · The Lost Patrol", "coll": "Appearance not collected",
        "eq": "Currently Equipped", "eqItem": "Worn Plate Shoulders", "eqArmor": "150 Armor", "eqStat": "+3 Strength", "itemId": "Item ID",
        "reag": "Peacebloom Leaf", "reagEn": "은엽수", "reagType": "Crafting Reagent",
        "usedIn": "Alchemy (11) · Cooking (1)", "aura": "Power Word: Fortitude", "auraDesc": "Increases Stamina.", "spellId": "Spell ID",
        "auraCaster": "Ashfrost",
        "notes": [
            ("Card skin · 3D model", "Dark slate background, angular border, top gloss, health bar with numbers. Border colour follows class, NPC reaction, item quality or quest difficulty. The 3D model sits in the tooltip's left margin."),
            ("Players", "Title, first name and surname, guild, item level, talent split, mount, speed, target of target, party members targeting the unit, PvP rank."),
            ("NPCs", "Current cast, your threat (%) and tanking, target, alive time and layer, drop tracking, NPC ID."),
            ("Gathering skill", "Required and current skill on herbs, ore veins and skinnable corpses, in difficulty colours (red, orange, yellow, green, grey)."),
            ("Items · compare with equipped", "Korean/English names, sources, collection status, owned count, vendor price, AH price, ID. With the option on, the equipped-gear comparison shows without Shift (off by default)."),
            ("Reagents", "How many recipes use the item (Used In). When EzWoW - Profession Recipes shows these lines, this addon leaves them to it."),
            ("Auras", "Who cast a buff or debuff (class colour) and the spell ID."),
        ],
        "foot": "Mock-ups rebuilt from the sizes, colours and strings in the addon code. Names, guild and numbers are made up; a picture stands in for the 3D model. When EzWoW - Best Gear Finder shows its source block for a piece of gear, this addon leaves out its own source lines.",
        "sLead": "/ezt · appearance, position & combat, unit info, items, spells & merchant",
        "sTitle": "Settings",
        "sNotes": [
            ("Language · border", "Click the box and pick a language from the list. Border: angular / default."),
            ("General & appearance", "Scale 50–200%, opacity, gloss, fade out, dropdown skin (/reload), per-character settings."),
            ("Position & combat", "Follow cursor (6 directions) / game default / static point (drag it with /ezt static). Hide or use the default position in combat, default position over unit frames."),
            ("Units", "Border colours, 3D model, talents, item level, PvP rank, target of target, party members targeting, mount, speed, cast & threat, NPC tracking, grey dead units, health numbers, hide Issue Reporter, HP bar height (0–16), gathering skill."),
            ("Items & merchant", "Sources, collection status, owned count, stack & vendor price, quality and quest borders, icons, caster, IDs, AH price (button to update), dual names, auto-sell junk & auto-repair, chat link tooltips, compare with equipped gear without Shift."),
            ("Reset · support", "Restore every default (same as /ezt reset)."),
        ],
        "sFoot": "Mock-up rebuilt from the window size, coordinates, colours and strings in the addon code. Check boxes show the defaults; the grey rows (auto-sell, auto-repair, Issue Reporter) show how they look when EzWoW - Bags and EzWoW - Error Catcher are installed and own those settings.",
    },
}


def model_art():
    return ('<svg width="100%" height="100%" viewBox="0 0 100 150" preserveAspectRatio="xMidYMax meet" style="display:block">'
            '<ellipse cx="50" cy="146" rx="34" ry="4" fill="rgba(0,0,0,.5)"/>'
            '<path d="M22 146 L26 92 C26 78 74 78 74 92 L78 146 Z" fill="#c8b070"/><path d="M30 96 H70 V126 H30 Z" fill="#e8e0c0"/>'
            '<rect x="44" y="96" width="12" height="30" fill="#c03030"/><circle cx="50" cy="60" r="18" fill="#e0b090"/>'
            '<path d="M30 58 C30 34 70 34 70 58 C64 46 36 46 30 58 Z" fill="#7a5030"/>'
            '<circle cx="43" cy="62" r="2.5" fill="#202020"/><circle cx="57" cy="62" r="2.5" fill="#202020"/>'
            '<path d="M18 84 L30 80 L30 118 L20 122 Z M82 84 L70 80 L70 118 L80 122 Z" fill="#b0b8c0"/></svg>')


def ui_page(lang, ctx):
    global S
    S = 1.25
    t, EL, L = T[lang], ctx["EL"][lang], ctx["L"][lang]
    mut = "#A7B9C5"
    parts = [heading(TITLE, esc(t["lead"]))]
    W = "#EDF4F7"
    pal = CLASS_HEX["PALADIN"]

    # 1-2 player card: 3D model in the left padding (SetPadding left = model width)
    model_w = 92
    px0, py0 = 70, 168
    name = f'<span style="color:{pal}">{esc(t["pTitle"])} {esc(t["pName"])} {esc(t["pSurname"])}</span>'
    if lang == "ko":
        name = f'<span style="color:{pal}">{esc(t["pName"])} {esc(t["pSurname"])}</span> <span style="color:{pal}">{esc(t["pTitle"])}</span>'
    plines = [
        name,
        f'<span style="color:#40ff40">{t["pGuild"]}</span>',
        f'<span style="color:{W}">{esc(t["pLine"])}</span>',
        f'<span style="color:{W}">{esc(t["zone"])}</span>',
        tag(EL["ilvl"], f'<span style="color:{W}">24.6</span>'),
        tag(L["talentLabel"], f'<span style="color:{W}">{esc(t["talent"])}</span>'),
        tag(EL["mount"], f'<span style="color:{W}">{esc(t["mount"])}</span>'),
        tag(EL["speed"], f'<span style="color:{W}">100%</span>'),
        f'<span style="color:{mut}">{esc(t["target"])}:</span> <span style="color:{CLASS_HEX["PRIEST"]}">{esc(t["tName"])}</span>',
        f'<span style="color:{mut}">{esc(L["targetByLabel"])}:</span> <span style="color:{CLASS_HEX["DRUID"]}">{esc(t["by"])}</span>, '
        f'<span style="color:{CLASS_HEX["ROGUE"]}">{esc(t["by2"])}</span>',
    ]
    pw = 360
    parts.append(tooltip(px0, py0, plines, border=pal, bar=(0.82, pal, "1,240 / 1,512"), left_pad=model_w, width=pw))
    parts.append(f'<div class="abs" style="left:{px0 + 6}px;top:{py0 + 18}px;width:{model_w * S - 8:.0f}px;height:{150 * S:.0f}px;z-index:31">{model_art()}</div>')

    # 3 NPC card
    hostile = "#ff2020"
    nx, ny = px0 + pw * S + 40, 168
    nlines = [
        f'<span style="color:{hostile}">{esc(t["npc"])}</span>',
        f'<span style="color:{W}">{esc(t["npcLine"])}</span>',
        tag(EL["casting"], f'<span style="color:#ffd100">{esc(t["cast"])}</span>'),
        tag(EL["threat"], f'<span style="color:#ff2020">100%</span> <span style="color:#EA837E">[{esc(EL["tanking"])}]</span>'),
        f'<span style="color:{mut}">{esc(t["target"])}:</span> <span style="color:{pal}">{esc(t["npcTarget"])}</span>',
        tag(EL["npcAlive"], f'<span style="color:{W}">{esc(t["alive"])}</span> <span style="color:#8398A6">{esc(EL["layer"])} #2</span>'),
        tag(EL["npcTrack"], f'<span style="color:#40bf40">{esc(EL["npcDropsFmt"] % (1, 3))}</span>'),
        (f'<span style="color:{mut}">{esc(t["npcId"])}</span>', f'<span style="color:{W}">448</span>'),
    ]
    parts.append(tooltip(nx, ny, nlines, border="#cc3333", bar=(0.64, "#d83a3a", "355 / 552")))

    # 4 gathering node (object tooltip + required skill line)
    gx, gy = 925, 168
    req = EL["gatherReqFmt"] % (esc(t["herb"]), 70, 85)
    glines = [f'<span style="color:{W}">{esc(t["node"])}</span>', f'<span style="color:{mut}">{esc(t["nodeSub"])}</span>',
              f'<span style="color:#ff8040">{req}</span>']
    parts.append(tooltip(gx, gy, glines))
    req2 = EL["gatherReqFmt"] % (esc(EL["gatherMining"]), 125, 85)
    parts.append(tooltip(gx, gy + 112, [f'<span style="color:{W}">{"구리 광맥" if lang == "ko" else "Copper Vein"}</span>',
                                        f'<span style="color:#ff2020">{req2}</span>']))

    # 5 item card + client comparison tooltip (equipped)
    q = QUALITY[3]
    ix, iy = 70, 470
    iw = 290
    money = '<span style="color:#fff">1</span><span style="color:#ffd700">●</span> <span style="color:#fff">24</span><span style="color:#c7c7cf">●</span>'
    ilines = [
        f'<span style="color:{q}">{esc(t["item"])}</span>',
        f'<span style="color:#8398A6">{esc(t["itemEn"])}</span>',
        f'<span style="color:{W}">{esc(t["bind"])}</span>',
        (f'<span style="color:{W}">{esc(t["slot"][0])}</span>', f'<span style="color:{W}">{esc(t["slot"][1])}</span>'),
        f'<span style="color:{W}">{esc(t["armor"])}</span>',
    ] + [f'<span style="color:{W}">{esc(s)}</span>' for s in t["stats"]] + [
        f'<span style="color:{W}">{esc(t["dur"])}</span>',
        f'<span style="color:{W}">{esc(t["req"])}</span>',
        tag(EL["collection"], f'<span style="color:#ff8040">{esc(t["coll"])}</span>'),
        tag(EL["source"], f'<span style="color:{W}">{esc(t["src1"])}</span>'),
        f'<span style="color:#4BC8E8">◇</span> <span style="color:#8398A6">{esc(EL["source2"])}:</span> <span style="color:{W}">{esc(t["src2"])}</span>',
        tag(EL["sellPrice"], money),
        tag(EL["auctionPrice"], '<span style="color:#fff">4</span><span style="color:#ffd700">●</span> '
            '<span style="color:#fff">80</span><span style="color:#c7c7cf">●</span> <span style="color:#8398A6">(' + esc(EL["ageHour"] % 2) + ')</span>'),
        (f'<span style="color:{mut}">{esc(t["itemId"])}</span>', f'<span style="color:{W}">6668</span>'),
    ]
    parts.append(tooltip(ix, iy, ilines, border=q, width=iw))
    elines = [f'<span style="color:#808080">{esc(t["eq"])}</span>', f'<span style="color:{QUALITY[2]}">{esc(t["eqItem"])}</span>',
              (f'<span style="color:{W}">{esc(t["slot"][0])}</span>', f'<span style="color:{W}">{esc(t["slot"][1])}</span>'),
              f'<span style="color:{W}">{esc(t["eqArmor"])}</span>', f'<span style="color:{W}">{esc(t["eqStat"])}</span>']
    parts.append(tooltip(ix + iw * S + 2, iy, elines, border=QUALITY[2]))

    # 6 reagent with "used in"
    rx, ry = 760, 470
    count = EL["bagFmt"].replace("%d", "{}").format(14, 10, 4)
    rlines = [f'<span style="color:#fff">{esc(t["reag"])}</span>', f'<span style="color:#8398A6">{esc(t["reagEn"])}</span>',
              f'<span style="color:#66bbff">{esc(t["reagType"])}</span>',
              tag(EL["bagCount"], f'<span style="color:{W}">{wow(count)}</span>'),
              f'<span style="color:#4BC8E8">◇</span> <span style="color:#8398A6">{esc(EL["usedIn"])}:</span> <span style="color:{W}">{esc(t["usedIn"])}</span>']
    parts.append(tooltip(rx, ry, rlines))

    # 7 aura caster
    ax, ay = 1215, 168
    alines = [f'<span style="color:#fff">{esc(t["aura"])}</span>', f'<span style="color:#ffd100">{esc(t["auraDesc"])}</span>',
              tag(EL["caster"], f'<span style="color:{CLASS_HEX["PRIEST"]}">{esc(t["auraCaster"])}</span>'),
              (f'<span style="color:{mut}">{esc(t["spellId"])}</span>', f'<span style="color:{W}">1244</span>')]
    parts.append(tooltip(ax, ay, alines, border="#AEE26A"))

    parts.append(callouts([(px0, py0), (px0 + pw * S, py0 + 105), (nx, ny), (gx, gy), (ix, iy), (rx, ry), (ax, ay)]))
    ny_notes = 870
    parts.append(notes_block(50, ny_notes, 730, t["notes"][:4]))
    parts.append(notes_block(820, ny_notes, 730, t["notes"][4:], start=5))
    parts.append(f'<div class="foot" style="left:50px;width:1500px">{esc(t["foot"])}</div>')
    return "".join(parts)


def settings_page(lang, ctx):
    global S
    S = 1.15
    t, L, th, lay = T[lang], ctx["L"][lang], ctx["th"], ctx["layout"]
    th = dict(th)
    th["bgSub"] = th["bgSub"]
    th["text"], th["muted"] = th["text"], th["muted"]
    win = Window({"bg": th["bg"], "bgSub": th["bgSub"], "border": th["border"], "text": th["text"], "muted": th["muted"],
                  "accent": th["accent"]}, lay["W"], lay["H"], TITLE, esc(L["subtitle"]), ctx["icon"], header=56, close=28, close_off=14)
    acc = css(th["accent"])
    d = lay["divider"]
    win.add(box(d[0], d[1], d[2], d[3], "background:rgba(52,76,91,.55)"))
    for key, x, y, w in lay["sections"]:
        win.section(x, y, esc(L[key]), width=w)
    for key, x, y in lay["steppers"]:
        val = {"scale": "100%", "opacity": "92%", "hpHeight": "8px"}[key]
        win.stepper(x, y, esc(L[key]), val, 88, 156, label_dy=6, label_w=82, value_color=acc)
    b = lay["buttons"]
    lab = {
        "langBtn": f'{L["language"]}: {L["langAuto"]} ▼', "borderBtn": f'{L["borderStyle"]}: {L["borderAngular"]} ▼',
        "posBtn": f'{L["position"]}: {L["posCursor"]} ▼', "moveStaticBtn": L["moveStatic"],
        "inspectAhBtn": L["scanAuctionBtn"].replace("%d", "1,284"), "resetBtn": L["reset"], "donateBtn": L["donate"],
    }
    for var, (x, y, w, h, accent) in b.items():
        size = 11 if var == "inspectAhBtn" else 12
        win.button(x, y, w, h, esc(lab[var]), accent=accent, size=size)
    x0, dx, y0, dy, bw, bh = lay["dirs"]
    for i, key in enumerate(lay["dirKeys"]):
        col, row = i % 3, i // 3
        active = key == "dirTopRight"
        win.button(x0 + col * dx, y0 + row * dy, bw, bh, esc(L[key]), size=11, color=acc if active else None,
                   bg="rgba(36,56,43,1)" if active else None, border=acc if active else None)
    dsrc = ctx["defaults"]
    for c in lay["checks"]:
        on = default_value(dsrc, c["read"])
        label = esc(L[c["key"]])
        disabled = False
        if c["owner"]:
            note = L["managedBy"].replace("%s", ctx["owners"].get(c["owner"], c["owner"]))
            label += f'  <span style="color:#8398A6">({esc(note)})</span>'
            disabled = True
        win.check(c["x"], c["y"], label, on, label_w=c["w"] - 2, disabled=disabled)
    win.add(f'<div class="t" style="left:{px(20)};top:{px(lay["H"] - 16 - 12)};width:{px(790)};text-align:center;font-size:{px(10)};'
            f'color:{css(th["muted"])};{SHADOW}">{esc(L["hint"])}</div>')

    ox, oy = 50, 150
    secs = {k: y for k, _, y, _ in lay["sections"]}
    ys = {"lang": (66, 93), "gen": (secs["secGeneral"], secs["secAnchor"] - 6), "anc": (secs["secAnchor"], 386),
          "unit": (secs["secUnit"], 352), "item": (secs["secItem"], 572), "foot": (588, 618)}
    right = ox + lay["W"] * S
    calls = [(ox - 22, oy + (a + b_) / 2 * S) for a, b_ in (ys["lang"], ys["gen"], ys["anc"])]
    calls += [(right + 22, oy + (ys["unit"][0] + ys["unit"][1]) / 2 * S),
              (right + 22, oy + (ys["item"][0] + ys["item"][1]) / 2 * S),
              (right + 22, oy + (ys["foot"][0] + ys["foot"][1]) / 2 * S)]
    nx = right + 60
    return (heading(TITLE, esc(t["sLead"]), t["sTitle"]) + win.html(ox + 0, oy) + callouts(calls)
            + notes_block(nx, oy + 4, PAGE_W - nx - 40, [(a, esc(b_)) for a, b_ in t["sNotes"]])
            + f'<div class="foot" style="left:50px;width:1500px">{esc(t["sFoot"])}</div>')


def main(root: Path):
    ctx = load(root)
    call = hexc(ctx["th"]["accent"])
    run_pages(root, [(f"{n}_{lang}", (lambda n=n, lang=lang: (ui_page if n == "ui" else settings_page)(lang, ctx)))
                     for lang in ("ko", "en") for n in ("ui", "settings")], call)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())
