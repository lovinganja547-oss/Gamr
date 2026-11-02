package com.neonrush.app;

import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;

import com.neonrush.core.Rng;

/** Fond animé : dégradé, grille en perspective, poussière en parallaxe et vignettage. */
final class Backdrop {
    private static final int STARS = 70;
    private final Paint bg = new Paint();
    private final Paint vignette = new Paint();
    private final Paint horizon = new Paint();
    private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float[] sx = new float[STARS], sy = new float[STARS], sz = new float[STARS];
    private final float[] lines = new float[4 * 64];
    private float w, h, scroll, speed, hue;
    private final Rng rng = new Rng(7);

    void resize(float width, float height) {
        w = width; h = height;
        bg.setShader(new LinearGradient(0, 0, 0, h, new int[]{Palette.BG_TOP, 0xFF10061F, Palette.BG_BOTTOM},
                new float[]{0f, 0.55f, 1f}, Shader.TileMode.CLAMP));
        vignette.setShader(new RadialGradient(w * 0.5f, h * 0.5f, Math.max(w, h) * 0.75f,
                new int[]{0x00000000, 0x00000000, 0xB0000000}, new float[]{0f, 0.55f, 1f}, Shader.TileMode.CLAMP));
        horizon.setShader(new LinearGradient(0, 0, 0, h * 0.22f, new int[]{0x55FF2BD6, 0x00FF2BD6},
                null, Shader.TileMode.CLAMP));
        line.setStyle(Paint.Style.STROKE);
        line.setStrokeCap(Paint.Cap.ROUND);
        for (int i = 0; i < STARS; i++) {
            sx[i] = rng.nextFloat() * w;
            sy[i] = rng.nextFloat() * h;
            sz[i] = 0.2f + rng.nextFloat() * 0.8f;
        }
    }

    /** speed en pixels/seconde (défilement vers le bas). */
    void update(float dt, float pxPerSec) {
        speed = pxPerSec;
        scroll += dt * pxPerSec / Math.max(1f, h) * 2.2f;
        if (scroll > 1000f) scroll -= 1000f;
        hue += dt * 0.02f;
        for (int i = 0; i < STARS; i++) {
            sy[i] += pxPerSec * dt * (0.25f + sz[i] * 0.9f);
            if (sy[i] > h + 40f) {
                sy[i] = -rng.nextFloat() * 80f;
                sx[i] = rng.nextFloat() * w;
                sz[i] = 0.2f + rng.nextFloat() * 0.8f;
            }
        }
    }

    void draw(Canvas c, float intensity) {
        c.drawRect(0, 0, w, h, bg);
        c.drawRect(0, 0, w, h * 0.22f, horizon);

        // Grille en perspective : lignes horizontales qui se rapprochent vers l'horizon (haut).
        final float hy = -h * 0.05f;
        final float frac = scroll - (float) Math.floor(scroll);
        int n = 0;
        final int rows = 16;
        for (int k = 0; k < rows; k++) {
            float d = k + 1f - frac;
            float t = 1f / (1f + d * 0.42f);           // 1 près du bas, -> 0 vers l'horizon
            float y = hy + (h * 1.08f - hy) * t;
            if (y < hy || y > h + 4f) continue;
            float a = t * t;
            line.setColor(Palette.withAlpha(Palette.lerp(Palette.VIOLET, Palette.MAGENTA, t), (int) (190 * a * intensity)));
            line.setStrokeWidth(1f + 2.2f * t);
            c.drawLine(0, y, w, y, line);
        }
        // Lignes de fuite.
        line.setStrokeWidth(1.4f);
        line.setColor(Palette.withAlpha(Palette.VIOLET, (int) (95 * intensity)));
        final int cols = 9;
        for (int i = -cols; i <= cols; i++) {
            float bx = w * 0.5f + i * w * 0.28f;
            lines[n++] = w * 0.5f + i * w * 0.012f;
            lines[n++] = hy;
            lines[n++] = bx;
            lines[n++] = h * 1.08f;
        }
        c.drawLines(lines, 0, n, line);

        // Poussière / lignes de vitesse.
        float streak = Math.min(1f, speed / Math.max(1f, h * 0.9f));
        for (int i = 0; i < STARS; i++) {
            float z = sz[i];
            int col = (i % 3 == 0) ? Palette.MAGENTA : Palette.CYAN;
            line.setColor(Palette.withAlpha(col, (int) ((60 + 140 * z) * intensity)));
            line.setStrokeWidth(1.2f + z * 2.2f);
            float len = 2f + streak * z * h * 0.06f;
            c.drawLine(sx[i], sy[i], sx[i], sy[i] - len, line);
        }

        // Rails latéraux.
        line.setStrokeWidth(3f);
        line.setColor(Palette.withAlpha(Palette.CYAN, (int) (90 * intensity)));
        c.drawLine(2f, 0, 2f, h, line);
        c.drawLine(w - 2f, 0, w - 2f, h, line);
        float tick = h / 10f;
        float off = (frac * tick * 4f) % tick;
        line.setColor(Palette.withAlpha(Palette.CYAN, (int) (150 * intensity)));
        line.setStrokeWidth(5f);
        for (float y = off - tick; y < h; y += tick) {
            c.drawLine(3f, y, 3f, y + tick * 0.3f, line);
            c.drawLine(w - 3f, y, w - 3f, y + tick * 0.3f, line);
        }
    }

    void drawVignette(Canvas c) { c.drawRect(0, 0, w, h, vignette); }
}
