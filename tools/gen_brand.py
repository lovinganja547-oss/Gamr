#!/usr/bin/env python3
"""Identité visuelle : fond de chargement, logo, écran de démarrage et icônes.
Sources : tools/art/*.jpg (rendus du jeu, scénario « art ») et la police Baloo 2 (OFL)."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "tools", "art")
FONT = os.path.join(ART, "Baloo2-ExtraBold.ttf")
CORAL = (240, 112, 78)
BROWN = (122, 62, 34)
CREAM = (255, 246, 226)
GOLD = (255, 200, 80)


def paw(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r * 0.55, cx + r, cy + r * 1.05], fill=fill)
    for dx, dy, k in [(-1.05, -0.75, 0.42), (-0.4, -1.35, 0.46), (0.4, -1.35, 0.46), (1.05, -0.75, 0.42)]:
        d.ellipse([cx + dx * r - r * k, cy + dy * r - r * k * 1.2, cx + dx * r + r * k, cy + dy * r + r * k * 1.2], fill=fill)


def logo(w=960):
    s = 2
    W, H = w * s, int(w * 0.62) * s
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f1 = ImageFont.truetype(FONT, int(W * 0.285))
    f2 = ImageFont.truetype(FONT, int(W * 0.098))
    # ombre portée
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.text((W // 2, int(H * 0.36) + 14 * s), "Truffe", font=f1, anchor="mm", fill=(60, 30, 15, 150), stroke_width=22 * s, stroke_fill=(60, 30, 15, 150))
    rb = [int(W * 0.17), int(H * 0.68), int(W * 0.83), int(H * 0.93)]
    ds.rounded_rectangle([rb[0], rb[1] + 12 * s, rb[2], rb[3] + 12 * s], radius=(rb[3] - rb[1]) // 2, fill=(60, 30, 15, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(7 * s))
    im.alpha_composite(sh)
    d = ImageDraw.Draw(im)
    # mot principal : contour brun, liseré corail, remplissage crème
    d.text((W // 2, int(H * 0.36)), "Truffe", font=f1, anchor="mm", fill=BROWN, stroke_width=22 * s, stroke_fill=BROWN)
    d.text((W // 2, int(H * 0.36)), "Truffe", font=f1, anchor="mm", fill=CORAL, stroke_width=11 * s, stroke_fill=CORAL)
    d.text((W // 2, int(H * 0.36)), "Truffe", font=f1, anchor="mm", fill=CREAM)
    # reflet sur le haut des lettres
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text((W // 2, int(H * 0.36)), "Truffe", font=f1, anchor="mm", fill=255)
    grad = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        t = (y - H * 0.2) / (H * 0.32)
        gd.line([(0, y), (W, y)], fill=int(max(0, min(1, t)) * 70))
    shade = Image.new("RGBA", (W, H), (255, 170, 90, 0))
    shade.putalpha(Image.composite(grad, Image.new("L", (W, H), 0), mask))
    im.alpha_composite(shade)
    # ruban
    d.rounded_rectangle(rb, radius=(rb[3] - rb[1]) // 2, fill=BROWN)
    d.rounded_rectangle([rb[0] + 7 * s, rb[1] + 7 * s, rb[2] - 7 * s, rb[3] - 7 * s], radius=(rb[3] - rb[1]) // 2, fill=CORAL)
    d.rounded_rectangle([rb[0] + 16 * s, rb[1] + 13 * s, rb[2] - 16 * s, rb[1] + (rb[3] - rb[1]) // 2], radius=(rb[3] - rb[1]) // 4, fill=(250, 140, 104))
    d.text((W // 2, (rb[1] + rb[3]) // 2 + 3 * s), "& COMPAGNIE", font=f2, anchor="mm", fill=CREAM, stroke_width=3 * s, stroke_fill=BROWN)
    # empreintes
    paw(d, int(W * 0.905), int(H * 0.16), int(W * 0.036), BROWN)
    paw(d, int(W * 0.905), int(H * 0.16), int(W * 0.029), GOLD)
    paw(d, int(W * 0.1), int(H * 0.8), int(W * 0.026), BROWN)
    paw(d, int(W * 0.1), int(H * 0.8), int(W * 0.02), GOLD)
    return im.resize((w, int(w * 0.62)), Image.LANCZOS)


def background():
    bg = Image.open(os.path.join(ART, "loading_bg.jpg")).convert("RGB").resize((1080, 1920), Image.LANCZOS)
    # voile clair en haut (lisibilité du logo) et sombre en bas (barre de progression)
    ov = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(1920):
        if y < 520:
            d.line([(0, y), (1080, y)], fill=(255, 236, 205, int(120 * (1 - y / 520.0) ** 1.4)))
        elif y > 1500:
            d.line([(0, y), (1080, y)], fill=(40, 22, 12, int(175 * ((y - 1500) / 420.0) ** 1.2)))
    out = bg.convert("RGBA")
    out.alpha_composite(ov)
    return out.convert("RGB")


def icons(lg):
    face = Image.open(os.path.join(ART, "icon_face.jpg")).convert("RGB")
    crop = face.crop((0, 0, 1080, 1080))
    # icône classique : portrait dans un carré arrondi, liseré clair
    ic = crop.resize((512, 512), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, 1023, 1023], radius=230, fill=255)
    m = m.resize((512, 512), Image.LANCZOS)
    ring = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle([14, 14, 1009, 1009], radius=218, outline=(255, 246, 226, 255), width=26)
    ic.alpha_composite(ring.resize((512, 512), Image.LANCZOS))
    ic.putalpha(m)
    ic.save(os.path.join(ROOT, "assets", "icons", "icon.png"))
    # icône adaptative : le portrait tient dans la zone sûre (66 %), le fond déborde en flou
    back = crop.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(14))
    back.save(os.path.join(ROOT, "assets", "icons", "icon_bg.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = crop.resize((316, 316), Image.LANCZOS).convert("RGBA")
    fm = Image.new("L", (316, 316), 0)
    ImageDraw.Draw(fm).ellipse([6, 6, 309, 309], fill=255)
    inner.putalpha(fm.filter(ImageFilter.GaussianBlur(9)))
    fg.alpha_composite(inner, (58, 58))
    fg.save(os.path.join(ROOT, "assets", "icons", "icon_fg.png"))


def main():
    lg = logo()
    lg.save(os.path.join(ROOT, "assets", "ui", "logo.png"))
    bg = background()
    bg.save(os.path.join(ROOT, "assets", "ui", "loading_bg.jpg"), quality=90)
    # image de démarrage du moteur : même cadrage que l'écran de chargement, pour une transition invisible
    sp = bg.resize((720, 1280), Image.LANCZOS).convert("RGBA")
    l2 = lg.resize((620, int(620 * 0.62)), Image.LANCZOS)
    sp.alpha_composite(l2, ((720 - 620) // 2, 70))
    sp.convert("RGB").save(os.path.join(ROOT, "assets", "icons", "splash.png"))
    icons(lg)
    print("brand ok")


if __name__ == "__main__":
    main()
