#!/usr/bin/env python3
"""Génère tous les sons originaux de Truffe & Co (synthèse procédurale, aucune ressource externe).
Usage : python3 tools/gen_audio.py  -> écrit assets/audio/*.wav"""
import numpy as np, struct, os, wave
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1234)

def t(d): return np.arange(int(SR * d)) / SR

def env(n, a=0.01, r=0.1):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e

def lp(x, k):  # filtre passe-bas 1 pôle
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc); y[i] = acc
    return y

def hp(x, k): return x - lp(x, k)

def bp(x, f, q=5.0):  # biquad passe-bande
    w = 2 * np.pi * f / SR; al = np.sin(w) / (2 * q)
    b0, b2 = al, -al; a0, a1, a2 = 1 + al, -2 * np.cos(w), 1 - al
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = (b0 * v + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, o; y[i] = o
    return y

def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0; return x / m * peak

def save(name, x, loop=False, sr=SR):
    x = np.clip(x, -1, 1); data = (x * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name + ".wav")
    with open(path, "wb") as f:
        chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, sr, sr * 2, 2, 16)
        if loop:
            smpl = struct.pack("<9I", 0, 0, 0, 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
            chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
        chunks += b"data" + struct.pack("<I", len(data)) + data
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)

def bark(f0, dur, bright=1.0):
    tt = t(dur); n = len(tt)
    f = f0 * (1 + 0.35 * np.exp(-tt * 18)) * (1 - 0.25 * tt / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = np.sign(np.sin(ph)) * 0.5 + np.sin(ph) * 0.5 + rng.normal(0, 0.35, n)
    y = bp(src, f0 * 2.2, 3) * 1.0 + bp(src, f0 * 4.5 * bright, 4) * 0.6 + bp(src, 2600 * bright, 6) * 0.25
    return norm(y * env(n, 0.006, dur * 0.6))

def meow(f0=520, dur=0.7):
    tt = t(dur); n = len(tt); x = tt / dur
    f = f0 * (0.85 + 0.45 * np.sin(np.pi * x) ** 1.5) * (1 - 0.15 * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum(np.sin(ph * k) / k for k in range(1, 9)) + rng.normal(0, 0.05, n)
    form = 900 + 1400 * np.sin(np.pi * np.clip(x * 1.3, 0, 1))
    y = bp(src, 1100, 2) * 0.7 + bp(src, 2400, 3) * 0.5
    y *= (0.6 + 0.4 * np.sin(np.pi * x)); _ = form
    return norm(y * env(n, 0.04, 0.2))

def tone(freqs, dur, decay=4.0, harm=(1, 0.4, 0.15), a=0.005):
    tt = t(dur); y = np.zeros(len(tt))
    for fr in freqs:
        for k, amp in enumerate(harm, 1):
            y += amp * np.sin(2 * np.pi * fr * k * tt)
    return y * np.exp(-tt * decay) * env(len(tt), a, 0.02)

def noise(dur): return rng.normal(0, 1, int(SR * dur))

def cat(*xs): return np.concatenate(xs)
def sil(d): return np.zeros(int(SR * d))

def gen_sfx():
    save("bark_small", bark(620, 0.16, 1.3))
    save("bark_mid", bark(420, 0.2, 1.0))
    save("bark_big", bark(260, 0.26, 0.8))
    save("yip", cat(bark(700, 0.1, 1.4) * 0.8, sil(0.05), bark(760, 0.1, 1.4)))
    save("meow", meow())
    save("meow_short", meow(600, 0.35))
    # ronronnement
    tt = t(1.6); n = len(tt)
    purr = lp(noise(1.6), 0.05) * (0.55 + 0.45 * np.sin(2 * np.pi * 24 * tt)) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.62 * tt))
    save("purr", norm(purr * env(n, 0.2, 0.3), 0.6))
    # halètement
    p = []
    for i in range(4):
        d = 0.18; nn = noise(d); p.append(bp(nn, 1500, 1.5) * env(len(nn), 0.03, 0.12) * (0.8 if i % 2 else 1)); p.append(sil(0.07))
    save("pant", norm(cat(*p), 0.5))
    tt = t(0.7); f = 900 + 300 * np.sin(np.pi * tt / 0.7)
    save("whine", norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.05, 0.3) * (0.8 + 0.2 * np.sin(2 * np.pi * 7 * tt)), 0.5))
    # reniflement
    s = []
    for i in range(3):
        nn = noise(0.07); s.append(hp(bp(nn, 3500, 1.2), 0.2) * env(len(nn), 0.01, 0.04)); s.append(sil(0.06))
    save("sniff", norm(cat(*s), 0.6))
    save("chime", norm(cat(tone([784], 0.12, 8), tone([1046.5], 0.5, 5)) , 0.6))
    save("coin", norm(cat(tone([1318.5], 0.07, 10, (1, 0.3)), tone([1975.5], 0.35, 7, (1, 0.3))), 0.55))
    save("click", norm(tone([1200], 0.05, 60, (1, 0.5, 0.3)), 0.5))
    save("pop", norm(np.sin(2 * np.pi * np.cumsum(np.linspace(300, 900, int(SR * 0.08))) / SR) * env(int(SR * 0.08), 0.002, 0.05), 0.6))
    tt = t(0.5); f = 1800 + 600 * np.sin(np.pi * tt / 0.5)
    save("whistle", norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.03, 0.15), 0.5))
    nn = noise(0.5); save("splash", norm(bp(nn, 1800, 0.8) * np.exp(-t(0.5) * 7), 0.6))
    b = []
    for i in range(5):
        d = 0.06; tt = t(d); f = 500 + 1500 * tt / d + rng.uniform(-100, 100)
        b.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.005, 0.03)); b.append(sil(rng.uniform(0.02, 0.08)))
    save("bubble", norm(cat(*b), 0.45))
    nn = noise(0.25); cam = cat(hp(nn[:1500], 0.4) * env(1500, 0.001, 0.02), sil(0.06), hp(nn[:2200], 0.3) * env(2200, 0.001, 0.05))
    save("camera", norm(cam, 0.6))
    save("bounce", norm(np.sin(2 * np.pi * 140 * t(0.12)) * np.exp(-t(0.12) * 35) + lp(noise(0.12), 0.3) * np.exp(-t(0.12) * 60) * 0.5, 0.7))
    save("success", norm(cat(tone([523.25, 659.25], 0.12, 6), tone([659.25, 783.99], 0.12, 6), tone([783.99, 1046.5], 0.6, 3)), 0.6))
    save("fail", norm(cat(tone([392], 0.18, 5), tone([330], 0.4, 4)), 0.5))
    save("levelup", norm(cat(*[tone([f], 0.09, 6) for f in (523.25, 659.25, 783.99, 1046.5)], tone([1046.5, 1318.5, 1568], 0.9, 2.5)), 0.6))
    c = []
    for i in range(4):
        nn = noise(0.06); c.append(bp(nn, 2200 + rng.uniform(-400, 400), 2) * env(len(nn), 0.002, 0.04)); c.append(sil(0.08))
    save("crunch", norm(cat(*c), 0.6))
    l = []
    for i in range(4):
        tt = t(0.07); l.append(np.sin(2 * np.pi * np.cumsum(np.linspace(400, 1200, len(tt))) / SR) * env(len(tt), 0.005, 0.04) * 0.6 + bp(noise(0.07), 1500, 2) * 0.3); l.append(sil(0.09))
    save("lap", norm(cat(*l), 0.5))
    nn = noise(0.35); save("whoosh", norm(bp(nn, 900, 0.7) * np.sin(np.pi * t(0.35) / 0.35) ** 2, 0.5))
    save("heart", norm(cat(tone([880], 0.08, 10), tone([1174.66], 0.25, 8)), 0.4))
    save("buzz", norm(np.sign(np.sin(2 * np.pi * 110 * t(0.3))) * env(int(SR * 0.3), 0.01, 0.05) * 0.5, 0.35))
    save("tick", norm(tone([2000], 0.03, 80, (1,)), 0.4))
    save("cheer", norm(lp(noise(1.2), 0.25) * env(int(SR * 1.2), 0.15, 0.6) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t(1.2))), 0.5))

def piano(fr, dur, vel=1.0):
    tt = t(dur)
    y = (np.sin(2 * np.pi * fr * tt) + 0.35 * np.sin(4 * np.pi * fr * tt) * np.exp(-tt * 3) + 0.12 * np.sin(6 * np.pi * fr * tt) * np.exp(-tt * 5))
    return y * np.exp(-tt * 2.2) * env(len(tt), 0.004, 0.08) * vel

def music(name, bpm, prog, scale, seed, dur_bars=16, bright=1.0):
    r = np.random.default_rng(seed); beat = 60 / bpm; bar = beat * 4
    total = int(SR * bar * dur_bars); y = np.zeros(total + SR * 3)
    for b in range(dur_bars):
        root = prog[b % len(prog)]; s0 = int(b * bar * SR)
        chord = [root, root * 1.2599, root * 1.4983]
        for i, fr in enumerate(chord):   # nappe douce
            pad = np.sin(2 * np.pi * fr * t(bar)) * 0.08 * np.sin(np.pi * t(bar) / bar)
            y[s0:s0 + len(pad)] += pad
        for k in range(4):  # arpège
            fr = chord[(k * 2) % 3] * (2 if k % 2 else 1)
            n = piano(fr, beat * 1.8, 0.18); st = s0 + int(k * beat * SR); y[st:st + len(n)] += n
        for k in range(8):  # mélodie pentatonique
            if r.random() < 0.55:
                fr = scale[r.integers(0, len(scale))] * 2 * bright
                n = piano(fr, beat * 1.5, 0.22); st = s0 + int(k * beat / 2 * SR); y[st:st + len(n)] += n
        bass = piano(root / 2, bar, 0.3); y[s0:s0 + len(bass)] += bass
    tail = y[total:total + SR * 3]; y = y[:total]; y[:len(tail)] += tail  # bouclage sans coupure
    save(name, norm(lp(y, 0.5), 0.55), loop=True)

def ambience():
    d = 12.0; n = int(SR * d); tt = t(d)
    def loopfade(x):
        f = int(SR * 1.0); out = x[:n].copy(); out[:f] = out[:f] * np.linspace(0, 1, f) + x[n:n + f] * np.linspace(1, 0, f); return out
    def birds(count, seed):
        r = np.random.default_rng(seed); y = np.zeros(n + SR)
        for i in range(count):
            st = r.integers(0, n); base = r.uniform(2500, 4200)
            for j in range(r.integers(2, 6)):
                dd = r.uniform(0.04, 0.1); tt2 = t(dd); f = base * (1 + 0.3 * np.sin(np.pi * tt2 / dd * r.uniform(1, 3)))
                s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt2), 0.005, 0.03) * 0.25
                p = st + int(j * 0.12 * SR); y[p:p + len(s)] += s[: len(y) - p]
        return y
    nz = rng.normal(0, 1, n + SR)
    wind = lp(nz, 0.01) * 3; wind *= 0.6 + 0.4 * np.sin(2 * np.pi * cat(tt, t(1.0)) / 6)
    save("amb_house", norm(loopfade(lp(nz, 0.02) * 0.3 + np.pad(np.tile(cat(tone([2400], 0.02, 100, (1,)), sil(0.98)), 13)[: n + SR], (0, 0)) * 0.15), 0.25), loop=True)
    save("amb_garden", norm(loopfade(wind * 0.5 + birds(14, 5)), 0.35), loop=True)
    save("amb_park", norm(loopfade(wind + birds(9, 8) + lp(rng.normal(0, 1, n + SR), 0.05) * 0.4), 0.35), loop=True)
    tt2 = cat(tt, t(1.0)); waves = lp(rng.normal(0, 1, n + SR), 0.08) * (0.3 + 0.7 * np.sin(np.pi * (tt2 % 6) / 6) ** 2) * 2
    save("amb_beach", norm(loopfade(waves + birds(3, 11) * 0.5), 0.4), loop=True)
    crowd = sum(bp(rng.normal(0, 1, n + SR), f, 2) for f in (300, 600, 1100)) * 0.5
    save("amb_center", norm(loopfade(crowd * (0.8 + 0.2 * np.sin(2 * np.pi * tt2 / 4)) + wind * 0.3), 0.25), loop=True)
    yb = lp(rng.normal(0, 1, n + SR), 0.02) * 0.4
    for st, f0 in ((2.0, 520), (5.5, 380), (9.0, 600)):
        b = bark(f0, 0.18) * 0.18; p = int(st * SR); yb[p:p + len(b)] += b
    save("amb_shelter", norm(loopfade(yb + birds(4, 21) * 0.5), 0.3), loop=True)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gen_sfx()
    C, D, E, F, G, A, B = 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88
    music("music_home", 76, [F, C, D * 0.89, A * 0.5 * 1.0], [C, D, E, G, A], 3)
    music("music_play", 112, [C, G * 0.5, A * 0.5, F * 0.5], [C, D, E, G, A], 9, bright=1.0)
    music("music_title", 84, [D, A * 0.5, B * 0.5, G * 0.5], [D, E, F * 1.0595, A, B], 17, dur_bars=12)
    ambience()
    print("ok", len(os.listdir(OUT)), "fichiers")
