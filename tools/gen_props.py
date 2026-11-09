#!/usr/bin/env python3
"""Meubles et accessoires arrondis (SDF + surface nets, comme les animaux).
Couleur des sommets = occlusion ambiante ; la teinte vient du matériau en jeu.
Usage : python3 tools/gen_props.py  puis  godot --headless --path . -s tools/convert_models.gd"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from gen_models import sd_ellipsoid, sd_sphere, sd_round_cone, smin, smax, build, save, length

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "props")

def sd_rbox(P, c, half, r):
    q = np.abs(P - np.asarray(c, float)) - (np.asarray(half, float) - r)
    return length(np.maximum(q, 0.0)) + np.minimum(np.max(q, axis=-1), 0.0) - r

def sd_torus(P, c, R, r):
    Q = P - np.asarray(c, float)
    q = np.stack([np.sqrt(Q[..., 0] ** 2 + Q[..., 2] ** 2) - R, Q[..., 1]], axis=-1)
    return length(q) - r

def sd_cyl(P, c, r, h, rr=0.01):
    Q = P - np.asarray(c, float)
    d = np.stack([np.sqrt(Q[..., 0] ** 2 + Q[..., 2] ** 2) - r + rr, np.abs(Q[..., 1]) - h + rr], axis=-1)
    return np.minimum(np.maximum(d[..., 0], d[..., 1]), 0.0) + length(np.maximum(d, 0.0)) - rr

PROPS = {
    # canapé 1,9 x 0,8 m, origine au sol
    "sofa": (lambda P: smin(smin(smin(
        sd_rbox(P, (0, 0.24, 0.02), (0.95, 0.18, 0.38), 0.08),
        sd_rbox(P, (0, 0.58, -0.29), (0.93, 0.3, 0.11), 0.09), 0.04),
        smin(sd_rbox(P, (-0.88, 0.4, 0.0), (0.12, 0.24, 0.4), 0.1), sd_rbox(P, (0.88, 0.4, 0.0), (0.12, 0.24, 0.4), 0.1), 0.01), 0.04),
        smin(sd_rbox(P, (-0.4, 0.46, 0.06), (0.38, 0.07, 0.3), 0.06), sd_rbox(P, (0.4, 0.46, 0.06), (0.38, 0.07, 0.3), 0.06), 0.01), 0.02),
        (-1.05, -0.02, -0.45), (1.05, 0.92, 0.45), 0.022),
    "bed_basket": (lambda P: smin(sd_torus(P, (0, 0.11, 0), 0.38, 0.1), sd_cyl(P, (0, 0.05, 0), 0.4, 0.05, 0.03), 0.04),
        (-0.52, -0.02, -0.52), (0.52, 0.24, 0.52), 0.016),
    "cushion_bed": (lambda P: smin(sd_ellipsoid(P, (0, 0.09, 0), (0.42, 0.1, 0.36)), sd_torus(P, (0, 0.13, 0), 0.34, 0.08), 0.06),
        (-0.5, -0.02, -0.46), (0.5, 0.26, 0.46), 0.016),
    "kennel": (lambda P: smax(sd_rbox(P, (0, 0.42, 0), (0.5, 0.42, 0.5), 0.06), -sd_rbox(P, (0, 0.27, 0.5), (0.2, 0.27, 0.12), 0.08), 0.02),
        (-0.6, -0.02, -0.6), (0.6, 0.9, 0.6), 0.02),
    "kennel_roof": (lambda P: _roof(P), (-0.75, 0.75, -0.75), (0.75, 1.32, 0.75), 0.018),
    "bench": (lambda P: smin(smin(
        smin(sd_rbox(P, (0, 0.45, -0.15), (0.7, 0.03, 0.06), 0.02), smin(sd_rbox(P, (0, 0.45, 0.0), (0.7, 0.03, 0.06), 0.02), sd_rbox(P, (0, 0.45, 0.15), (0.7, 0.03, 0.06), 0.02), 0.005), 0.005),
        smin(sd_rbox(P, (0, 0.68, -0.25), (0.7, 0.06, 0.025), 0.02), sd_rbox(P, (0, 0.85, -0.25), (0.7, 0.06, 0.025), 0.02), 0.005), 0.005),
        smin(sd_rbox(P, (-0.6, 0.23, -0.05), (0.035, 0.23, 0.2), 0.02), sd_rbox(P, (0.6, 0.23, -0.05), (0.035, 0.23, 0.2), 0.02), 0.005), 0.01),
        (-0.8, -0.02, -0.35), (0.8, 0.95, 0.3), 0.014),
    "toybox": (lambda P: smin(sd_rbox(P, (0, 0.22, 0), (0.35, 0.22, 0.23), 0.04), sd_rbox(P, (0, 0.47, 0), (0.37, 0.05, 0.25), 0.04), 0.01),
        (-0.42, -0.02, -0.3), (0.42, 0.56, 0.3), 0.014),
    "bowl": (lambda P: smax(sd_cyl(P, (0, 0.045, 0), 0.19, 0.045, 0.03), -sd_cyl(P, (0, 0.085, 0), 0.15, 0.04, 0.02), 0.01),
        (-0.24, -0.02, -0.24), (0.24, 0.12, 0.24), 0.008),
    "pot": (lambda P: smax(sd_round_cone(P, (0, 0.02, 0), (0, 0.34, 0), 0.17, 0.21), -sd_cyl(P, (0, 0.36, 0), 0.17, 0.04, 0.01), 0.01),
        (-0.26, -0.02, -0.26), (0.26, 0.4, 0.26), 0.01),
}

def _roof(P):
    # toit à deux pans arrondi
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ridge = 1.22 - np.abs(x) * 0.6
    slab = np.abs(y - ridge) - 0.05
    return np.maximum(np.maximum(slab, np.abs(z) - 0.66), np.abs(x) - 0.66) - 0.02

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (sdf, bmin, bmax, h) in PROPS.items():
        for q, k in (("hi", 2.3), ("lo", 3.6)):
            v, n, c, t = build(sdf, None, bmin, bmax, h * k)
            ao = c[:, 3:4]
            c[:, :3] = np.clip(0.55 + 0.45 * ao, 0, 1)
            save(os.path.join(OUT, "%s_%s.bin" % (name, q)), (v, n, c, t))
            print(name, q, len(t), "triangles")

if __name__ == "__main__":
    main()
