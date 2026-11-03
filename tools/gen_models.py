#!/usr/bin/env python3
"""Génère les maillages 3D originaux des animaux de Patouille.

Méthode : champs de distance signés (SDF) combinés par union lisse, polygonisés
par « surface nets » (numpy), normales analytiques par gradient, puis masques de
pelage peints par régions (dégradés doux) et occlusion ambiante dans les couleurs
de sommets. Chaque pièce est exprimée dans le repère de son pivot d'animation
(PetModel.gd), pour rester compatible avec l'IK et les postures.

Sortie : assets/models/<race>/<pièce>_<hi|lo>.bin + meta.json
Format .bin : int32 nv, int32 ni, nv*(3f pos, 3f normale, 4f couleur), ni*int32.
Couleur : R = zone « seconde couleur », G = zone blanche, B = extrémités (points), A = occlusion.
Usage : python3 tools/gen_models.py
"""
import numpy as np, json, os, struct, math

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models")

# Mêmes valeurs que scripts/autoload/game_data.gd
BREEDS = {
    "labrador": dict(species="dog", body=(0.30, 0.27, 0.56), leg_len=0.27, leg_rad=0.065, head=0.19, snout=(0.15, 0.085), ear="floppy", ear_size=0.11, tail="otter", pattern="solid"),
    "shiba": dict(species="dog", body=(0.24, 0.22, 0.44), leg_len=0.22, leg_rad=0.052, head=0.165, snout=(0.11, 0.07), ear="pointy", ear_size=0.085, tail="curl", pattern="shiba"),
    "poodle": dict(species="dog", body=(0.22, 0.24, 0.40), leg_len=0.30, leg_rad=0.045, head=0.155, snout=(0.14, 0.06), ear="fluffy", ear_size=0.09, tail="pompom", pattern="poodle"),
    "shepherd": dict(species="dog", body=(0.30, 0.28, 0.62), leg_len=0.31, leg_rad=0.065, head=0.18, snout=(0.18, 0.08), ear="pointy", ear_size=0.12, tail="bushy", pattern="saddle"),
    "beagle": dict(species="dog", body=(0.24, 0.22, 0.46), leg_len=0.20, leg_rad=0.055, head=0.17, snout=(0.13, 0.064), ear="long", ear_size=0.13, tail="whip", pattern="beagle"),
    "cat": dict(species="cat", body=(0.19, 0.19, 0.42), leg_len=0.18, leg_rad=0.04, head=0.15, snout=(0.05, 0.06), ear="cat", ear_size=0.075, tail="cat", pattern="tabby"),
}
TAIL = {"otter": (3, 0.075, 0.042), "curl": (4, 0.055, 0.045), "pompom": (2, 0.07, 0.018),
        "bushy": (4, 0.08, 0.05), "whip": (3, 0.07, 0.03), "cat": (5, 0.07, 0.028)}

# ------------------------------------------------------------------ primitives SDF (P : (...,3))
def length(v): return np.sqrt(np.sum(v * v, axis=-1))

def sd_ellipsoid(P, c, r):
    r = np.asarray(r, float); q = (P - c) / r
    k0 = length(q); k1 = length(q / r)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

def sd_sphere(P, c, r): return length(P - np.asarray(c)) - r

def sd_round_cone(P, a, b, ra, rb):
    """Segment a->b à rayon variable (cône arrondi)."""
    a = np.asarray(a, float); b = np.asarray(b, float)
    ba = b - a; l2 = float(np.dot(ba, ba))
    pa = P - a
    h = np.clip(np.sum(pa * ba, axis=-1) / l2, 0.0, 1.0)
    d = length(pa - h[..., None] * ba)
    return d - (ra + (rb - ra) * h)

def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k): return -smin(-a, -b, k)

def fur(P, amp, freq):
    """Relief doux (mèches) : somme de sinus déphasés, sans motif visible."""
    x, y, z = P[..., 0] * freq, P[..., 1] * freq, P[..., 2] * freq
    n = np.sin(x * 1.7 + np.sin(y * 1.3)) * np.sin(y * 1.9 + np.sin(z * 1.1)) * np.sin(z * 1.5 + np.sin(x * 1.2))
    return n * amp

def soft(x, a, b):
    """Transition douce 0 -> 1 entre a et b."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

# ------------------------------------------------------------------ surface nets
def polygonize(sdf, bmin, bmax, h):
    bmin = np.asarray(bmin, float); bmax = np.asarray(bmax, float)
    n = np.maximum(np.ceil((bmax - bmin) / h).astype(int) + 1, 4)
    xs = [bmin[i] + np.arange(n[i]) * h for i in range(3)]
    G = np.stack(np.meshgrid(*xs, indexing="ij"), axis=-1)
    D = sdf(G)
    inside = D < 0
    nx, ny, nz = n
    corners = [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0), (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)]
    def cs(a, o): return a[o[0]:nx - 1 + o[0], o[1]:ny - 1 + o[1], o[2]:nz - 1 + o[2]]
    cnt = sum(cs(inside, c).astype(np.int32) for c in corners)
    active = (cnt > 0) & (cnt < 8)
    edges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]
    acc = np.zeros(active.shape + (3,)); num = np.zeros(active.shape)
    base = cs(G, (0, 0, 0))
    for a, b in edges:
        da = cs(D, corners[a]); db = cs(D, corners[b])
        m = (da < 0) != (db < 0)
        t = np.where(m, da / np.where(m, da - db, 1.0), 0.0)
        pa = base + np.array(corners[a]) * h; pb = base + np.array(corners[b]) * h
        p = pa + (pb - pa) * t[..., None]
        acc += np.where(m[..., None], p, 0.0); num += m
    idx = -np.ones(active.shape, dtype=np.int64)
    ai = np.argwhere(active)
    idx[tuple(ai.T)] = np.arange(len(ai))
    verts = acc[tuple(ai.T)] / num[tuple(ai.T)][:, None]
    faces = []
    # arêtes de la grille selon chaque axe
    for axis in range(3):
        o = [0, 0, 0]; o[axis] = 1
        a_in = inside[: nx - o[0], : ny - o[1], : nz - o[2]]
        b_in = inside[o[0]:, o[1]:, o[2]:]
        ch = a_in != b_in
        e = np.argwhere(ch)
        u, v = [i for i in range(3) if i != axis]
        ok = (e[:, u] >= 1) & (e[:, v] >= 1) & (e[:, u] < n[u] - 1) & (e[:, v] < n[v] - 1) & (e[:, axis] < n[axis] - 1)
        e = e[ok]
        flip = a_in[tuple(e.T)]
        def cell(du, dv):
            c = e.copy(); c[:, u] -= du; c[:, v] -= dv
            return idx[tuple(c.T)]
        c00, c10, c11, c01 = cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)
        q = np.stack([c00, c10, c11, c01], axis=1)
        q[flip] = q[flip][:, ::-1]
        if axis == 1:
            q = q[:, ::-1]
        faces.append(q)
    q = np.concatenate(faces)
    q = q[(q >= 0).all(axis=1)]
    tris = np.concatenate([q[:, [0, 1, 2]], q[:, [0, 2, 3]]])
    return verts, tris

def grad(sdf, P, e=1e-4):
    g = np.zeros_like(P)
    for i in range(3):
        d = np.zeros(3); d[i] = e
        g[:, i] = sdf(P + d) - sdf(P - d)
    return g / np.maximum(length(g), 1e-12)[:, None]

def build(sdf, paint, bmin, bmax, h):
    v, t = polygonize(sdf, bmin, bmax, h)
    for _ in range(2):   # projection sur la surface exacte
        nrm = grad(sdf, v)
        v = v - sdf(v)[:, None] * nrm
    nrm = grad(sdf, v)
    col = np.zeros((len(v), 4))
    col[:, :3] = paint(v, nrm) if paint else 0.0
    # occlusion ambiante : échantillons le long de la normale
    ao = np.zeros(len(v))
    for k, dist in enumerate((0.012, 0.03, 0.06)):
        ao += np.clip(sdf(v + nrm * dist) / dist, 0, 1) * (1.0 / (k + 1))
    col[:, 3] = np.clip(ao / (1 + 0.5 + 1 / 3), 0.0, 1.0) ** 0.8
    # orientation des triangles cohérente avec les normales
    fn = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    avg = nrm[t[:, 0]] + nrm[t[:, 1]] + nrm[t[:, 2]]
    bad = np.sum(fn * avg, axis=1) < 0
    t[bad] = t[bad][:, ::-1]
    return v, nrm, col, t

def save(path, mesh, mirror=False):
    v, n, c, t = mesh
    if mirror:
        v = v * [-1, 1, 1]; n = n * [-1, 1, 1]; t = t[:, ::-1]
    # Godot : triangles dans le sens horaire vu de face
    t = t[:, ::-1]
    data = np.concatenate([v, n, c], axis=1).astype("<f4")
    with open(path, "wb") as f:
        f.write(struct.pack("<ii", len(v), t.size))
        f.write(data.tobytes())
        f.write(t.astype("<i4").tobytes())

# ------------------------------------------------------------------ pièces
def make_breed(name, B, res_scale):
    bx, by, bz = B["body"]; L = B["leg_len"]; hr = B["head"]; lr = B["leg_rad"]
    sl, sw = B["snout"]; es = B["ear_size"]; pat = B["pattern"]; cat = B["species"] == "cat"
    hx, zf, zr, hy = bx * 0.3, bz * 0.3, -bz * 0.3, -by * 0.26
    neck_base = np.array([0, by * 0.28, bz * 0.38])
    head_pos = np.array([0, by * 0.3 + hr * (0.95 if cat else 1.05), bz * (0.44 if cat else 0.46) + hr * (0.3 if cat else 0.35)])
    fur_amp = {"poodle": 0.0045}.get(pat, 0.0)
    fur_f = 60.0 if pat == "poodle" else 55.0
    H = lambda base: base * res_scale
    meta = {"head_pos": head_pos.tolist()}
    parts = {}

    # ---------- torse + cou
    def torso(P):
        d = sd_ellipsoid(P, (0, by * 0.04, bz * 0.24), (bx * 0.5, by * 0.52, bz * 0.3))
        d = smin(d, sd_ellipsoid(P, (0, by * 0.02, -bz * 0.27), (bx * 0.48, by * 0.48, bz * 0.27)), 0.05)
        waist = 0.40 if cat else (0.36 if pat in ("shepherd", "poodle") else 0.42)
        d = smin(d, sd_ellipsoid(P, (0, by * 0.08, -bz * 0.02), (bx * waist, by * waist, bz * 0.35)), 0.06)
        top = head_pos * 0.82 + neck_base * 0.18
        d = smin(d, sd_round_cone(P, neck_base, top, hr * (0.62 if not cat else 0.55), hr * (0.5 if not cat else 0.45)), 0.05)
        for sx in (-1, 1):   # épaules et hanches
            d = smin(d, sd_ellipsoid(P, (sx * hx, hy * 0.2, zf), (lr * 1.7, by * 0.35, lr * 2.0)), 0.04)
            d = smin(d, sd_ellipsoid(P, (sx * hx * 1.05, hy * 0.1, zr), (lr * 2.0, by * 0.4, lr * 2.4)), 0.04)
        if pat in ("shepherd", "shiba"):   # collerette
            d = smin(d, sd_ellipsoid(P, neck_base + [0, -hr * 0.1, hr * 0.05], (hr * 0.85, hr * 0.85, hr * 0.7)), 0.05)
        if pat == "poodle":   # toison bouclée sur le poitrail
            d = smin(d, sd_ellipsoid(P, (0, by * 0.06, bz * 0.26), (bx * 0.62, by * 0.62, bz * 0.3)), 0.04)
            d = smin(d, sd_sphere(P, neck_base * 0.5 + head_pos * 0.5, hr * 0.8), 0.04)
        return d + fur(P, fur_amp, fur_f)

    def paint_torso(P, N):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        r = np.zeros(len(P)); g = np.zeros(len(P)); b = np.zeros(len(P))
        under = soft(-y, by * 0.05, by * 0.25)
        chest = soft(z, bz * 0.2, bz * 0.42) * soft(-y + by * 0.3, 0.0, by * 0.25) * soft(N[:, 2], 0.1, 0.6)
        throat = soft(N[:, 2] - N[:, 1] * 0.3, 0.2, 0.7) * soft(y, by * 0.2, by * 0.4)
        back = soft(y, by * 0.1, by * 0.3) * soft(z, -bz * 0.46, -bz * 0.36) * (1 - soft(z, bz * 0.2, bz * 0.34))
        if pat == "shiba":
            g = np.maximum(under * 0.95, np.maximum(chest, throat * soft(abs(x), 0, hr * 0.5)))
        elif pat == "beagle":
            r = back * (1 - soft(abs(x), bx * 0.42, bx * 0.5) * 0.0)
            g = np.maximum(under, np.maximum(chest, throat))
            g = g * (1 - r)
        elif pat == "saddle":
            r = soft(y, -by * 0.05, by * 0.15) * soft(z, -bz * 0.5, -bz * 0.3) * (1 - soft(z, bz * 0.15, bz * 0.3))
        elif pat == "tabby":
            bands = 0.5 + 0.5 * np.sin(z / bz * 22.0 + np.sin(x * 40.0) * 0.6)
            r = soft(bands, 0.55, 0.8) * soft(y, -by * 0.1, by * 0.15)
            g = under * 0.5
        elif pat == "solid":
            g = under * 0.25 * 0.0
        return np.stack([r, g, b], axis=1)

    e = max(bx, by, bz) * 0.6 + hr
    parts["torso"] = (torso, paint_torso, (-bx, -by, -bz * 0.62), (bx, head_pos[1] + hr * 0.2, bz * 0.62 + hr * 0.4), H(0.019))

    # ---------- tête (repère du pivot de tête)
    eye_r = hr * 0.2
    eye_p = np.array([hr * 0.4, hr * 0.12, hr * 0.8])
    snout_c = np.array([0, -hr * 0.28, hr * 0.78 + sl * 0.35])
    nose_p = snout_c + [0, sw * 0.45, sl * 0.78]
    if cat:
        nose_p = np.array([0, -hr * 0.12, hr * 0.98])

    def head_base(P, muzzle=True):
        d = sd_ellipsoid(P, (0, hr * 0.06, -hr * 0.04), (hr * 0.98, hr * 0.92, hr * 0.98))
        for sx in (-1, 1):
            d = smin(d, sd_ellipsoid(P, (sx * hr * 0.42, -hr * 0.28, hr * 0.3), (hr * 0.5, hr * 0.45, hr * 0.5)), 0.05)
            d = smin(d, sd_ellipsoid(P, (sx * hr * 0.36, hr * 0.33, hr * 0.62), (hr * 0.26, hr * 0.16, hr * 0.22)), 0.03)  # arcades
        if cat:
            for sx in (-1, 1):
                d = smin(d, sd_ellipsoid(P, (sx * hr * 0.17, -hr * 0.3, hr * 0.82), (hr * 0.24, hr * 0.2, hr * 0.18)), 0.03)
            d = smin(d, sd_ellipsoid(P, (0, -hr * 0.46, hr * 0.7), (hr * 0.2, hr * 0.14, hr * 0.16)), 0.03)
            d = smin(d, sd_ellipsoid(P, (0, -hr * 0.1, hr * 0.85), (hr * 0.12, hr * 0.12, hr * 0.14)), 0.03)
        elif muzzle:
            tip = snout_c + [0, 0, sl * 0.55]
            back = snout_c - [0, -sw * 0.15, sl * 0.6]
            m = sd_round_cone(P, back, tip, sw * 1.0, sw * 0.82)
            m = smax(m, -(P[..., 1] - (snout_c[1] - sw * 0.75)), 0.02)   # dessous aplati
            d = smin(d, m, 0.06)
            for sx in (-1, 1):   # babines
                jow = 1.1 if name == "labrador" else 1.0
                d = smin(d, sd_ellipsoid(P, tip + [sx * sw * 0.42, -sw * 0.55, -sl * 0.2], (sw * 0.55 * jow, sw * 0.42 * jow, sl * 0.45)), 0.03)
            d = smin(d, sd_ellipsoid(P, tip + [0, -sw * 0.9, -sl * 0.35], (sw * 0.5, sw * 0.25, sl * 0.4)), 0.03)  # menton
        if pat == "poodle":
            d = smin(d, sd_ellipsoid(P, (0, hr * 0.72, -hr * 0.05), (hr * 0.75, hr * 0.55, hr * 0.75)), 0.05)
        return d

    # Profondeur de la peau devant l'œil (sans orbite) : marche le long de -Z
    zs = np.linspace(hr * 1.4, 0.0, 600)
    probe = np.stack([np.full_like(zs, eye_p[0]), np.full_like(zs, eye_p[1]), zs], axis=1)
    dd = head_base(probe, muzzle=False)
    skin_z = float(zs[np.argmax(dd < 0)])
    eye_c = np.array([eye_p[0], eye_p[1], skin_z - eye_r * 0.5])

    def head(P):
        d = head_base(P)
        # orbites : l'œil est enchâssé, seul un dôme aplati dépasse
        for sx in (-1, 1):
            d = smax(d, -sd_ellipsoid(P, eye_c * [sx, 1, 1] + [0, 0, eye_r * 0.02], (eye_r * 0.88, eye_r * 0.9, eye_r * 0.7)), 0.02)
        return d + fur(P, fur_amp * 0.6, fur_f)

    def paint_head(P, N):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        r = np.zeros(len(P)); g = np.zeros(len(P))
        muzzle = soft(z, hr * 0.55, hr * 0.8) * soft(-y, -hr * 0.05, hr * 0.15)
        cheeks = soft(-y, hr * 0.15, hr * 0.35) * soft(z, hr * 0.0, hr * 0.4)
        b = muzzle.copy()   # extrémités (siamois)
        if pat == "shiba":
            g = np.maximum(muzzle, cheeks)
            g = np.maximum(g, soft(z, hr * 0.5, hr * 0.7) * soft(y, hr * 0.15, hr * 0.25) * soft(abs(x) - hr * 0.33, -0.02, 0.0) * 0)
        elif pat == "beagle":
            blaze = soft(hr * 0.12 - abs(x), 0.0, hr * 0.06) * soft(z, hr * 0.3, hr * 0.6) * soft(N[:, 2] + N[:, 1], 0.2, 0.8)
            g = np.maximum(muzzle, blaze)
        elif pat == "saddle":
            r = muzzle * soft(z, hr * 0.75, hr * 0.95) * 0.9 + soft(y, hr * 0.6, hr * 0.9) * 0.3
        elif pat == "tabby":
            stripes = soft(0.5 + 0.5 * np.sin(x / hr * 18.0), 0.6, 0.85) * soft(y, hr * 0.35, hr * 0.55) * soft(z, -hr * 0.1, hr * 0.3)
            r = stripes
            g = muzzle * 0.6
            b = np.maximum(muzzle, soft(z, hr * 0.5, hr * 0.75) * 0.7)
        elif pat == "solid":
            r = muzzle * 0.6
        return np.stack([r, g, b], axis=1)

    hb = hr * 1.1
    parts["head"] = (head, paint_head, (-hb, -hb, -hb), (hb, hb * 1.05, hr * 0.85 + sl * 1.25 + 0.02), H(0.0125))

    # ---------- truffe
    def nose(P):
        if cat:
            d = sd_ellipsoid(P, (0, 0, 0), (hr * 0.1, hr * 0.065, hr * 0.06))
            return smax(d, P[..., 1] - hr * 0.04, 0.01)
        d = sd_ellipsoid(P, (0, 0, 0), (sw * 0.48, sw * 0.32, sw * 0.3))
        d = smin(d, sd_ellipsoid(P, (0, -sw * 0.15, -sw * 0.05), (sw * 0.2, sw * 0.25, sw * 0.25)), 0.02)
        for sx in (-1, 1):
            d = smax(d, -sd_sphere(P, (sx * sw * 0.18, -sw * 0.05, sw * 0.27), sw * 0.08), 0.01)
        return d
    nb = sw * 0.7 if not cat else hr * 0.15
    parts["nose"] = (nose, None, (-nb, -nb, -nb), (nb, nb, nb), H(0.0045 if not cat else 0.0032))
    meta["nose"] = nose_p.tolist()
    meta["eye"] = eye_c.tolist()
    meta["eye_skin_z"] = skin_z
    meta["eye_r"] = eye_r

    # ---------- oreilles (repère du pivot ; oreille gauche x<0, la droite est miroir)
    et = B["ear"]
    def ear(P):
        x, y, z = P[..., 0], P[..., 1], P[..., 2]
        if et in ("pointy", "cat"):
            k = 1.0 if et == "pointy" else 0.85
            w = 1.25 if et == "cat" else 1.0
            Q = P.copy(); Q[..., 2] = z / 0.42
            d = sd_round_cone(Q, (0, 0, 0), (0, es * 1.45 * k, 0), es * 0.5 * k * w, es * 0.04)
            cup = sd_round_cone(Q - [0, es * 0.1, es * 0.55], (0, 0, 0), (0, es * 1.3 * k, 0), es * 0.38 * k * w, es * 0.02)
            d = smax(d, -cup, 0.01)
            return d * 0.42
        if et in ("floppy", "long"):
            ln = 1.4 if et == "floppy" else 2.0
            Q = P.copy()
            Q[..., 0] = x + (y / (es * ln)) ** 2 * es * 0.25   # courbure vers l'extérieur
            d = sd_ellipsoid(Q, (-es * 0.1, -es * ln * 0.42, 0), (es * 0.17, es * ln * 0.55, es * 0.48))
            d = smin(d, sd_ellipsoid(Q, (-es * 0.05, -es * 0.05, 0), (es * 0.2, es * 0.3, es * 0.4)), 0.03)
            return d
        # caniche : touffe bouclée
        d = sd_ellipsoid(P, (-es * 0.1, -es * 0.6, 0), (es * 0.55, es * 1.1, es * 0.6))
        return d + fur(P, 0.005, 70.0)
    def paint_ear(P, N):
        r = np.zeros(len(P)); g = np.zeros(len(P)); b = np.ones(len(P))
        if pat == "saddle":
            r = np.full(len(P), 0.7)
        if pat == "beagle":
            r = np.zeros(len(P))
        return np.stack([r, g, b], axis=1)
    eb = es * 2.3
    parts["ear"] = (ear, paint_ear, (-eb, -eb * 1.2, -eb * 0.6), (eb * 0.6, eb, eb * 0.6), H(0.0075))
    if et in ("pointy", "cat"):
        k = 1.0 if et == "pointy" else 0.85
        w = 1.25 if et == "cat" else 1.0
        def ear_in(P):
            Q = P.copy(); Q[..., 2] = (P[..., 2] - es * 0.06) / 0.2
            return sd_round_cone(Q - [0, es * 0.12, 0], (0, 0, 0), (0, es * 1.2 * k, 0), es * 0.33 * k * w, es * 0.02) * 0.2
        parts["ear_inner"] = (ear_in, None, (-eb * 0.5, -0.02, -0.02), (eb * 0.5, eb, eb * 0.3), H(0.006))

    # ---------- pattes (repère hanche -> genou, axe -Y)
    a = L * 0.52; bl = L * 0.5
    for front in (True, False):
        ur = lr * (1.1 if front else 1.25)
        def upper(P, front=front, ur=ur):
            d = sd_round_cone(P, (0, 0.01, 0), (0, -a, 0), ur * 1.15, lr * 0.95)
            if not front:
                d = smin(d, sd_ellipsoid(P, (0, -a * 0.18, -lr * 0.25), (ur * 1.35, a * 0.55, ur * 1.6)), 0.04)
            else:
                d = smin(d, sd_ellipsoid(P, (0, -a * 0.1, lr * 0.15), (ur * 1.25, a * 0.45, ur * 1.35)), 0.04)
            return d + fur(P, fur_amp * 0.7, fur_f)
        def lower(P, front=front):
            d = sd_round_cone(P, (0, 0.0, 0), (0, -bl + lr * 0.4, lr * 0.1), lr * 0.95, lr * 0.75)
            paw = sd_ellipsoid(P, (0, -bl + lr * 0.05, lr * 0.45), (lr * 1.2, lr * 0.62, lr * 1.5))
            paw = smax(paw, -(P[..., 1] + bl - lr * 0.45), 0.01)  # dessous plat
            d = smin(d, paw, 0.03)
            for k in range(4):   # orteils
                tx = (k - 1.5) * lr * 0.55
                d = smin(d, sd_sphere(P, (tx, -bl + lr * 0.12, lr * 1.25 - abs(k - 1.5) * lr * 0.12), lr * 0.36), 0.015)
            if pat == "poodle":
                d = smin(d, sd_sphere(P, (0, -bl * 0.75, 0), lr * 1.7) + fur(P, 0.005, 70.0), 0.03)
            return d + fur(P, fur_amp * 0.5, fur_f)
        def paint_lower(P, N):
            y = P[:, 1]
            g = np.zeros(len(P)); r = np.zeros(len(P))
            paws = soft(-y, bl * 0.55, bl * 0.8)
            if pat in ("shiba", "beagle"):
                g = soft(-y, bl * 0.2, bl * 0.5) if pat == "beagle" else paws
            if pat == "tabby":
                g = paws * 0.0
            b = soft(-y, bl * 0.35, bl * 0.65)
            return np.stack([r, g, b], axis=1)
        def paint_upper(P, N):
            r = np.zeros(len(P)); g = np.zeros(len(P)); b = np.zeros(len(P))
            if pat == "saddle":
                r = soft(P[:, 1], -a * 0.2, a * 0.1) * 0.8
            return np.stack([r, g, b], axis=1)
        tag = "front" if front else "rear"
        m = ur * 2.2
        parts["leg_upper_" + tag] = (upper, paint_upper, (-m, -a - lr * 1.5, -m), (m, m * 0.6, m), H(0.011))
        parts["leg_lower_" + tag] = (lower, paint_lower, (-lr * 2.2, -bl - lr * 1.2, -lr * 1.6), (lr * 2.2, lr * 1.2, lr * 2.2), H(0.0085))

    # ---------- queue (segments, axe -Z)
    n, seg_len, r0 = TAIL[B["tail"]]
    tt = B["tail"]
    for i in range(n):
        ra = r0 * (1.0 - i / (n + 1) * (0.5 if tt != "bushy" else 0.2))
        rb = r0 * (1.0 - (i + 1) / (n + 1) * (0.5 if tt != "bushy" else 0.2))
        if i == n - 1 and tt in ("whip", "cat", "otter"):
            rb *= 0.6
        fluffy = tt in ("bushy", "curl")
        def seg(P, ra=ra, rb=rb, fluffy=fluffy, last=(i == n - 1)):
            d = sd_round_cone(P, (0, 0, 0.004), (0, 0, -seg_len), ra * (1.25 if fluffy else 1.0), rb * (1.25 if fluffy else 1.0))
            if tt == "pompom" and last:
                d = smin(d, sd_sphere(P, (0, 0, -seg_len * 1.1), 0.075) + fur(P, 0.005, 70.0), 0.02)
            return d + fur(P, 0.006 if fluffy else 0.0, 45.0)
        def paint_seg(P, N, i=i):
            r = np.zeros(len(P)); g = np.zeros(len(P)); b = np.ones(len(P))
            z = -P[:, 2] / seg_len
            if tt in ("whip", "curl") and i == n - 1:
                g = soft(z, 0.2, 0.7)
            if pat == "beagle" and i < n - 1:
                r = np.ones(len(P))
            if pat == "saddle":
                r = soft(P[:, 1], -ra * 0.5, ra * 0.5) * 0.9 + (0.6 if i == n - 1 else 0.0)
            if pat == "shiba":
                g = np.maximum(g, soft(-P[:, 1], ra * 0.2, ra * 0.8))
            if pat == "tabby":
                r = soft(0.5 + 0.5 * np.sin((z + i) * math.pi * 2.0), 0.6, 0.85)
            return np.stack([np.clip(r, 0, 1), g, b], axis=1)
        m = max(ra, rb) * 1.6 + (0.09 if tt == "pompom" and i == n - 1 else 0.01)
        parts["tail_%d" % i] = (seg, paint_seg, (-m, -m, -seg_len - m - (0.06 if tt == "pompom" else 0)), (m, m, m), H(0.0085))
    meta["tail_segments"] = n
    meta["tail_len"] = seg_len
    return parts, meta

def main():
    for name, B in BREEDS.items():
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        for q, rs in (("hi", 1.0), ("lo", 1.65)):
            parts, meta = make_breed(name, B, rs)
            stats = 0
            for pname, (sdf, paint, bmin, bmax, h) in parts.items():
                mesh = build(sdf, paint, bmin, bmax, h)
                stats += len(mesh[3])
                save(os.path.join(d, "%s_%s.bin" % (pname, q)), mesh)
                if pname.startswith("ear"):
                    save(os.path.join(d, "%s_r_%s.bin" % (pname, q)), mesh, mirror=True)
            meta["parts"] = sorted(parts.keys())
            with open(os.path.join(d, "meta.json"), "w") as f:
                json.dump(meta, f, indent=1)
            print(name, q, "triangles:", stats)

if __name__ == "__main__":
    main()
