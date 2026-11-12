#!/usr/bin/env python3
"""Habillage de l'interface : boutons, panneaux, bandeaux et jauges en « 9 tranches » (étirables).
Les boutons et jauges sont en niveaux de gris : le jeu les teinte à la couleur voulue.
Usage : python3 tools/gen_ui_skin.py -> assets/ui/skin/*.png"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "skin")
K = 3   # suréchantillonnage

def rr(size, box, radius, fill):
    im = Image.new("L", size, 0)
    ImageDraw.Draw(im).rounded_rectangle(box, radius, fill=fill)
    return im

def vgrad(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None]
    a = np.array(top, float)[None, None, :] * (1 - t[..., None]) + np.array(bottom, float)[None, None, :] * t[..., None]
    return np.repeat(a, w, axis=1)

def compose(w, h, layers):
    """layers : liste de (image RGBA numpy 0..1)."""
    out = np.zeros((h, w, 4))
    for l in layers:
        a = l[..., 3:4]
        out[..., :3] = out[..., :3] * (1 - a) + l[..., :3] * a
        out[..., 3:4] = out[..., 3:4] + a * (1 - out[..., 3:4])
    return out

def save(name, arr, w, h):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"))

def layer(mask, rgb):
    m = np.asarray(mask, float) / 255.0
    if isinstance(rgb, np.ndarray):
        return np.concatenate([rgb, m[..., None]], -1)
    return np.concatenate([np.broadcast_to(np.array(rgb, float), m.shape + (3,)), m[..., None]], -1)

def button(name, pressed=False, radius=30):
    w, h = 112, 120
    W, H = w * K, h * K
    r = radius * K
    pad = 8 * K
    top = pad if not pressed else pad + 5 * K
    body_h = 92 * K
    layers = []
    if not pressed:
        sh = rr((W, H), (pad, top + 8 * K, W - pad, top + body_h + 12 * K), r, 150).filter(ImageFilter.GaussianBlur(5 * K))
        layers.append(layer(sh, (0.25, 0.14, 0.06)))
        lip = rr((W, H), (pad, top + 7 * K, W - pad, top + body_h + 7 * K), r, 255)
        layers.append(layer(lip, (0.66, 0.66, 0.66)))
    body = rr((W, H), (pad, top, W - pad, top + body_h), r, 255)
    g = vgrad(W, H, (1.0, 1.0, 1.0), (0.84, 0.84, 0.84)) if not pressed else vgrad(W, H, (0.80, 0.80, 0.80), (0.88, 0.88, 0.88))
    layers.append(layer(body, g))
    # reflet doux en haut et fin liseré clair
    gl = rr((W, H), (pad + 5 * K, top + 4 * K, W - pad - 5 * K, top + body_h * 0.46), r - 6 * K, 70 if not pressed else 25).filter(ImageFilter.GaussianBlur(1.2 * K))
    layers.append(layer(gl, (1.0, 1.0, 1.0)))
    edge = Image.new("L", (W, H), 0)
    ImageDraw.Draw(edge).rounded_rectangle((pad, top, W - pad, top + body_h), r, outline=110, width=int(1.4 * K))
    layers.append(layer(edge, (0.55, 0.55, 0.55)))
    save(name, compose(W, H, layers), w, h)

def panel(name, radius=34, ribbon=False):
    w, h = 144, 144
    W, H = w * K, h * K
    r = radius * K
    pad = 10 * K
    layers = []
    sh = rr((W, H), (pad, pad + 6 * K, W - pad, H - pad + 6 * K), r, 120).filter(ImageFilter.GaussianBlur(6 * K))
    layers.append(layer(sh, (0.25, 0.14, 0.06)))
    outer = rr((W, H), (pad, pad, W - pad, H - pad), r, 255)
    layers.append(layer(outer, (0.80, 0.72, 0.62)))
    inner = rr((W, H), (pad + 3 * K, pad + 3 * K, W - pad - 3 * K, H - pad - 3 * K), r - 3 * K, 255)
    layers.append(layer(inner, vgrad(W, H, (1.0, 1.0, 1.0), (0.955, 0.945, 0.93))))
    line = Image.new("L", (W, H), 0)
    ImageDraw.Draw(line).rounded_rectangle((pad + 6 * K, pad + 6 * K, W - pad - 6 * K, H - pad - 6 * K), r - 6 * K, outline=140, width=int(1.2 * K))
    layers.append(layer(line, (1.0, 1.0, 1.0)))
    save(name, compose(W, H, layers), w, h)

def header():
    """Bandeau de titre : dégradé, reflets en biais, liseré bas (niveaux de gris, teinté en jeu)."""
    w, h = 144, 112
    W, H = w * K, h * K
    r = 30 * K
    body = rr((W, H), (0, 0, W - 1, H - 1), r, 255)
    g = vgrad(W, H, (1.0, 1.0, 1.0), (0.82, 0.82, 0.82))
    y, x = np.mgrid[0:H, 0:W]
    stripes = ((x + y) // (14 * K)) % 2
    g = g * (1.0 - 0.045 * stripes[..., None])
    layers = [layer(body, g)]
    gl = rr((W, H), (6 * K, 5 * K, W - 6 * K, int(H * 0.42)), r - 6 * K, 60).filter(ImageFilter.GaussianBlur(1.5 * K))
    layers.append(layer(gl, (1.0, 1.0, 1.0)))
    edge = Image.new("L", (W, H), 0)
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, W - 1, H - 1), r, outline=150, width=int(2 * K))
    layers.append(layer(edge, (0.62, 0.62, 0.62)))
    save("header", compose(W, H, layers), w, h)

def bar(name, fill):
    w, h = 64, 32
    W, H = w * K, h * K
    body = rr((W, H), (0, 0, W - 1, H - 1), H // 2, 255)
    if fill:
        layers = [layer(body, vgrad(W, H, (1.0, 1.0, 1.0), (0.80, 0.80, 0.80)))]
        gl = rr((W, H), (5 * K, 3 * K, W - 5 * K, int(H * 0.45)), H // 4, 110).filter(ImageFilter.GaussianBlur(K))
        layers.append(layer(gl, (1.0, 1.0, 1.0)))
    else:
        layers = [layer(body, vgrad(W, H, (0.80, 0.76, 0.70), (0.90, 0.87, 0.82)))]
        edge = Image.new("L", (W, H), 0)
        ImageDraw.Draw(edge).rounded_rectangle((0, 0, W - 1, H - 1), H // 2, outline=160, width=int(1.5 * K))
        layers.append(layer(edge, (0.66, 0.60, 0.52)))
    save(name, compose(W, H, layers), w, h)

def paw_pattern():
    """Motif discret de pattes, raccordable, pour le fond des panneaux."""
    S = 192
    im = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    def paw(cx, cy, s, ang):
        import math
        ca, sa = math.cos(ang), math.sin(ang)
        def p(x, y): return (cx + (x * ca - y * sa) * s, cy + (x * sa + y * ca) * s)
        for ox in (0, S * K, -S * K):
            for oy in (0, S * K, -S * K):
                x0, y0 = p(0, 6)
                d.ellipse([x0 - 11 * s + ox, y0 - 9 * s + oy, x0 + 11 * s + ox, y0 + 9 * s + oy], fill=(120, 80, 50, 255))
                for (tx, ty) in ((-13, -8), (-5, -15), (5, -15), (13, -8)):
                    x1, y1 = p(tx, ty)
                    d.ellipse([x1 - 4.6 * s + ox, y1 - 5.6 * s + oy, x1 + 4.6 * s + ox, y1 + 5.6 * s + oy], fill=(120, 80, 50, 255))
    paw(48 * K, 50 * K, K * 1.0, -0.4)
    paw(146 * K, 100 * K, K * 0.8, 0.5)
    paw(70 * K, 150 * K, K * 0.7, 0.2)
    im = im.resize((S, S), Image.LANCZOS)
    im.save(os.path.join(OUT, "paws.png"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    button("btn"); button("btn_pressed", True)
    button("tile", radius=34); button("tile_pressed", True, radius=34)
    panel("panel"); header(); bar("bar_fill", True); bar("bar_bg", False); paw_pattern()
    print(sorted(os.listdir(OUT)))
