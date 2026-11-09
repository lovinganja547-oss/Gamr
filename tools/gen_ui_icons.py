#!/usr/bin/env python3
"""Jeu d'icônes vectorielles original de Truffe & Co (SVG 64x64 rendus en 128 px).
Style : contour brun chaud arrondi, aplats doux, petit reflet. Aucune ressource externe.
Usage : python3 tools/gen_ui_icons.py  -> assets/ui/icons/<nom>.svg
"""
import os, math

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "icons")
INK = "#4b3428"
SW = 3.2

def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">'
            f'<g stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')

def C(cx, cy, r, f="#fff", sw=None):
    s = f' stroke-width="{sw}"' if sw is not None else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{f}"{s}/>'

def E(cx, cy, rx, ry, f="#fff", rot=0, sw=None, sc=None):
    s = f' stroke-width="{sw}"' if sw is not None else ""
    if sc:
        s += f' stroke="{sc}"'
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{f}" transform="rotate({rot} {cx} {cy})"{s}/>'

def R(x, y, w, h, f="#fff", r=4, rot=0, sw=None):
    s = f' stroke-width="{sw}"' if sw is not None else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{f}" transform="rotate({rot} {x + w / 2} {y + h / 2})"{s}/>'

def P(d, f="none", sw=None, sc=None):
    s = f' stroke-width="{sw}"' if sw is not None else ""
    if sc:
        s += f' stroke="{sc}"'
    return f'<path d="{d}" fill="{f}"{s}/>'

def L(x1, y1, x2, y2, sw=None, sc=None):
    s = f' stroke-width="{sw}"' if sw is not None else ""
    if sc:
        s += f' stroke="{sc}"'
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"{s}/>'

def HL(cx, cy, r=3):   # reflet
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#fff" stroke="none" opacity="0.75"/>'

def star(cx, cy, r, f, n=5, inner=0.45):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{f}"/>'

def heart(cx, cy, s, f):
    d = (f"M{cx},{cy + s * 0.9} C{cx - s * 1.5},{cy - s * 0.1} {cx - s * 0.9},{cy - s * 1.3} {cx},{cy - s * 0.45} "
         f"C{cx + s * 0.9},{cy - s * 1.3} {cx + s * 1.5},{cy - s * 0.1} {cx},{cy + s * 0.9}Z")
    return P(d, f)

def bone(cx, cy, w, f="#fbf3e2", rot=-25):
    g = (f'<g transform="rotate({rot} {cx} {cy})">' + R(cx - w / 2, cy - 4, w, 8, f, 3) +
         C(cx - w / 2, cy - 4, 5, f) + C(cx - w / 2, cy + 4, 5, f) + C(cx + w / 2, cy - 4, 5, f) + C(cx + w / 2, cy + 4, 5, f) +
         R(cx - w / 2 + 2, cy - 2.5, w - 4, 5, f, 2, sw=0) + '</g>')
    return g

def bowl(fill_top):
    return (P("M10,32 L54,32 L49,50 Q48,54 44,54 L20,54 Q16,54 15,50 Z", "#f07a6a") +
            E(32, 32, 22, 6, fill_top) + HL(20, 42, 2.5))

def paw(cx, cy, s, f):
    return (E(cx, cy + s * 0.35, s * 0.55, s * 0.45, f) + C(cx - s * 0.62, cy - s * 0.25, s * 0.22, f) +
            C(cx - s * 0.22, cy - s * 0.6, s * 0.22, f) + C(cx + s * 0.22, cy - s * 0.6, s * 0.22, f) + C(cx + s * 0.62, cy - s * 0.25, s * 0.22, f))

ICONS = {}
def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco

# ------------------------------------------------------------------ interface
ICONS["coin"] = lambda: C(32, 32, 22, "#ffd24d") + C(32, 32, 15, "#ffc21a", sw=2) + paw(32, 33, 11, "#e79f16") + HL(22, 22, 4)
ICONS["star"] = lambda: star(32, 33, 25, "#ffd24d") + HL(25, 26, 3)
ICONS["heart"] = lambda: heart(32, 34, 17, "#ff6b81") + HL(23, 25, 3.5)
ICONS["relation"] = lambda: heart(25, 36, 13, "#ff8fb1") + heart(40, 30, 12, "#ff6b81")
ICONS["lock"] = lambda: P("M22,30 V22 A10,10 0 0 1 42,22 V30", "none", 4) + R(15, 29, 34, 25, "#ffd24d", 5) + C(32, 40, 3.5, INK) + L(32, 42, 32, 47)
ICONS["check"] = lambda: C(32, 32, 24, "#7ad17a") + P("M20,33 L28,41 L44,24", "none", 5)
ICONS["close"] = lambda: L(18, 18, 46, 46, 6) + L(46, 18, 18, 46, 6)
ICONS["left"] = lambda: P("M40,14 L20,32 L40,50", "none", 6)
ICONS["right"] = lambda: P("M24,14 L44,32 L24,50", "none", 6)
ICONS["menu"] = lambda: R(12, 14, 40, 7, "#fff", 3) + R(12, 29, 40, 7, "#fff", 3) + R(12, 44, 40, 7, "#fff", 3)
ICONS["recenter"] = lambda: C(32, 32, 20, "none") + C(32, 32, 7, "#ff8a5c") + L(32, 4, 32, 14) + L(32, 50, 32, 60) + L(4, 32, 14, 32) + L(50, 32, 60, 32)
ICONS["camera"] = lambda: R(8, 20, 48, 32, "#7fb2f0", 6) + R(22, 13, 20, 10, "#7fb2f0", 3) + C(32, 36, 10, "#fff") + C(32, 36, 5, "#5a7fb0") + C(47, 27, 2.5, "#ffd24d", sw=1.5)
ICONS["map"] = lambda: P("M8,16 L24,10 L40,16 L56,10 L56,48 L40,54 L24,48 L8,54 Z", "#bfe3a5") + L(24, 10, 24, 48) + L(40, 16, 40, 54) + P("M44,22 a6,6 0 1 1 0.1,0 M44,34 L44,28", "#ff6b81", 2.5)
ICONS["paw"] = lambda: paw(32, 33, 22, "#e8a56a")
ICONS["mic"] = lambda: R(23, 8, 18, 30, "#9ad0f5", 9) + P("M15,30 A17,17 0 0 0 49,30", "none") + L(32, 47, 32, 56) + L(23, 56, 41, 56)
ICONS["gear"] = lambda: "".join(f'<g transform="rotate({a} 32 32)">' + R(27, 4, 10, 14, "#c9c3bd", 2) + '</g>' for a in range(0, 360, 45)) + C(32, 32, 17, "#c9c3bd") + C(32, 32, 6, "#fff")
ICONS["calendar"] = lambda: R(10, 14, 44, 40, "#fff", 6) + R(10, 14, 44, 12, "#ff8a5c", 6) + L(22, 9, 22, 18) + L(42, 9, 42, 18) + P("M22,40 L29,46 L42,33", "none", 4)
ICONS["medal"] = lambda: P("M22,6 L30,28 M42,6 L34,28", "none", 6) + C(32, 40, 15, "#ffd24d") + star(32, 40, 8, "#ffb91a")
ICONS["medal_gold"] = lambda: P("M22,6 L30,28 M42,6 L34,28", "none", 6) + C(32, 40, 15, "#ffd24d") + P("M29,34 L33,32 L33,48", "none", 3)
ICONS["medal_silver"] = lambda: P("M22,6 L30,28 M42,6 L34,28", "none", 6) + C(32, 40, 15, "#d6dbe3") + P("M27,35 Q32,29 37,35 L27,47 L38,47", "none", 3)
ICONS["medal_bronze"] = lambda: P("M22,6 L30,28 M42,6 L34,28", "none", 6) + C(32, 40, 15, "#e0a066") + P("M27,33 L37,33 L31,39 Q38,39 37,44 Q34,49 27,46", "none", 3)
ICONS["album"] = lambda: R(14, 10, 38, 44, "#fff", 4, rot=-8) + R(10, 14, 38, 44, "#ffe9b8", 4) + P("M14,50 L24,36 L32,46 L38,40 L45,50 Z", "#7ac07a", 2.5) + C(37, 25, 4, "#ffd24d", sw=2)
ICONS["deco"] = lambda: R(8, 30, 48, 18, "#ff9f7f", 5) + R(12, 18, 40, 16, "#ffb39a", 5) + R(6, 26, 10, 22, "#f08a6a", 4) + R(48, 26, 10, 22, "#f08a6a", 4) + L(14, 48, 14, 55) + L(50, 48, 50, 55)
ICONS["style"] = lambda: P("M32,32 L10,18 Q6,32 10,46 Z", "#ff8fb1") + P("M32,32 L54,18 Q58,32 54,46 Z", "#ff8fb1") + C(32, 32, 7, "#ff6b9a")
ICONS["save"] = lambda: R(10, 10, 44, 44, "#7fb2f0", 6) + R(18, 10, 24, 14, "#fff", 2) + R(18, 34, 28, 20, "#fff", 2)
ICONS["trash"] = lambda: R(14, 18, 36, 6, "#c9c3bd", 2) + P("M18,24 L21,54 L43,54 L46,24 Z", "#e6e1dc") + L(27, 30, 28, 48) + L(37, 30, 36, 48) + R(26, 12, 12, 6, "#c9c3bd", 2)
ICONS["reload"] = lambda: P("M48,30 A16,16 0 1 1 42,18", "none", 5) + P("M40,8 L44,19 L33,21", "none", 5)
ICONS["warning"] = lambda: P("M32,8 L58,54 L6,54 Z", "#ffd24d") + L(32, 24, 32, 38, 5) + C(32, 46, 2.5, INK)
ICONS["dice"] = lambda: R(10, 10, 44, 44, "#fff", 9) + C(21, 21, 3.5, INK) + C(43, 43, 3.5, INK) + C(32, 32, 3.5, INK) + C(43, 21, 3.5, INK) + C(21, 43, 3.5, INK)
ICONS["tip"] = lambda: C(32, 26, 16, "#ffe680") + R(25, 40, 14, 8, "#c9c3bd", 2) + L(27, 52, 37, 52) + HL(26, 20, 3)
ICONS["timer"] = lambda: C(32, 36, 20, "#fff") + R(27, 6, 10, 7, "#ff8a5c", 2) + L(32, 36, 32, 24) + L(32, 36, 41, 40)
ICONS["flag"] = lambda: L(16, 8, 16, 58) + P("M16,10 L50,10 L42,21 L50,32 L16,32 Z", "#7ad17a")
ICONS["male"] = lambda: C(26, 38, 14, "#9ad0f5") + L(36, 28, 52, 12) + P("M40,12 L52,12 L52,24", "none")
ICONS["female"] = lambda: C(32, 24, 14, "#ffb3cf") + L(32, 38, 32, 58) + L(23, 49, 41, 49)
ICONS["sparkle"] = lambda: star(32, 32, 24, "#ffe680", 4, 0.3) + star(50, 14, 8, "#fff", 4, 0.35)
ICONS["trophy"] = lambda: P("M18,10 L46,10 L44,30 Q32,42 20,30 Z", "#ffd24d") + P("M18,14 Q6,14 10,24 Q14,30 21,30 M46,14 Q58,14 54,24 Q50,30 43,30", "none") + R(28, 38, 8, 10, "#ffc21a", 1) + R(18, 48, 28, 8, "#c99a6a", 3) + HL(25, 17, 3)
ICONS["shower"] = lambda: P("M14,8 L14,22 Q14,26 18,26 L30,26", "none", 4) + P("M24,26 L44,26 L40,34 L28,34 Z", "#c9c3bd") + "".join(L(x, 40, x - 2, 50, 3) for x in (28, 34, 40)) + "".join(C(x - 3, 56, 2, "#7fb2f0", sw=1.5) for x in (28, 34, 40))
ICONS["finger"] = lambda: P("M26,58 L22,38 Q18,32 24,32 L26,34 L26,12 Q26,7 31,7 Q36,7 36,12 L36,28 L46,30 Q52,32 50,40 L46,58 Z", "#ffd9b8")
ICONS["play"] = lambda: P("M20,12 L50,32 L20,52 Z", "#7ad17a")
ICONS["stop"] = lambda: R(16, 16, 32, 32, "#ff6b81", 5)
ICONS["record"] = lambda: C(32, 32, 20, "#ff6b81") + HL(25, 25, 4)
ICONS["listen"] = lambda: P("M12,24 L22,24 L34,12 L34,52 L22,40 L12,40 Z", "#9ad0f5") + P("M42,22 Q50,32 42,42 M48,16 Q60,32 48,48", "none")
ICONS["sell"] = lambda: P("M8,30 L30,8 L54,8 L56,10 L56,34 L34,56 Z", "#ffd24d") + C(46, 18, 4, "#fff") + P("M24,34 L36,22", "none")
ICONS["leash"] = lambda: P("M10,54 Q14,20 40,14", "none", 4) + C(44, 14, 7, "#ff8a5c") + R(6, 48, 14, 10, "#c99a6a", 4)
ICONS["home_go"] = lambda: P("M8,32 L32,10 L56,32", "none", 5) + R(16, 30, 32, 24, "#ffe9b8", 2) + R(28, 40, 9, 14, "#c99a6a", 2)
ICONS["accessibility"] = lambda: C(32, 12, 6, "#7fb2f0") + P("M12,22 L52,22 M32,22 L32,38 L22,56 M32,38 L42,56", "none", 5)
ICONS["brush"] = lambda: R(8, 26, 32, 14, "#c99a6a", 6) + "".join(L(12 + i * 6, 40, 12 + i * 6, 50, 3) for i in range(5)) + R(38, 29, 20, 8, "#e8a56a", 4)
ICONS["tug"] = lambda: P("M6,32 Q20,22 32,32 Q44,42 58,32", "none", 7) + P("M6,32 Q20,22 32,32 Q44,42 58,32", "none", 3, sc="#e8d39a") + C(8, 32, 6, "#e8d39a") + C(56, 32, 6, "#e8d39a")
ICONS["cuddle"] = lambda: heart(32, 36, 14, "#ff8fb1") + P("M8,46 Q14,30 24,36 M56,46 Q50,30 40,36", "none", 4)
ICONS["rest"] = lambda: P("M42,10 A20,20 0 1 0 54,40 A16,16 0 0 1 42,10 Z", "#ffe680") + P("M14,14 L22,14 L14,22 L22,22", "none", 2.5)
ICONS["photo_mode"] = ICONS["camera"]
ICONS["route"] = lambda: P("M12,52 Q12,36 28,36 Q44,36 44,22 Q44,12 52,12", "none", 4) + C(12, 52, 5, "#7ad17a") + P("M48,4 L58,4 L54,10 L58,16 L48,16 Z", "#ff6b81", 2)
ICONS["speed"] = lambda: P("M8,44 A24,24 0 0 1 56,44", "#e6f4ff") + L(32, 44, 46, 26, 4) + C(32, 44, 4, INK)
ICONS["text_size"] = lambda: P("M8,50 L20,16 L32,50 M12,38 L28,38", "none", 4) + P("M36,50 L46,26 L56,50 M39,42 L53,42", "none", 3)
ICONS["motion"] = lambda: C(36, 32, 14, "#9ad0f5") + L(6, 24, 18, 24) + L(4, 32, 18, 32) + L(6, 40, 18, 40)

# ------------------------------------------------------------------ actions / menus
ICONS["feed"] = lambda: bowl("#a86b3c") + C(26, 30, 3, "#c98a50", sw=1.5) + C(34, 29, 3, "#c98a50", sw=1.5) + C(40, 31, 3, "#c98a50", sw=1.5)
ICONS["water"] = lambda: P("M32,6 Q50,30 50,40 A18,18 0 0 1 14,40 Q14,30 32,6 Z", "#7fc4f5") + HL(24, 38, 4)
ICONS["wash"] = lambda: P("M6,30 L58,30 L54,48 Q52,54 46,54 L18,54 Q12,54 10,48 Z", "#9ad0f5") + C(20, 22, 6, "#fff") + C(30, 16, 5, "#fff") + C(40, 22, 7, "#fff") + L(14, 54, 12, 60) + L(50, 54, 52, 60)
ICONS["treat"] = lambda: bone(32, 32, 30)
ICONS["throw"] = lambda: C(32, 34, 18, "#d7f04a") + P("M16,26 Q32,36 48,26 M16,42 Q32,32 48,42", "none", 2.5) + P("M48,8 L58,4 M52,14 L60,12", "none", 2.5)
ICONS["call"] = lambda: P("M8,26 L22,26 L46,12 L46,52 L22,38 L8,38 Z", "#ff9f7f") + R(14, 38, 8, 14, "#ff9f7f", 3) + P("M52,22 Q58,32 52,42", "none")
ICONS["training"] = lambda: P("M4,24 L32,12 L60,24 L32,36 Z", "#6a8fd0") + P("M16,30 L16,44 Q32,54 48,44 L48,30", "#8aa9e0") + L(56, 26, 56, 42) + C(56, 44, 3, "#ffd24d", sw=2)
ICONS["activities"] = lambda: C(32, 32, 24, "#ff8a5c") + C(32, 32, 16, "#fff") + C(32, 32, 8, "#ff8a5c")
ICONS["contests"] = ICONS["trophy"]
ICONS["shop"] = lambda: P("M10,22 L54,22 L50,56 L14,56 Z", "#b9a3f0") + P("M22,26 L22,16 A10,10 0 0 1 42,16 L42,26", "none") + HL(20, 30, 3)
ICONS["inventory"] = lambda: R(12, 16, 40, 40, "#e8a56a", 9) + R(20, 8, 24, 10, "none", 5) + R(18, 30, 28, 14, "#f3c08f", 4) + L(32, 30, 32, 36)
ICONS["more"] = ICONS["menu"]
ICONS["places"] = ICONS["map"]
ICONS["pets"] = ICONS["paw"]
ICONS["voice"] = ICONS["mic"]
ICONS["settings"] = ICONS["gear"]
ICONS["daily"] = ICONS["calendar"]
ICONS["achievements"] = ICONS["medal"]
ICONS["walk"] = ICONS["leash"]
ICONS["search"] = lambda: C(26, 26, 16, "#e6f4ff") + L(38, 38, 56, 56, 7) + paw(26, 27, 10, "#e8a56a")
ICONS["agility"] = lambda: L(12, 20, 12, 56, 4) + L(52, 20, 52, 56, 4) + R(8, 30, 48, 6, "#ff6b81", 3) + R(8, 44, 48, 6, "#fff", 3)
ICONS["obedience"] = ICONS["training"]
ICONS["tricks"] = lambda: star(32, 32, 24, "#ffd24d") + star(52, 12, 6, "#fff") + star(12, 50, 5, "#fff")
ICONS["fetch"] = ICONS["throw"]
ICONS["competition"] = ICONS["trophy"]
ICONS["photo"] = ICONS["camera"]

# ------------------------------------------------------------------ besoins
ICONS["hunger"] = ICONS["feed"]
ICONS["thirst"] = ICONS["water"]
ICONS["clean"] = lambda: C(22, 38, 13, "#d8f0ff") + C(40, 26, 10, "#d8f0ff") + C(44, 46, 7, "#d8f0ff") + HL(17, 33, 3) + HL(36, 22, 2.5)
ICONS["energy"] = lambda: P("M36,4 L14,36 L30,36 L26,60 L50,26 L34,26 Z", "#ffd24d")
ICONS["mood"] = lambda: C(32, 32, 24, "#ffd86b") + C(23, 27, 3, INK) + C(41, 27, 3, INK) + P("M20,38 Q32,50 44,38", "none", 3.5)
ICONS["health"] = lambda: heart(32, 34, 18, "#ff6b81") + R(28, 20, 8, 22, "#fff", 2, sw=2) + R(21, 27, 22, 8, "#fff", 2, sw=2)
ICONS["outside"] = lambda: R(28, 38, 8, 18, "#b5835a", 2) + C(32, 26, 18, "#7ac07a") + C(22, 32, 9, "#8ccc7f") + C(42, 32, 9, "#8ccc7f")
ICONS["affection"] = ICONS["relation"]

# ------------------------------------------------------------------ objets
ICONS["kibble"] = ICONS["feed"]
ICONS["pate"] = lambda: R(12, 18, 40, 34, "#d0d7e0", 6) + E(32, 18, 20, 6, "#e9edf2") + R(12, 28, 40, 14, "#ff9f7f", 0) + heart(32, 36, 5, "#fff")
ICONS["fish"] = lambda: P("M8,32 Q28,10 46,32 Q28,54 8,32 Z", "#9ad0f5") + P("M44,32 L58,20 L58,44 Z", "#9ad0f5") + C(20, 29, 2.5, INK)
ICONS["veggie"] = lambda: P("M16,52 L46,22 Q52,20 52,26 L22,56 Q14,60 16,52 Z", "#ff9f40") + P("M48,20 Q46,6 56,8 M50,22 Q60,14 62,22", "#7ac07a", 3)
ICONS["biscuit"] = ICONS["treat"]
ICONS["chew"] = lambda: R(10, 26, 44, 12, "#d9a46a", 6, rot=-30) + L(20, 40, 26, 30, 2) + L(30, 34, 36, 24, 2) + L(40, 28, 46, 18, 2)
ICONS["cheese"] = lambda: P("M8,44 L50,16 L56,44 Z", "#ffd24d") + C(30, 38, 4, "#ffc21a", sw=2) + C(44, 32, 3, "#ffc21a", sw=2)
ICONS["cookie"] = lambda: C(32, 32, 22, "#e0a066") + C(24, 26, 3, "#7a4a2a", sw=1.5) + C(38, 22, 3, "#7a4a2a", sw=1.5) + C(36, 38, 3, "#7a4a2a", sw=1.5) + C(24, 40, 2.5, "#7a4a2a", sw=1.5)
ICONS["shampoo"] = lambda: R(18, 20, 28, 36, "#ffb3cf", 8) + R(26, 10, 12, 10, "#fff", 2) + R(36, 8, 14, 5, "#fff", 2) + C(32, 38, 6, "#fff")
ICONS["vitamins"] = lambda: R(12, 24, 40, 16, "#ff6b81", 8, rot=-35) + P("M24,46 L40,18", "none") + HL(22, 34, 2.5)
ICONS["ball"] = lambda: C(32, 32, 20, "#ff5a5a") + HL(25, 25, 5)
ICONS["tennis"] = lambda: C(32, 32, 20, "#d7f04a") + P("M14,24 Q32,36 50,24 M14,40 Q32,28 50,40", "none", 2.5)
ICONS["disc"] = lambda: E(32, 34, 26, 12, "#4f9bf0") + E(32, 31, 16, 6, "#7fb8f5", sw=2)
ICONS["rope"] = lambda: P("M10,32 Q22,20 32,32 Q42,44 54,32", "none", 8) + P("M10,32 Q22,20 32,32 Q42,44 54,32", "none", 4, sc="#e8d39a") + C(10, 32, 7, "#e8d39a") + C(54, 32, 7, "#e8d39a")
ICONS["plush"] = lambda: E(30, 40, 20, 14, "#ffd84d") + C(42, 24, 11, "#ffd84d") + P("M50,24 L60,27 L50,30 Z", "#ff9f40", 2) + C(44, 22, 2, INK)
ICONS["acc_none"] = lambda: C(32, 32, 22, "#f2eee9") + L(18, 46, 46, 18, 4)
ICONS["bandana"] = lambda: P("M8,20 L56,20 L32,52 Z", "#ff5a5a") + C(24, 28, 2.5, "#fff", sw=1) + C(38, 28, 2.5, "#fff", sw=1) + C(31, 38, 2.5, "#fff", sw=1)
ICONS["bow"] = ICONS["style"]
ICONS["hat"] = lambda: E(32, 42, 28, 9, "#ecd38a") + P("M18,40 Q18,16 32,16 Q46,16 46,40", "#ecd38a") + R(18, 32, 28, 6, "#ff6b81", 1)
ICONS["crown"] = lambda: P("M8,48 L12,18 L24,32 L32,12 L40,32 L52,18 L56,48 Z", "#ffd24d") + C(32, 40, 4, "#ff5a7a", sw=2)
ICONS["glasses"] = lambda: R(6, 24, 22, 16, "#2c2c35", 7) + R(36, 24, 22, 16, "#2c2c35", 7) + P("M28,30 Q32,26 36,30", "none") + HL(12, 29, 2)
ICONS["scarf"] = lambda: P("M8,24 Q32,36 56,24 L56,32 Q32,44 8,32 Z", "#4f86d6") + R(36, 32, 10, 24, "#4f86d6", 3) + L(38, 52, 38, 58, 2) + L(44, 52, 44, 58, 2)
ICONS["rug"] = lambda: E(32, 36, 26, 14, "#e08a6a") + E(32, 36, 16, 8, "#f3b49a")
ICONS["bed"] = lambda: E(32, 40, 26, 14, "#b97a50") + E(32, 38, 18, 8, "#f3e6d0")
ICONS["cloud_bed"] = lambda: C(20, 38, 12, "#e3e8ff") + C(34, 32, 14, "#e3e8ff") + C(46, 40, 10, "#e3e8ff") + R(12, 40, 40, 12, "#e3e8ff", 6, sw=0)
ICONS["royal_bed"] = lambda: R(8, 30, 48, 18, "#a03f72", 5) + R(10, 14, 44, 16, "#e0b44a", 4) + C(32, 22, 4, "#ff5a7a", sw=2)
ICONS["fern"] = lambda: R(24, 42, 16, 14, "#e08a5a", 3) + P("M32,42 Q22,20 12,18 M32,42 Q32,16 32,8 M32,42 Q42,20 52,18", "none", 4, sc="#4f9a4f")
ICONS["cactus"] = lambda: R(24, 46, 16, 12, "#e08a5a", 3) + R(26, 12, 12, 36, "#6ab36a", 6) + P("M26,30 L18,30 L18,20 M38,26 L46,26 L46,16", "none", 4)
ICONS["flowers"] = lambda: R(24, 42, 16, 14, "#9ad0f5", 3) + L(32, 42, 24, 24) + L(32, 42, 40, 22) + L(32, 42, 32, 18) + C(24, 22, 6, "#ff8fb1") + C(40, 20, 6, "#ffd24d") + C(32, 14, 6, "#b9a3f0")
ICONS["lamp"] = lambda: P("M20,26 L44,26 L38,8 L26,8 Z", "#ffe680") + L(32, 26, 32, 52) + R(22, 52, 20, 5, "#c9c3bd", 2)
ICONS["star_lamp"] = lambda: ICONS["lamp"]() + star(32, 16, 6, "#fff")
ICONS["sofa"] = ICONS["deco"]
ICONS["paint"] = lambda: R(10, 10, 38, 16, "#ffd24d", 5) + P("M48,18 L54,18 L54,30 L32,34 L32,40", "none") + R(28, 40, 8, 18, "#c99a6a", 2)
ICONS["frame"] = lambda: R(10, 12, 44, 40, "#c99a6a", 3) + R(16, 18, 32, 28, "#e6f4ff", 1) + C(40, 26, 4, "#ffd24d", sw=2) + P("M16,46 L28,32 L38,42 L48,34 L48,46 Z", "#7ac07a", 2)
ICONS["toybox"] = lambda: R(10, 26, 44, 28, "#9ad0f5", 4) + R(8, 20, 48, 9, "#ff8a5c", 3) + C(22, 18, 6, "#ff5a5a")
ICONS["collar"] = lambda: E(32, 32, 22, 16, "none", sw=8) + E(32, 32, 22, 16, "none", sw=4, sc="#ff5a5a") + C(32, 50, 6, "#ffd24d")

# ------------------------------------------------------------------ lieux
ICONS["house"] = lambda: P("M6,30 L32,8 L58,30", "#ff8a5c") + R(14, 28, 36, 28, "#ffe9b8", 2) + R(28, 38, 10, 18, "#c99a6a", 2) + R(18, 34, 8, 8, "#9ad0f5", 1)
ICONS["garden"] = lambda: L(32, 34, 32, 58, 4) + "".join(C(32 + math.cos(a) * 10, 22 + math.sin(a) * 10, 7, "#ffd24d") for a in [i * math.pi / 3 for i in range(6)]) + C(32, 22, 7, "#b5835a") + P("M32,48 Q20,40 18,48", "#7ac07a", 2.5)
ICONS["park"] = ICONS["outside"]
ICONS["beach"] = lambda: P("M6,56 Q32,46 58,56 Z", "#f5d99a") + L(30, 16, 36, 54) + P("M8,24 Q30,0 54,22 Z", "#ff6b81") + L(30, 24, 30, 24)
ICONS["forest"] = lambda: P("M18,8 L30,32 L6,32 Z", "#4f9a4f") + P("M18,22 L32,46 L4,46 Z", "#5aab5a") + R(15, 46, 6, 10, "#b5835a", 1) + P("M44,14 L58,40 L30,40 Z", "#6ab36a") + R(41, 40, 6, 14, "#b5835a", 1)
ICONS["center"] = lambda: P("M6,54 L6,30 Q32,14 58,30 L58,54 Z", "#ffe9b8") + L(20, 54, 20, 34) + L(44, 54, 44, 34) + R(16, 40, 32, 4, "#ff6b81", 2) + L(32, 22, 32, 8) + P("M32,8 L44,12 L32,16", "#7ad17a", 2)
ICONS["shelter"] = lambda: ICONS["house"]() + heart(32, 20, 5, "#ff6b81")
ICONS["field"] = ICONS["center"]

# ------------------------------------------------------------------ trouvailles
ICONS["daisy"] = lambda: "".join(E(32 + math.cos(a) * 12, 32 + math.sin(a) * 12, 8, 4.5, "#fff", math.degrees(a)) for a in [i * math.pi / 4 for i in range(8)]) + C(32, 32, 7, "#ffd24d")
ICONS["snail"] = lambda: C(36, 30, 14, "#e0a066") + P("M36,30 m-6,0 a6,6 0 1 1 12,0 a10,10 0 1 1 -20,0", "none", 2.5) + P("M6,46 L52,46 Q56,46 54,42 L48,40", "#ffd9b8") + L(12, 44, 8, 30, 2.5) + L(16, 44, 16, 30, 2.5)
ICONS["leaf"] = lambda: P("M10,54 Q8,14 54,10 Q50,52 10,54 Z", "#e8a040") + P("M10,54 L44,20", "none", 2.5)
ICONS["worm"] = lambda: P("M8,40 Q16,28 24,40 Q32,52 40,40 Q48,28 56,36", "none", 9, sc="#ff9fb0") + C(56, 36, 2, INK)
ICONS["strawberry"] = lambda: P("M32,56 Q10,40 14,24 Q32,16 50,24 Q54,40 32,56 Z", "#ff5a5a") + P("M20,22 L32,10 L44,22 Z", "#7ac07a", 2.5) + C(26, 32, 1.5, "#ffe680", sw=0) + C(38, 34, 1.5, "#ffe680", sw=0) + C(32, 42, 1.5, "#ffe680", sw=0)
ICONS["acorn"] = lambda: E(32, 40, 13, 16, "#e0a066") + P("M16,30 Q32,14 48,30 Z", "#8a5a3a") + L(32, 18, 34, 10)
ICONS["feather"] = lambda: P("M12,54 Q14,20 50,8 Q48,40 12,54 Z", "#bfe3ff") + L(12, 54, 40, 20, 2.5)
ICONS["mushroom"] = lambda: P("M8,32 Q32,0 56,32 Z", "#ff5a5a") + R(24, 32, 16, 22, "#fff3e0", 5) + C(22, 22, 3, "#fff", sw=1) + C(38, 18, 3, "#fff", sw=1)
ICONS["butterfly"] = lambda: E(20, 24, 12, 14, "#b9a3f0", -20) + E(44, 24, 12, 14, "#b9a3f0", 20) + E(22, 44, 9, 10, "#ffb3cf") + E(42, 44, 9, 10, "#ffb3cf") + R(29, 16, 6, 36, INK, 3, sw=0)
ICONS["stick"] = lambda: P("M8,50 L56,18", "none", 8) + P("M8,50 L56,18", "none", 4, sc="#c99a6a") + P("M34,34 L40,24", "none", 4)
ICONS["maple"] = lambda: star(32, 30, 24, "#ff7a3a", 5, 0.55) + L(32, 34, 32, 60)
ICONS["shell"] = lambda: P("M32,52 L8,30 Q32,0 56,30 Z", "#ffc9b8") + L(32, 52, 20, 22, 2) + L(32, 52, 32, 16, 2) + L(32, 52, 44, 22, 2)
ICONS["starfish"] = lambda: star(32, 34, 26, "#ff9f40", 5, 0.5) + C(32, 32, 2, "#fff", sw=0)
ICONS["crab"] = lambda: E(32, 38, 18, 12, "#ff6b5a") + C(14, 20, 7, "#ff6b5a") + C(50, 20, 7, "#ff6b5a") + L(20, 30, 16, 26) + L(44, 30, 48, 26) + C(27, 34, 2, INK) + C(37, 34, 2, INK)
ICONS["coral"] = lambda: P("M32,58 L32,30 M32,40 L20,24 M32,36 L44,18 M20,24 L16,14 M44,18 L50,12", "none", 7, sc="#ff8fb1")
ICONS["pebble"] = lambda: E(32, 36, 22, 15, "#c9c3bd") + HL(24, 30, 3)
ICONS["driftwood"] = lambda: R(6, 26, 52, 12, "#d8c3a5", 6, rot=-10) + L(18, 32, 30, 30, 2) + L(36, 30, 46, 28, 2)

ICONS["pinecone"] = lambda: E(32, 36, 14, 20, "#a8703f") + "".join(P(f"M{20 + (i % 3) * 8},{24 + (i // 3) * 9} q4,5 8,0", "none", 2.5) for i in range(9)) + R(29, 8, 6, 8, "#6a8a3a", 2)
ICONS["marble"] = lambda: C(32, 32, 20, "#7fc4f5") + P("M18,36 Q30,22 46,30", "none", 3, sc="#ff6b81") + HL(25, 24, 5)
ICONS["sock"] = lambda: P("M22,8 L42,8 L42,36 L50,44 Q54,52 46,56 L24,56 Q14,56 18,44 L22,38 Z", "#ffb3cf") + R(22, 8, 20, 8, "#fff", 2) + P("M24,24 L40,24 M24,32 L40,32", "none", 2.5, sc="#ff6b9a")
ICONS["coin_old"] = lambda: C(32, 32, 22, "#d8b25a") + C(32, 32, 15, "#c49a3e", sw=2) + P("M26,26 L38,26 L38,38 L26,38 Z", "none", 2.5) + HL(23, 23, 3)
ICONS["key_old"] = lambda: C(18, 32, 11, "#d8b25a") + C(18, 32, 4, "#fbf3e2", sw=2) + R(27, 28, 30, 8, "#d8b25a", 2) + R(46, 36, 5, 9, "#d8b25a", 1) + R(38, 36, 5, 7, "#d8b25a", 1)
ICONS["bottle"] = lambda: R(14, 22, 38, 22, "#bfe8d0", 10, rot=-25) + R(46, 10, 8, 10, "#c99a6a", 2, rot=-25) + R(22, 28, 18, 9, "#fff8e0", 2, rot=-25) + HL(20, 30, 3)
ICONS["gem"] = lambda: P("M14,24 L24,12 L40,12 L50,24 L32,54 Z", "#b9a3f0") + P("M14,24 L50,24 M24,12 L32,24 L40,12 M32,24 L32,54", "none", 2) + HL(26, 18, 3)
ICONS["bone_old"] = lambda: bone(32, 32, 30, "#e0cfa8") + P("M22,26 L26,30 M36,34 L40,36", "none", 2)
ICONS["medal_old"] = lambda: P("M22,6 L30,28 M42,6 L34,28", "none", 6) + C(32, 40, 15, "#c49a3e") + star(32, 40, 8, "#a87d2a") + P("M20,52 L24,48", "none", 2)
ICONS["pearl"] = lambda: P("M8,40 Q32,10 56,40 Q32,58 8,40 Z", "#d8c3a5") + C(32, 38, 10, "#fbf6f0") + HL(28, 34, 3)
ICONS["leaves_pile"] = lambda: E(32, 42, 24, 12, "#c8792f") + E(24, 36, 10, 6, "#e8a040", -20) + E(40, 34, 10, 6, "#d65a2a", 25) + E(32, 30, 9, 5, "#e8c040", 5)
ICONS["clue"] = lambda: E(32, 36, 20, 14, "#f5d4b8") + C(32, 30, 6, INK) + P("M10,16 Q16,10 22,16 M42,16 Q48,10 54,16 M26,8 Q32,2 38,8", "none", 3, sc="#7fb2f0")
ICONS["daily_star"] = lambda: C(32, 32, 24, "#ffe9b8") + star(32, 33, 16, "#ffb91a")

# ------------------------------------------------------------------ émotions (bulles au-dessus de l'animal)
def bubble(inner):
    return P("M10,10 L54,10 Q58,10 58,14 L58,42 Q58,46 54,46 L30,46 L20,56 L22,46 L10,46 Q6,46 6,42 L6,14 Q6,10 10,10 Z", "#fff") + inner
ICONS["emo_heart"] = lambda: bubble(heart(32, 30, 11, "#ff6b81"))
ICONS["emo_zzz"] = lambda: bubble(P("M16,18 L28,18 L16,32 L28,32 M34,24 L44,24 L34,36 L44,36", "none", 3.5))
ICONS["emo_question"] = lambda: bubble(P("M24,22 Q24,14 32,14 Q40,14 40,22 Q40,28 32,30 L32,34", "none", 4) + C(32, 40, 2.5, INK))
ICONS["emo_exclaim"] = lambda: bubble(L(32, 15, 32, 31, 5) + C(32, 39, 3, INK))
ICONS["emo_yum"] = lambda: bubble(C(32, 28, 12, "#ffd86b", sw=2.5) + P("M25,30 Q32,38 39,30", "none", 2.5) + E(35, 34, 3, 4, "#ff8fb1", sw=1.5))
ICONS["emo_sad"] = lambda: bubble(C(32, 28, 12, "#bcd6f0", sw=2.5) + P("M25,34 Q32,28 39,34", "none", 2.5) + C(27, 25, 1.5, INK) + C(37, 25, 1.5, INK))
ICONS["emo_angry"] = lambda: bubble(P("M20,16 L28,24 M28,16 L20,24 M36,16 L44,24 M44,16 L36,24", "none", 3, sc="#e04a4a") + P("M24,36 Q32,30 40,36", "none", 3))
ICONS["emo_sparkle"] = lambda: bubble(star(32, 28, 13, "#ffe680", 4, 0.3))
ICONS["emo_star"] = lambda: bubble(star(32, 28, 13, "#ffd24d"))
ICONS["emo_drop"] = lambda: bubble(P("M32,14 Q42,28 42,32 A10,10 0 0 1 22,32 Q22,28 32,14 Z", "#7fc4f5", 2.5))
ICONS["emo_food"] = lambda: bubble(bone(32, 28, 18, rot=-20))
ICONS["emo_flag"] = lambda: bubble(L(24, 14, 24, 40) + P("M24,15 L42,15 L37,22 L42,29 L24,29 Z", "#7ad17a", 2.5))
ICONS["emo_cold"] = lambda: bubble("".join(L(32, 28, 32 + math.cos(a) * 12, 28 + math.sin(a) * 12, 3, sc="#6aa9e0") for a in [i * math.pi / 3 for i in range(6)]))
ICONS["emo_warm"] = lambda: bubble(P("M24,38 Q20,30 26,24 Q28,32 32,30 Q30,20 36,16 Q38,26 42,28 Q44,36 38,38 Z", "#ffb04a", 2.5))
ICONS["emo_hot"] = lambda: bubble(P("M24,40 Q16,30 24,20 Q26,30 30,28 Q26,16 34,10 Q36,22 42,24 Q48,34 40,40 Z", "#ff5a3a", 2.5))
ICONS["emo_playful"] = lambda: bubble(C(32, 28, 12, "#ffd86b", sw=2.5) + C(27, 25, 1.5, INK) + P("M35,24 L39,26", "none", 2) + P("M25,31 Q32,38 39,31 Z", "#ff8fb1", 2))
ICONS["emo_bug"] = lambda: bubble(E(32, 30, 8, 10, "#7a5a3a", sw=2.5) + L(22, 24, 42, 36, 2) + L(42, 24, 22, 36, 2))
ICONS["emo_sleepy"] = lambda: bubble(P("M22,26 Q26,30 30,26 M34,26 Q38,30 42,26", "none", 2.5) + E(32, 36, 4, 3, "#fff", sw=2))
ICONS["emo_paw"] = lambda: bubble(paw(32, 29, 13, "#e8a56a"))
ICONS["emo_note"] = lambda: bubble(P("M26,38 L26,16 L42,12 L42,32", "none", 3) + E(23, 38, 5, 4, INK, sw=0) + E(39, 33, 5, 4, INK, sw=0))
ICONS["emo_medal1"] = lambda: bubble(C(32, 28, 12, "#ffd24d", sw=2.5) + P("M30,22 L33,20 L33,35", "none", 2.5))
ICONS["emo_medal2"] = lambda: bubble(C(32, 28, 12, "#d6dbe3", sw=2.5) + P("M28,24 Q32,18 36,24 L28,34 L37,34", "none", 2.5))
ICONS["emo_medal3"] = lambda: bubble(C(32, 28, 12, "#e0a066", sw=2.5) + P("M28,22 L36,22 L31,27 Q37,27 36,31 Q33,36 28,33", "none", 2.5))

# ------------------------------------------------------------------ agilité (obstacles)
ICONS["hurdle"] = ICONS["agility"]
ICONS["tunnel"] = lambda: P("M8,54 L8,36 A24,24 0 0 1 56,36 L56,54 Z", "#6a8fd0") + P("M18,54 L18,38 A14,14 0 0 1 46,38 L46,54 Z", "#2c2c35") + L(4, 54, 60, 54)
ICONS["weave"] = lambda: "".join(L(12 + i * 13, 14, 12 + i * 13, 54, 5, "#ff6b81" if i % 2 else None) for i in range(4)) + P("M6,34 Q18,22 32,34 Q46,46 58,34", "none", 3, "#7fb2f0")
ICONS["hoop"] = lambda: L(32, 44, 32, 58, 5) + L(20, 58, 44, 58, 4) + E(32, 28, 18, 18, "none", 0, 7) + E(32, 28, 18, 18, "none", 0, 3.5, "#ff6b81")
ICONS["platform"] = lambda: R(8, 30, 48, 14, "#e8a56a", 3) + R(8, 24, 48, 8, "#f3c08f", 3) + L(14, 44, 14, 56, 4) + L(50, 44, 50, 56, 4)
ICONS["walkway"] = lambda: P("M4,50 L20,22 L44,22 L60,50", "none", 5) + R(18, 18, 28, 8, "#e8a56a", 2) + L(26, 26, 26, 50, 3) + L(38, 26, 38, 50, 3)
ICONS["stop_zone"] = lambda: P("M22,8 L42,8 L56,22 L56,42 L42,56 L22,56 L8,42 L8,22 Z", "#ff5a5a") + R(16, 28, 32, 8, "#fff", 2, sw=0)
ICONS["combo"] = lambda: L(8, 24, 8, 56, 4) + L(28, 24, 28, 56, 4) + R(6, 34, 24, 5, "#ff6b81", 2) + E(46, 36, 11, 11, "none", 0, 5, "#7fb2f0") + L(46, 47, 46, 58, 4)

# Variantes teintées (une icône par objet)
TINTS = {
    "collar": ("#ff5a5a", {"collar_red": "#e04848", "collar_blue": "#3a73e0", "collar_green": "#4cbf5a", "collar_pink": "#f07fb0", "collar_gold": "#f2c640", "collar_purple": "#8c50cc"}),
    "paint": ("#ffd24d", {"wall_cream": "#f6e8cc", "wall_mint": "#bfe8d0", "wall_lilac": "#dccff2", "wall_peach": "#fcd2bb"}),
    "rug": ("#e08a6a", {"rug_round": "#e08a6a", "rug_blue": "#5a8ad6", "rug_green": "#73b873"}),
    "deco": ("#ff9f7f", {"sofa_coral": "#ff9f7f", "sofa_teal": "#3f9a9a", "sofa_mustard": "#e0b43a"}),
    "frame": ("#e6f4ff", {"frame_sun": "#ffe9b0", "frame_sea": "#bfe0ff"}),
}

def main():
    os.makedirs(OUT, exist_ok=True)
    for base, (col, variants) in TINTS.items():
        for name, c in variants.items():
            fn = ICONS[base]
            ICONS[name] = (lambda fn=fn, col=col, c=c: fn().replace(col, c))
    for f in os.listdir(OUT):
        if f.endswith(".svg"):
            os.remove(os.path.join(OUT, f))
    for name, fn in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg(fn()))
    print(len(ICONS), "icônes")

if __name__ == "__main__":
    main()
