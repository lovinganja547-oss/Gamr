package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Rng;

/** Système de particules à mémoire fixe, en coordonnées monde. */
final class Particles {
    static final int DOT = 0, SPARK = 1, RING = 2, SHARD = 3;
    private static final int MAX = 700;
    private final float[] x = new float[MAX], y = new float[MAX], vx = new float[MAX], vy = new float[MAX];
    private final float[] life = new float[MAX], max = new float[MAX], size = new float[MAX], grav = new float[MAX];
    private final int[] color = new int[MAX], type = new int[MAX];
    private int count;
    final Rng rng = new Rng(3);

    void clear() { count = 0; }

    int count() { return count; }

    void spawn(int t, float px, float py, float pvx, float pvy, float lifeS, float sz, int col, float g) {
        if (count >= MAX) return;
        int i = count++;
        type[i] = t; x[i] = px; y[i] = py; vx[i] = pvx; vy[i] = pvy;
        life[i] = max[i] = lifeS; size[i] = sz; color[i] = col; grav[i] = g;
    }

    void burst(int t, float px, float py, int n, float spMin, float spMax, float lifeS, float sz, int col) {
        for (int k = 0; k < n; k++) {
            float a = rng.nextFloat() * 6.2831855f;
            float s = rng.range(spMin, spMax);
            spawn(t, px, py, (float) Math.cos(a) * s, (float) Math.sin(a) * s,
                    lifeS * rng.range(0.6f, 1.2f), sz * rng.range(0.6f, 1.3f), col, 0f);
        }
    }

    void update(float dt) {
        for (int i = 0; i < count; ) {
            life[i] -= dt;
            if (life[i] <= 0f) {
                int l = --count;
                x[i] = x[l]; y[i] = y[l]; vx[i] = vx[l]; vy[i] = vy[l]; life[i] = life[l]; max[i] = max[l];
                size[i] = size[l]; grav[i] = grav[l]; color[i] = color[l]; type[i] = type[l];
                continue;
            }
            float drag = type[i] == RING ? 1f : (1f - Math.min(0.9f, dt * 2.2f));
            vx[i] *= drag;
            vy[i] = vy[i] * drag - grav[i] * dt;
            x[i] += vx[i] * dt;
            y[i] += vy[i] * dt;
            i++;
        }
    }

    /** Dessin : u = pixels par unité monde, base = ordonnée écran du bas, cam = y monde du bas de l'écran. */
    void draw(Canvas c, Gfx g, float u, float base, float cam, float ox, float oy) {
        for (int i = 0; i < count; i++) {
            float k = life[i] / max[i];
            float sx = x[i] * u + ox, sy = base - (y[i] - cam) * u + oy;
            int col = color[i];
            switch (type[i]) {
                case DOT: {
                    float r = size[i] * u * (0.4f + 0.6f * k);
                    g.circle(c, sx, sy, r, Palette.alpha(col, k));
                    break;
                }
                case SPARK: {
                    float len = 0.035f;
                    g.line(c, sx, sy, sx - vx[i] * len * u, sy + vy[i] * len * u, Palette.alpha(col, k), size[i] * u * k + 1f);
                    break;
                }
                case RING: {
                    float r = size[i] * u * (1f - k) + 2f;
                    g.ring(c, sx, sy, r, Palette.alpha(col, k * 0.9f), (3f + 6f * k) * u);
                    break;
                }
                default: {
                    float r = size[i] * u * (0.5f + 0.5f * k);
                    g.polygon(c, sx, sy, r, 3, life[i] * 9f + i, Palette.alpha(col, k), 0f, true);
                    break;
                }
            }
        }
    }
}
