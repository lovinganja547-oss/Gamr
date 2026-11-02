package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Skins;

/** Rendu des sphères et de leurs traînées selon le skin. */
final class SkinPainter {
    private final Gfx g;
    private final Particles fx;

    SkinPainter(Gfx g, Particles fx) { this.g = g; this.fx = fx; }

    static int glowColor(Skins.Skin s, float time) {
        return s.trail == Skins.TRAIL_RAINBOW ? Palette.hue(time * 0.35f) : s.glow;
    }

    /** Sphère en coordonnées écran ; r = rayon en pixels. */
    void sphere(Canvas c, Skins.Skin s, float x, float y, float r, float time, float tilt) {
        final int glow = glowColor(s, time);
        final int accent = s.trail == Skins.TRAIL_RAINBOW ? Palette.hue(time * 0.35f + 0.5f) : s.accent;
        float pulse = 1f + 0.06f * (float) Math.sin(time * 6f);

        if (s.deco == Skins.DECO_RGB) {
            float j = r * (0.12f + 0.06f * (float) Math.sin(time * 23f));
            g.circle(c, x - j, y, r, Palette.withAlpha(0xFFFF1F8F, 150));
            g.circle(c, x + j, y, r, Palette.withAlpha(0xFF00F0FF, 150));
        }
        g.glow(c, x, y, r * 3.1f * pulse, glow, 0.9f);

        switch (s.deco) {
            case Skins.DECO_RAYS: {
                for (int i = 0; i < 10; i++) {
                    double a = time * 1.6f + i * Math.PI / 5;
                    float l = r * (1.45f + 0.25f * (float) Math.sin(time * 7f + i));
                    g.line(c, x + (float) Math.cos(a) * r * 1.05f, y + (float) Math.sin(a) * r * 1.05f,
                            x + (float) Math.cos(a) * l, y + (float) Math.sin(a) * l, Palette.withAlpha(accent, 200), r * 0.16f);
                }
                break;
            }
            case Skins.DECO_SPIKES: {
                for (int i = 0; i < 7; i++) {
                    double a = i * Math.PI * 2 / 7 + time * 3f;
                    float l = r * (1.25f + 0.35f * Math.abs((float) Math.sin(time * 17f + i * 3)));
                    g.line(c, x + (float) Math.cos(a) * r * 0.95f, y + (float) Math.sin(a) * r * 0.95f,
                            x + (float) Math.cos(a + 0.25) * l, y + (float) Math.sin(a + 0.25) * l, accent, r * 0.1f);
                }
                break;
            }
            default:
                break;
        }

        // Corps
        g.circle(c, x, y, r, glow);
        if (s.deco == Skins.DECO_DARK) {
            g.circle(c, x, y, r * 0.82f, s.core);
            g.ring(c, x, y, r * 0.86f, Palette.withAlpha(accent, 230), r * 0.14f);
            g.circle(c, x - r * 0.28f, y - r * 0.3f, r * 0.14f, Palette.withAlpha(Palette.WHITE, 160));
        } else {
            g.circle(c, x, y, r * 0.7f, Palette.lerp(glow, s.core, 0.6f));
            g.circle(c, x, y, r * 0.48f, s.core);
            g.circle(c, x - r * 0.3f + tilt * r * 0.1f, y - r * 0.32f, r * 0.2f, Palette.withAlpha(Palette.WHITE, 220));
        }

        switch (s.deco) {
            case Skins.DECO_PULSE: {
                float p = (time * 1.3f) % 1f;
                g.ring(c, x, y, r * (1.1f + p * 1.4f), Palette.alpha(accent, 1f - p), r * 0.12f);
                break;
            }
            case Skins.DECO_FACETS:
                g.polygon(c, x, y, r * 0.78f, 6, time * 1.2f, Palette.withAlpha(Palette.WHITE, 200), r * 0.08f, false);
                g.polygon(c, x, y, r * 1.18f, 6, -time * 0.8f, Palette.withAlpha(accent, 170), r * 0.06f, false);
                break;
            case Skins.DECO_MOONS:
                for (int i = 0; i < 2; i++) {
                    double a = time * (i == 0 ? 3.2 : -2.4) + i * 2.0;
                    float d = r * (i == 0 ? 1.7f : 2.1f);
                    float mx = x + (float) Math.cos(a) * d, my = y + (float) Math.sin(a) * d * 0.55f;
                    g.glow(c, mx, my, r * 0.9f, accent, 0.8f);
                    g.circle(c, mx, my, r * (i == 0 ? 0.26f : 0.2f), Palette.WHITE);
                }
                break;
            case Skins.DECO_RINGS:
                c.save();
                c.translate(x, y);
                c.rotate(time * 40f);
                g.rect.set(-r * 1.9f, -r * 0.55f, r * 1.9f, r * 0.55f);
                g.stroke.setColor(Palette.withAlpha(accent, 210));
                g.stroke.setStrokeWidth(r * 0.1f);
                c.drawOval(g.rect, g.stroke);
                c.rotate(70f);
                g.rect.set(-r * 1.6f, -r * 0.45f, r * 1.6f, r * 0.45f);
                g.stroke.setColor(Palette.withAlpha(glow, 200));
                c.drawOval(g.rect, g.stroke);
                c.restore();
                break;
            case Skins.DECO_DNA: {
                for (int i = 0; i < 3; i++) {
                    double a = time * 4.0 + i * 2.094;
                    float d = r * 1.45f;
                    float ax = x + (float) Math.cos(a) * d, ay = y + (float) Math.sin(a) * d * 0.4f;
                    float bx = x - (float) Math.cos(a) * d, by = y - (float) Math.sin(a) * d * 0.4f;
                    g.line(c, ax, ay, bx, by, Palette.withAlpha(Palette.WHITE, 70), r * 0.06f);
                    g.circle(c, ax, ay, r * 0.17f, s.glow);
                    g.circle(c, bx, by, r * 0.17f, accent);
                }
                break;
            }
            case Skins.DECO_CORE: {
                float f = 0.75f + 0.25f * (float) Math.sin(time * 19f) * (float) Math.sin(time * 7f);
                g.circle(c, x, y, r * 0.3f * f, Palette.WHITE);
                break;
            }
            default:
                break;
        }
    }

    /** Traînée ; transforme les coordonnées monde en écran. Émet des particules selon le style. */
    void trail(Canvas c, Skins.Skin s, Trail t, float u, float base, float cam, float time, float ox, float oy, boolean emit) {
        int n = t.count;
        if (n < 2) return;
        final int glow = glowColor(s, time);
        final float baseW = 2f * 26f * u * 0.82f;
        float px = t.x(0) * u + ox, py = base - (t.y(0) - cam) * u + oy;
        for (int i = 1; i < n; i++) {
            float k = 1f - i / (float) n;
            float qx = t.x(i) * u + ox, qy = base - (t.y(i) - cam) * u + oy;
            float wdt = baseW * k;
            switch (s.trail) {
                case Skins.TRAIL_ZIGZAG: {
                    float j = ((i & 1) == 0 ? 1f : -1f) * 10f * u * (0.6f + 0.4f * (float) Math.sin(time * 40f + i));
                    g.line(c, px, py, qx + j, qy, Palette.alpha(glow, k * 0.35f), wdt * 0.9f);
                    g.line(c, px, py, qx + j, qy, Palette.alpha(s.accent, k), Math.max(2f, wdt * 0.18f));
                    qx += j;
                    break;
                }
                case Skins.TRAIL_HELIX: {
                    float a = i * 0.55f - time * 9f;
                    float off = (float) Math.sin(a) * 16f * u * (0.4f + k);
                    float offB = (float) Math.sin(a + 3.1416f) * 16f * u * (0.4f + k);
                    float pa = (float) Math.sin(a + 0.55f) * 16f * u * (0.4f + Math.min(1f, k + 1f / n));
                    float pb = (float) Math.sin(a + 0.55f + 3.1416f) * 16f * u * (0.4f + Math.min(1f, k + 1f / n));
                    g.line(c, px + pa, py, qx + off, qy, Palette.alpha(s.glow, k), Math.max(2f, wdt * 0.25f));
                    g.line(c, px + pb, py, qx + offB, qy, Palette.alpha(s.accent, k), Math.max(2f, wdt * 0.25f));
                    break;
                }
                case Skins.TRAIL_RAINBOW: {
                    int col = Palette.hue(time * 0.35f + i * 0.035f);
                    g.line(c, px, py, qx, qy, Palette.alpha(col, k * 0.4f), wdt);
                    g.line(c, px, py, qx, qy, Palette.alpha(col, k), wdt * 0.35f);
                    break;
                }
                case Skins.TRAIL_GLITCH: {
                    float j = 6f * u;
                    g.line(c, px - j, py, qx - j, qy, Palette.alpha(0xFF00F0FF, k * 0.8f), wdt * 0.4f);
                    g.line(c, px + j, py, qx + j, qy, Palette.alpha(0xFFFF1F8F, k * 0.8f), wdt * 0.4f);
                    if (((int) (time * 20f) + i) % 7 == 0) {
                        g.fill.setColor(Palette.alpha(Palette.WHITE, k * 0.7f));
                        c.drawRect(qx - wdt * 0.6f, qy - 3f * u, qx + wdt * 0.6f, qy + 3f * u, g.fill);
                    }
                    break;
                }
                case Skins.TRAIL_STARS:
                    g.line(c, px, py, qx, qy, Palette.alpha(glow, k * 0.28f), wdt);
                    g.line(c, px, py, qx, qy, Palette.alpha(s.accent, k * 0.6f), wdt * 0.15f);
                    break;
                default:
                    g.line(c, px, py, qx, qy, Palette.alpha(glow, k * 0.28f), wdt);
                    g.line(c, px, py, qx, qy, Palette.alpha(Palette.lerp(glow, Palette.WHITE, 0.5f), k * 0.9f), wdt * 0.3f);
                    break;
            }
            px = qx; py = qy;
        }

        if (!emit || fx == null) return;
        float hx = t.x(0), hy = t.y(0);
        Particles p = fx;
        switch (s.trail) {
            case Skins.TRAIL_EMBERS:
                p.spawn(Particles.DOT, hx + p.rng.range(-12f, 12f), hy - 10f, p.rng.range(-40f, 40f), p.rng.range(-60f, 30f),
                        0.5f, p.rng.range(4f, 8f), p.rng.chance(0.5f) ? s.accent : s.glow, -40f);
                break;
            case Skins.TRAIL_SPARKLE:
                if (p.rng.chance(0.6f))
                    p.spawn(Particles.SHARD, hx + p.rng.range(-20f, 20f), hy - 15f, 0f, -20f, 0.6f, p.rng.range(4f, 7f), Palette.WHITE, 0f);
                break;
            case Skins.TRAIL_DRIP:
                if (p.rng.chance(0.5f))
                    p.spawn(Particles.DOT, hx + p.rng.range(-14f, 14f), hy - 18f, 0f, 0f, 0.7f, p.rng.range(4f, 7f), s.glow, 260f);
                break;
            case Skins.TRAIL_STARS:
                if (p.rng.chance(0.7f))
                    p.spawn(Particles.DOT, hx + p.rng.range(-30f, 30f), hy - p.rng.range(10f, 60f), 0f, 0f, 0.9f,
                            p.rng.range(2f, 4.5f), p.rng.chance(0.3f) ? s.accent : Palette.WHITE, 0f);
                break;
            default:
                break;
        }
    }
}
