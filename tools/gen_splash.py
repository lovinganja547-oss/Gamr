#!/usr/bin/env python3
"""Écran de démarrage de Truffe & Co (assets/icons/splash.png)."""
from PIL import Image, ImageDraw, ImageFont
import os
D = os.path.dirname(__file__)
W, H = 720, 1280
im = Image.new("RGB", (W, H))
d = ImageDraw.Draw(im)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(253 - 20 * t), int(196 - 40 * t), int(140 - 10 * t)))
icon = Image.open(os.path.join(D, "..", "assets", "icons", "icon_fg.png")).convert("RGBA").resize((420, 420))
im.paste(icon, ((W - 420) // 2, 330), icon)
font = None
for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
    if os.path.exists(f):
        font = ImageFont.truetype(f, 92)
txt = "Truffe & Co"
if font:
    w = d.textlength(txt, font=font)
    d.text(((W - w) / 2 + 4, 804), txt, font=font, fill=(150, 80, 45))
    d.text(((W - w) / 2, 800), txt, font=font, fill=(255, 255, 255))
im.save(os.path.join(D, "..", "assets", "icons", "splash.png"))
print("ok")
