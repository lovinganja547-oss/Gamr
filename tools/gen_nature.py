#!/usr/bin/env python3
"""Végétation et rochers sculptés (SDF + surface nets) : houppiers, troncs, sapins, buissons, haies, rochers.
Les maillages sont unitaires (taille ~1) et mis à l'échelle en jeu. Couleur des sommets = occlusion.
Usage : python3 tools/gen_nature.py  puis  godot --headless --path . -s tools/convert_models.gd"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from gen_models import sd_ellipsoid, sd_sphere, sd_round_cone, smin, smax, build, save, length

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "props")

def lumps(P, amp, freq, seed=0.0):
    x, y, z = P[..., 0] * freq + seed, P[..., 1] * freq + seed * 1.7, P[..., 2] * freq + seed * 0.6
    n = np.sin(x * 1.7 + np.sin(y * 1.3)) * np.sin(y * 1.9 + np.sin(z * 1.1)) * np.sin(z * 1.5 + np.sin(x * 1.2))
    n2 = np.sin(x * 3.1 + 1.0) * np.sin(y * 2.7 + 2.0) * np.sin(z * 3.3 + 0.5)
    return (n + n2 * 0.5) * amp

def blobs(P, centers, k):
    d = None
    for (c, r) in centers:
        s = sd_ellipsoid(P, np.asarray(c, float), r) if isinstance(r, tuple) else sd_sphere(P, c, r)
        d = s if d is None else smin(d, s, k)
    return d

def canopy_a(P):
    d = blobs(P, [((0, 0, 0), 0.72), ((0.48, 0.12, 0.1), 0.5), ((-0.45, 0.05, 0.22), 0.52), ((0.05, 0.42, -0.12), 0.52),
                  ((-0.15, -0.05, -0.5), 0.48), ((0.28, -0.1, 0.48), 0.44), ((-0.3, 0.38, 0.2), 0.4)], 0.16)
    return d + lumps(P, 0.05, 5.5, 1.0)

def canopy_b(P):
    d = blobs(P, [((0, -0.1, 0), (0.62, 0.7, 0.62)), ((0.1, 0.5, 0.05), (0.46, 0.55, 0.46)), ((-0.36, -0.2, 0.2), 0.42),
                  ((0.38, -0.25, -0.15), 0.42), ((0.0, 0.92, 0.0), 0.3)], 0.18)
    return d + lumps(P, 0.05, 5.5, 3.0)

def canopy_c(P):
    d = blobs(P, [((0, 0, 0), (0.95, 0.5, 0.85)), ((0.5, 0.22, 0.2), 0.45), ((-0.52, 0.2, -0.1), 0.48), ((0.0, 0.32, -0.4), 0.45),
                  ((-0.1, 0.25, 0.45), 0.42)], 0.18)
    return d + lumps(P, 0.05, 5.0, 5.0)

def trunk(P):
    d = sd_round_cone(P, (0, 0, 0), (0.02, 1.0, 0.0), 0.15, 0.085)
    for a in (0.3, 2.3, 4.4):
        d = smin(d, sd_round_cone(P, (0, 0.14, 0), (np.cos(a) * 0.26, -0.02, np.sin(a) * 0.26), 0.07, 0.035), 0.09)
    d = smin(d, sd_round_cone(P, (0, 0.72, 0), (0.24, 1.0, 0.1), 0.06, 0.035), 0.05)
    d = smin(d, sd_round_cone(P, (0, 0.8, 0), (-0.2, 1.02, -0.14), 0.055, 0.03), 0.05)
    return d + lumps(P, 0.008, 16.0)

def pine(P):
    d = None
    for (y0, y1, r) in ((0.0, 0.5, 0.52), (0.26, 0.72, 0.4), (0.5, 0.9, 0.28), (0.72, 1.06, 0.17)):
        s = sd_round_cone(P, (0, y0, 0), (0, y1, 0), r, 0.02)
        s = np.maximum(s, y0 - 0.04 - P[..., 1])   # dessous plat de chaque étage
        d = s if d is None else smin(d, s, 0.05)
    ang = np.arctan2(P[..., 2], P[..., 0])
    return d + np.sin(ang * 9.0 + P[..., 1] * 7.0) * 0.022 + lumps(P, 0.012, 9.0)

def bush(P):
    d = blobs(P, [((0, 0.3, 0), (0.55, 0.36, 0.5)), ((0.42, 0.24, 0.1), 0.32), ((-0.4, 0.22, -0.08), 0.34), ((0.05, 0.42, -0.2), 0.3),
                  ((-0.08, 0.2, 0.36), 0.3)], 0.12)
    d = np.maximum(d, -P[..., 1])
    return d + lumps(P, 0.035, 8.0, 2.0)

def hedge(P):
    from gen_props import sd_rbox
    d = sd_rbox(P, (0, 0.38, 0), (1.0, 0.38, 0.28), 0.2)
    d = np.maximum(d, -P[..., 1])
    return d + lumps(P, 0.04, 7.0, 4.0)

def rock_a(P):
    d = blobs(P, [((0, 0.22, 0), (0.52, 0.34, 0.42)), ((0.26, 0.16, 0.14), (0.3, 0.22, 0.3)), ((-0.28, 0.14, -0.1), (0.3, 0.2, 0.26))], 0.1)
    for (n, o) in (((0.6, 0.7, 0.3), 0.36), ((-0.5, 0.75, -0.4), 0.38), ((0.1, 0.6, -0.78), 0.4), ((-0.2, 0.55, 0.8), 0.4)):
        n = np.asarray(n) / np.linalg.norm(n)
        d = smax(d, np.sum(P * n, -1) - o, 0.04)
    return np.maximum(d, -P[..., 1]) + lumps(P, 0.012, 10.0)

def rock_b(P):
    d = sd_ellipsoid(P, np.asarray((0, 0.3, 0), float), (0.4, 0.5, 0.36))
    for (n, o) in (((0.8, 0.4, 0.2), 0.3), ((-0.7, 0.5, 0.3), 0.3), ((0.0, 0.9, 0.3), 0.62), ((0.2, 0.3, -0.9), 0.3)):
        n = np.asarray(n) / np.linalg.norm(n)
        d = smax(d, np.sum(P * n, -1) - o, 0.05)
    return np.maximum(d, -P[..., 1]) + lumps(P, 0.012, 10.0, 2.0)

def stump(P):
    from gen_props import sd_cyl
    d = sd_cyl(P, (0, 0.16, 0), 0.26, 0.16, 0.03)
    for a in (0.5, 2.6, 4.6):
        d = smin(d, sd_round_cone(P, (0, 0.1, 0), (np.cos(a) * 0.4, -0.02, np.sin(a) * 0.4), 0.09, 0.04), 0.08)
    return np.maximum(d, -P[..., 1]) + lumps(P, 0.008, 16.0)

def log(P):
    Q = P[..., [1, 0, 2]].copy()
    Q[..., 0] = P[..., 1] - 0.2
    Q[..., 1] = P[..., 0]
    from gen_props import sd_cyl
    d = sd_cyl(Q, (0, 0, 0), 0.2, 0.8, 0.03)
    return d + lumps(P, 0.008, 14.0)

NATURE = {
    "canopy_a": (canopy_a, (-1.2, -0.95, -1.2), (1.2, 1.15, 1.2), 0.05),
    "canopy_b": (canopy_b, (-1.0, -1.0, -1.0), (1.0, 1.4, 1.0), 0.05),
    "canopy_c": (canopy_c, (-1.25, -0.75, -1.2), (1.25, 0.95, 1.2), 0.05),
    "trunk": (trunk, (-0.45, -0.08, -0.45), (0.45, 1.12, 0.45), 0.022),
    "pine": (pine, (-0.7, -0.1, -0.7), (0.7, 1.15, 0.7), 0.03),
    "bush": (bush, (-0.95, -0.05, -0.8), (0.95, 0.85, 0.8), 0.036),
    "hedge": (hedge, (-1.15, -0.05, -0.45), (1.15, 0.9, 0.45), 0.04),
    "rock_a": (rock_a, (-0.75, -0.05, -0.65), (0.75, 0.7, 0.65), 0.028),
    "rock_b": (rock_b, (-0.6, -0.05, -0.55), (0.6, 0.9, 0.55), 0.028),
    "stump": (stump, (-0.55, -0.05, -0.55), (0.55, 0.42, 0.55), 0.022),
    "log": (log, (-0.95, -0.05, -0.32), (0.95, 0.5, 0.32), 0.026),
}

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (sdf, bmin, bmax, h) in NATURE.items():
        for q, k in (("hi", 1.8), ("lo", 2.8)):
            v, n, c, t = build(sdf, None, bmin, bmax, h * k)
            ao = c[:, 3:4]
            c[:, :3] = np.clip(0.42 + 0.58 * ao, 0, 1)
            save(os.path.join(OUT, "%s_%s.bin" % (name, q)), (v, n, c, t))
            print(name, q, len(t), "triangles")

if __name__ == "__main__":
    main()
