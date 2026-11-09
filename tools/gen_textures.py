#!/usr/bin/env python3
"""Textures originales raccordables (bruit périodique par FFT) pour Truffe & Co.
Usage : python3 tools/gen_textures.py -> assets/textures/*.png (512 px)"""
import numpy as np, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
N = 512
rng = np.random.default_rng(2026)

def pnoise(scale, seed=None, n=N):
    """Bruit lisse périodique (filtre passe-bas gaussien dans le domaine fréquentiel)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.normal(0, 1, (n, n))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    g = np.exp(-(fx ** 2 + fy ** 2) * (scale ** 2) * 40.0)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
    out -= out.min()
    return out / max(out.max(), 1e-9)

def fbm(scales, weights, seed=0):
    t = sum(pnoise(s, seed + i) * w for i, (s, w) in enumerate(zip(scales, weights)))
    t -= t.min()
    return t / t.max()

def save(name, rgb):
    rgb = np.clip(rgb, 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))

def lerp(a, b, t):
    return a + (b - a) * t[..., None]

def planks():
    rows = 6
    h = N // rows
    y, x = np.mgrid[0:N, 0:N]
    out = np.zeros((N, N, 3))
    grain_n = pnoise(6, 11)
    for r in range(rows):
        sl = slice(r * h, (r + 1) * h)
        offs = int(rng.integers(0, N))
        nb = 2   # deux lattes par rangée, joints décalés
        for k in range(nb):
            tone = rng.uniform(-0.08, 0.08)
            base = np.array([0.80, 0.60, 0.40]) + tone
            dark = base * 0.72
            xs = (x[sl] + offs) % N
            m = (xs >= k * N // nb) & (xs < (k + 1) * N // nb)
            ly = (y[sl] - r * h) / h
            grain = (0.5 + 0.5 * np.sin(ly * 70.0 + grain_n[sl] * 22.0 + xs * 0.004 + k * 3.0)) ** 4 * 0.8 + pnoise(0.4, 90 + r)[sl] * 0.25
            knot = np.clip(1.0 - np.hypot((xs - (k * N // nb + 90 + r * 30) % N) / 18.0, (ly - 0.5) * h / 10.0), 0, 1) ** 2
            c = lerp(np.broadcast_to(base, m.shape + (3,)), np.broadcast_to(dark, m.shape + (3,)), grain * 0.55 + knot * 0.6)
            out[sl][m] = c[m]
            # joint d'about
            edge = (xs == k * N // nb) | (xs == k * N // nb + 1)
            out[sl][edge] *= 0.55
        out[r * h:r * h + 2] *= 0.5   # joint entre rangées
    out *= (0.92 + 0.08 * pnoise(3, 5))[..., None]
    save("wood_planks", out)

def fabric():
    y, x = np.mgrid[0:N, 0:N]
    weave = 0.5 + 0.25 * np.sin(x * np.pi / 3.0) * np.sign(np.sin(y * np.pi / 6.0)) + 0.25 * np.sin(y * np.pi / 3.0) * np.sign(np.sin(x * np.pi / 6.0))
    v = 0.86 + 0.08 * weave + 0.06 * (pnoise(2, 21) - 0.5)
    save("fabric", np.repeat(v[..., None], 3, axis=2))

def plaster():
    v = 0.93 + 0.05 * (fbm([4, 1.5], [0.6, 0.4], 31) - 0.5) * 2
    save("plaster", np.repeat(v[..., None], 3, axis=2))

def grass():
    n = fbm([10, 4, 1.2], [0.5, 0.3, 0.2], 41)
    y, x = np.mgrid[0:N, 0:N]
    blades = 0.5 + 0.5 * np.sin(x * 1.7 + pnoise(1.0, 42) * 30.0)
    base = np.array([0.50, 0.74, 0.36]); alt = np.array([0.36, 0.60, 0.27]); dry = np.array([0.66, 0.72, 0.38])
    c = lerp(np.broadcast_to(base, (N, N, 3)), np.broadcast_to(alt, (N, N, 3)), n * 0.8 + blades * 0.15)
    c = lerp(c, np.broadcast_to(dry, (N, N, 3)), np.clip(pnoise(12, 43) - 0.62, 0, 1) * 2.0)
    fine = rng.random((N, N))
    c *= (0.9 + 0.2 * fine)[..., None]
    save("grass", c)

def sand():
    n = fbm([6, 1.0], [0.6, 0.4], 51)
    y, x = np.mgrid[0:N, 0:N]
    ripple = 0.5 + 0.5 * np.sin(y * 0.11 + pnoise(8, 52) * 8.0)
    base = np.array([0.96, 0.88, 0.70]); alt = np.array([0.88, 0.77, 0.56])
    c = lerp(np.broadcast_to(base, (N, N, 3)), np.broadcast_to(alt, (N, N, 3)), n * 0.6 + ripple * 0.25)
    grains = rng.random((N, N)) < 0.02
    c[grains] *= 0.85
    save("sand", c)

def forest_floor():
    n = fbm([8, 2.5, 1.0], [0.5, 0.3, 0.2], 61)
    soil = np.array([0.46, 0.38, 0.26]); moss = np.array([0.36, 0.52, 0.28]); leaf = np.array([0.72, 0.42, 0.18])
    c = lerp(np.broadcast_to(soil, (N, N, 3)), np.broadcast_to(moss, (N, N, 3)), np.clip(pnoise(9, 62) * 1.4 - 0.3, 0, 1))
    c = lerp(c, np.broadcast_to(leaf, (N, N, 3)), np.clip(pnoise(1.2, 63) - 0.66, 0, 1) * 3.0)
    c *= (0.85 + 0.25 * n)[..., None]
    save("forest_floor", c)

def path_dirt():
    n = fbm([5, 1.2], [0.6, 0.4], 71)
    c = lerp(np.broadcast_to(np.array([0.70, 0.58, 0.42]), (N, N, 3)), np.broadcast_to(np.array([0.58, 0.47, 0.34]), (N, N, 3)), n)
    pebbles = np.clip(pnoise(0.6, 72) - 0.8, 0, 1) * 4.0
    c = lerp(c, np.broadcast_to(np.array([0.82, 0.78, 0.72]), (N, N, 3)), pebbles)
    save("dirt", c)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    planks(); fabric(); plaster(); grass(); sand(); forest_floor(); path_dirt()
    print("textures :", sorted(os.listdir(OUT)))
