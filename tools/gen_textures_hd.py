#!/usr/bin/env python3
"""Textures HD raccordables avec cartes de relief (normales) pour les décors de Truffe & Co.
Complète gen_textures.py. Usage : python3 tools/gen_textures_hd.py -> assets/textures/*.png
Chaque matière produit <nom>.png (couleur) et <nom>_n.png (normales, convention OpenGL)."""
import numpy as np, os, sys
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from gen_textures import pnoise, fbm, lerp, OUT, N

rng = np.random.default_rng(77)

def save_rgb(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))

def save_normal(name, height, strength=4.0):
    """Normales à partir d'une hauteur périodique (0..1)."""
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * strength
    nz = np.ones_like(height)
    n = np.stack([-dx, dy, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    save_rgb(name + "_n", n * 0.5 + 0.5)

def col(c, shape=(N, N)):
    return np.broadcast_to(np.array(c, dtype=float), shape + (3,)).copy()

def voronoi(k, seed, stretch=(1.0, 1.0), jitter=1.0):
    """Cellules de Voronoï périodiques : (distance au bord 0..1, identifiant de cellule)."""
    r = np.random.default_rng(seed)
    g = int(np.sqrt(k))
    pts = []
    for i in range(g):
        for j in range(g):
            pts.append(((i + 0.5 + (r.random() - 0.5) * jitter) / g, (j + 0.5 + (r.random() - 0.5) * jitter) / g))
    pts = np.array(pts)
    y, x = np.mgrid[0:N, 0:N] / N
    d1 = np.full((N, N), 9.0); d2 = np.full((N, N), 9.0); idx = np.zeros((N, N), int)
    for n_i, (px, py) in enumerate(pts):
        dx = np.abs(x - px); dx = np.minimum(dx, 1 - dx) * stretch[0]
        dy = np.abs(y - py); dy = np.minimum(dy, 1 - dy) * stretch[1]
        d = np.hypot(dx, dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, n_i, idx)
        d1 = np.where(closer, d, d1)
    edge = (d2 - d1) * g
    return np.clip(edge, 0, 1), idx, len(pts)

def cobble():
    edge, idx, k = voronoi(64, 3, jitter=0.85)
    tone = np.random.default_rng(4).uniform(-0.09, 0.09, k)[idx]
    stone = np.clip(edge * 3.2, 0, 1) ** 0.55
    base = col((0.70, 0.66, 0.60)) + tone[..., None]
    base += (pnoise(1.2, 5)[..., None] - 0.5) * 0.10
    warm = np.random.default_rng(6).uniform(0, 1, k)[idx]
    base = lerp(base, col((0.74, 0.62, 0.52)), warm * 0.35)
    mortar = col((0.42, 0.40, 0.36))
    moss = np.clip(pnoise(7, 8) - 0.62, 0, 1) * 2.2 * (1 - stone)
    mortar = lerp(mortar, col((0.38, 0.47, 0.28)), moss)
    c = lerp(mortar, base, stone)
    save_rgb("cobble", c)
    save_normal("cobble", stone * 0.9 + pnoise(0.6, 9) * 0.1, 5.0)

def bricks(name, rows, per_row, c_a, c_b, mortar_c, seed):
    y, x = np.mgrid[0:N, 0:N]
    h = N // rows
    r = np.random.default_rng(seed)
    out = np.zeros((N, N, 3)); height = np.zeros((N, N))
    w = N // per_row
    for row in range(rows):
        offs = (w // 2) if row % 2 else 0
        for b in range(per_row):
            t = r.random()
            cc = np.array(c_a) * (1 - t) + np.array(c_b) * t + r.uniform(-0.03, 0.03)
            x0 = (b * w + offs) % N
            xs = (x - x0) % N
            ys = y - row * h
            m = (xs < w) & (ys >= 0) & (ys < h)
            ex = np.minimum(xs, w - 1 - xs); ey = np.minimum(ys, h - 1 - ys)
            bev = np.clip(np.minimum(ex, ey) / 5.0, 0, 1)
            out[m] = (mortar_c * (1 - bev[m])[:, None] + cc * bev[m][:, None])
            height[m] = bev[m]
    grain = (pnoise(0.5, seed + 1) - 0.5) * 0.14 + (pnoise(4, seed + 2) - 0.5) * 0.10
    out += grain[..., None] * np.clip(height, 0.3, 1)[..., None]
    save_rgb(name, out)
    save_normal(name, height * 0.85 + pnoise(0.5, seed + 3) * 0.15, 5.0)

def roof_tiles():
    y, x = np.mgrid[0:N, 0:N]
    rows, per = 8, 8
    h = N / rows; w = N / per
    row = np.floor(y / h)
    xo = (x + (row % 2) * w * 0.5) % N
    lx = (xo % w) / w - 0.5
    ly = (y % h) / h
    # tuile arrondie en bas : hauteur décroissante vers le haut de la rangée, bord en arc
    arc = np.sqrt(np.clip(1 - (lx * 2) ** 2, 0, 1))
    lower = ly > (0.55 + 0.4 * arc)
    height = np.clip(0.35 + ly * 0.65, 0, 1) * (0.75 + 0.25 * arc)
    height = np.where(lower, height * 0.25, height)
    tid = (row * per + np.floor(xo / w)).astype(int)
    tone = np.random.default_rng(12).uniform(-0.10, 0.10, rows * per + per)[tid]
    c = col((0.80, 0.80, 0.80)) + tone[..., None]
    c *= (0.62 + 0.38 * height)[..., None]
    c += (pnoise(0.7, 13)[..., None] - 0.5) * 0.08
    save_rgb("roof_tiles", c)
    save_normal("roof_tiles", height, 6.0)

def bark():
    y, x = np.mgrid[0:N, 0:N]
    warp = pnoise(5, 21) * 60.0
    ridges = np.abs(np.sin((x + warp) * np.pi / 32.0)) ** 0.6
    cracks = np.clip(pnoise(1.0, 22) * 1.6 - 0.5, 0, 1)
    height = np.clip(ridges * 0.8 + cracks * 0.2, 0, 1)
    c = lerp(col((0.30, 0.22, 0.15)), col((0.62, 0.49, 0.36)), height)
    c += (pnoise(0.5, 23)[..., None] - 0.5) * 0.08
    save_rgb("bark", c)
    save_normal("bark", height, 5.0)

def stone_wall():
    edge, idx, k = voronoi(36, 31, stretch=(1.0, 1.7), jitter=0.9)
    tone = np.random.default_rng(32).uniform(-0.10, 0.10, k)[idx]
    stone = np.clip(edge * 4.0, 0, 1) ** 0.5
    base = col((0.74, 0.71, 0.66)) + tone[..., None] + (pnoise(0.8, 33)[..., None] - 0.5) * 0.10
    c = lerp(col((0.45, 0.43, 0.40)), base, stone)
    save_rgb("stone_wall", c)
    save_normal("stone_wall", stone * 0.85 + pnoise(0.5, 34) * 0.15, 5.0)

def rock():
    n = fbm([9, 3, 1.0, 0.4], [0.4, 0.3, 0.2, 0.1], 41)
    cracks = np.abs(pnoise(3.0, 42) - 0.5) < 0.012
    c = lerp(col((0.50, 0.49, 0.47)), col((0.78, 0.76, 0.72)), n)
    lichen = np.clip(pnoise(6, 43) - 0.68, 0, 1) * 3.0
    c = lerp(c, col((0.62, 0.68, 0.42)), lichen)
    c[cracks] *= 0.6
    save_rgb("rock", c)
    save_normal("rock", n, 7.0)

def leaves():
    """Feuillage dense : feuilles claires sur fond sombre, pour les houppiers sculptés."""
    img = Image.new("L", (N * 3, N * 3), 60)
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(51)
    pts = r.random((900, 2)) * N
    for (px, py) in pts:
        s = r.uniform(9, 17); ang = r.uniform(0, np.pi); v = int(r.uniform(120, 255))
        for ox in (0, N, 2 * N):
            for oy in (0, N, 2 * N):
                cx, cy = px + ox, py + oy
                dx, dy = np.cos(ang) * s, np.sin(ang) * s
                nx, ny = -dy * 0.45, dx * 0.45
                d.polygon([(cx - dx, cy - dy), (cx + nx, cy + ny), (cx + dx, cy + dy), (cx - nx, cy - ny)], fill=v)
    img = img.crop((N, N, 2 * N, 2 * N)).filter(ImageFilter.GaussianBlur(0.8))
    v = np.asarray(img, dtype=float) / 255.0
    c = lerp(col((0.42, 0.52, 0.36)), col((1.0, 1.0, 0.92)), v)
    save_rgb("leaves", c)
    save_normal("leaves", v, 4.0)

def grass_hd():
    y, x = np.mgrid[0:N, 0:N]
    n = fbm([10, 4, 1.2], [0.5, 0.3, 0.2], 61)
    streak = 0.5 + 0.5 * np.sin(x * 2.3 + pnoise(0.8, 62) * 40.0) * np.sin(y * 0.35 + pnoise(1.5, 63) * 20.0)
    c = lerp(col((0.40, 0.60, 0.26)), col((0.30, 0.48, 0.20)), n * 0.85)
    c = lerp(c, col((0.56, 0.70, 0.32)), np.clip(streak, 0, 1) * 0.35)
    c = lerp(c, col((0.62, 0.66, 0.36)), np.clip(pnoise(12, 64) - 0.64, 0, 1) * 1.8)
    c *= (0.88 + 0.24 * rng.random((N, N)))[..., None]
    save_rgb("grass", c)
    save_normal("grass", streak * 0.6 + n * 0.4, 2.5)

def sand_hd():
    y, x = np.mgrid[0:N, 0:N]
    n = fbm([6, 1.0], [0.6, 0.4], 71)
    ripple = 0.5 + 0.5 * np.sin(y * (2 * np.pi * 14 / N) + pnoise(7, 72) * 9.0)
    c = lerp(col((0.90, 0.80, 0.60)), col((0.80, 0.68, 0.48)), n * 0.5 + (1 - ripple) * 0.3)
    grains = rng.random((N, N))
    c[grains < 0.03] *= 0.86
    c[grains > 0.985] *= 1.10
    save_rgb("sand", c)
    save_normal("sand", ripple * 0.75 + n * 0.25, 3.0)

def dirt_hd():
    n = fbm([5, 1.2], [0.6, 0.4], 81)
    edge, idx, k = voronoi(900, 82, jitter=1.0)
    peb = (np.random.default_rng(83).random(k)[idx] > 0.86) * np.clip(edge * 4 - 0.5, 0, 1)
    c = lerp(col((0.66, 0.54, 0.39)), col((0.52, 0.42, 0.30)), n)
    c = lerp(c, col((0.78, 0.74, 0.68)), peb * 0.9)
    save_rgb("dirt", c)
    save_normal("dirt", n * 0.5 + peb * 0.5, 4.0)

def forest_floor_hd():
    n = fbm([8, 2.5, 1.0], [0.5, 0.3, 0.2], 91)
    c = lerp(col((0.40, 0.33, 0.22)), col((0.32, 0.46, 0.25)), np.clip(pnoise(9, 92) * 1.4 - 0.3, 0, 1))
    img = Image.new("L", (N * 3, N * 3), 0)
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(93)
    for (px, py) in r.random((260, 2)) * N:
        s = r.uniform(7, 13); ang = r.uniform(0, np.pi)
        for ox in (0, N, 2 * N):
            for oy in (0, N, 2 * N):
                cx, cy = px + ox, py + oy
                dx, dy = np.cos(ang) * s, np.sin(ang) * s
                d.polygon([(cx - dx, cy - dy), (cx - dy * 0.5, cy + dx * 0.5), (cx + dx, cy + dy), (cx + dy * 0.5, cy - dx * 0.5)], fill=int(r.uniform(140, 255)))
    lv = np.asarray(img.crop((N, N, 2 * N, 2 * N)).filter(ImageFilter.GaussianBlur(0.7)), dtype=float) / 255.0
    leaf_c = lerp(col((0.72, 0.40, 0.16)), col((0.85, 0.66, 0.24)), pnoise(0.6, 94))
    c = lerp(c, leaf_c, np.clip(lv, 0, 1) * 0.9)
    c *= (0.85 + 0.25 * n)[..., None]
    save_rgb("forest_floor", c)
    save_normal("forest_floor", n * 0.5 + lv * 0.5, 4.0)

def planks_normal():
    im = np.asarray(Image.open(os.path.join(OUT, "wood_planks.png")).convert("L"), dtype=float) / 255.0
    save_normal("wood_planks", im, 3.0)

def plaster_hd():
    n = fbm([4, 1.5, 0.5], [0.5, 0.3, 0.2], 101)
    v = 0.92 + 0.07 * (n - 0.5) * 2
    save_rgb("plaster", np.repeat(v[..., None], 3, 2))
    save_normal("plaster", n, 2.0)

def wallpaper():
    """Papier peint clair à fines rayures et petits motifs (teinté en jeu)."""
    y, x = np.mgrid[0:N, 0:N]
    stripes = (np.floor(x / (N / 16)) % 2) * 0.035
    dots = np.clip(1 - np.hypot(((x + N / 32) % (N / 8)) - N / 16, (y % (N / 8)) - N / 16) / 5.0, 0, 1) * 0.07
    v = 0.92 + stripes - dots + (pnoise(0.6, 111) - 0.5) * 0.03
    save_rgb("wallpaper", np.repeat(v[..., None], 3, 2))

def noise_maps():
    """Bruits doux raccordables : nuages, eau, variation des sols (R, G, B = 3 échelles)."""
    a = fbm([14, 6, 2.5], [0.55, 0.3, 0.15], 121)
    b = fbm([7, 3, 1.2], [0.5, 0.3, 0.2], 122)
    c = fbm([3, 1.2, 0.5], [0.5, 0.3, 0.2], 123)
    save_rgb("noise", np.stack([a, b, c], -1))

def grass_card():
    """Touffe de brins d'herbe (RGBA), base sombre, pointes claires."""
    S = 256
    img = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(131)
    for i in range(34):
        x0 = r.uniform(0.10, 0.90) * S * 2
        h = r.uniform(0.45, 0.98) * S * 2
        lean = r.uniform(-0.22, 0.22) * S * 2
        w = r.uniform(6, 12)
        steps = 12
        for s in range(steps):
            t0, t1 = s / steps, (s + 1) / steps
            xa = x0 + lean * t0 ** 2; xb = x0 + lean * t1 ** 2
            ya = S * 2 - h * t0; yb = S * 2 - h * t1
            wa = w * (1 - t0) + 1.0; wb = w * (1 - t1) + 1.0
            g = 0.74 + 0.26 * t1
            tone = r.uniform(0.92, 1.08)
            colr = (int(255 * min(1, 0.62 * g * tone + 0.12)), int(255 * min(1, g * tone)), int(255 * min(1, 0.42 * g * tone + 0.05)), 255)
            d.polygon([(xa - wa, ya), (xa + wa, ya), (xb + wb, yb), (xb - wb, yb)], fill=colr)
    img = img.resize((S, S), Image.LANCZOS)
    img.save(os.path.join(OUT, "grass_card.png"))

def flower_card():
    """Planche de 4 fleurs (2 × 2) en RGBA : tige verte, pétales blancs (teintés par instance), cœur jaune."""
    S = 128
    img = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(4):
        ox, oy = (k % 2) * S * 2, (k // 2) * S * 2
        cx, cy = ox + S, oy + S * 0.62
        d.line([(cx, oy + S * 2), (cx + 6, cy)], fill=(70, 140, 60, 255), width=10)
        d.polygon([(cx, oy + S * 1.55), (cx - 46, oy + S * 1.25), (cx - 8, oy + S * 1.3)], fill=(80, 155, 66, 255))
        petals = [5, 8, 6, 12][k]
        pr = [44, 34, 50, 26][k]
        for p in range(petals):
            a = 2 * np.pi * p / petals
            px, py = cx + np.cos(a) * pr * 0.75, cy + np.sin(a) * pr * 0.75
            rr = pr * (0.62 if k != 3 else 0.5)
            d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(255, 255, 255, 255))
        d.ellipse([cx - pr * 0.42, cy - pr * 0.42, cx + pr * 0.42, cy + pr * 0.42], fill=(255, 205, 70, 255))
    img = img.resize((S * 2, S * 2), Image.LANCZOS)
    img.save(os.path.join(OUT, "flower_card.png"))

def rug():
    """Tapis rond à motifs (niveaux de gris, teinté en jeu), alpha circulaire."""
    S = 512
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S / 2 + 0.5, y - S / 2 + 0.5) / (S / 2)
    a = np.arctan2(y - S / 2, x - S / 2)
    v = np.full((S, S), 0.80)
    v = np.where((r > 0.86) & (r < 0.97), 1.0, v)
    v = np.where((r > 0.60) & (r < 0.66), 1.0, v)
    v = np.where(r < 0.20, 1.0, v)
    scallop = 0.76 + 0.045 * np.cos(a * 16)
    v = np.where((r > scallop - 0.035) & (r < scallop), 0.62, v)
    petal = 0.40 + 0.10 * np.abs(np.cos(a * 4))
    v = np.where((r < petal) & (r > 0.24), 0.66, v)
    weave = 0.5 + 0.5 * np.sin(x * 1.3) * np.sin(y * 1.3)
    v = v * (0.94 + 0.06 * weave)
    alpha = np.clip((1.0 - r) * 90.0, 0, 1)
    rgba = np.stack([v, v, v, alpha], -1)
    Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "rug.png"))

def blob():
    """Tache douce (ombre de contact, lueur) en niveaux de gris."""
    S = 128
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S / 2 + 0.5, y - S / 2 + 0.5) / (S / 2)
    v = np.clip(1 - r, 0, 1) ** 1.6
    rgba = np.stack([np.ones_like(v), np.ones_like(v), np.ones_like(v), v], -1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "soft_blob.png"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    cobble()
    bricks("brick", 16, 8, (0.72, 0.38, 0.28), (0.60, 0.30, 0.22), np.array([0.78, 0.74, 0.68]), 11)
    bricks("pavers", 8, 4, (0.80, 0.74, 0.66), (0.70, 0.64, 0.58), np.array([0.50, 0.47, 0.42]), 15)
    roof_tiles(); bark(); stone_wall(); rock(); leaves(); grass_hd(); sand_hd(); dirt_hd(); forest_floor_hd()
    planks_normal(); plaster_hd(); wallpaper(); noise_maps(); grass_card(); flower_card(); rug(); blob()
    print("textures :", len(os.listdir(OUT)))
