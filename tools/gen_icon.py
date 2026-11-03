#!/usr/bin/env python3
"""Génère l'icône originale de Patouille (assets/icons/*.png)."""
from PIL import Image, ImageDraw
import os
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
os.makedirs(OUT, exist_ok=True)

def face(d, S, ox=0, oy=0, k=1.0):
    c = lambda x, y: (ox + x * k, oy + y * k)
    def ell(x0, y0, x1, y1, col):
        d.ellipse([*c(x0, y0), *c(x1, y1)], fill=col)
    ell(70, 150, 190, 380, (139, 84, 52))      # oreille gauche
    ell(322, 150, 442, 380, (139, 84, 52))     # oreille droite
    ell(120, 110, 392, 400, (240, 196, 140))   # tête
    ell(170, 250, 342, 420, (255, 238, 214))   # museau
    ell(185, 210, 235, 270, (40, 30, 30)); ell(277, 210, 327, 270, (40, 30, 30))
    ell(200, 220, 216, 236, (255, 255, 255)); ell(292, 220, 308, 236, (255, 255, 255))
    ell(226, 285, 286, 330, (45, 32, 32))      # truffe
    ell(240, 340, 272, 395, (240, 110, 120))   # langue
    ell(130, 150, 175, 175, (139, 84, 52))

def icon(size, bg=True, fg=True, pad=0.0):
    S = 512; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if bg:
        for y in range(S):
            r = int(255 - y * 0.12); g = int(170 - y * 0.1); b = int(90 + y * 0.05)
            d.line([(0, y), (S, y)], fill=(r, g, b, 255))
    if fg:
        k = 1.0 - pad; o = S * pad / 2
        face(d, S, o, o, k)
    return im.resize((size, size), Image.LANCZOS)

icon(512).save(os.path.join(OUT, "icon.png"))
icon(432, fg=False).save(os.path.join(OUT, "icon_bg.png"))
icon(432, bg=False, pad=0.35).save(os.path.join(OUT, "icon_fg.png"))
m = icon(432, bg=False, pad=0.35); m.save(os.path.join(OUT, "icon_mono.png"))
print("ok")
