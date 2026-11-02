package com.neonrush.app;

import android.graphics.Canvas;
import android.graphics.RectF;

/** Bouton tactile néon. */
final class Button {
    static final int PRIMARY = 0, SECONDARY = 1, GHOST = 2;
    final RectF r = new RectF();
    String label;
    String sub;
    int color;
    int style;
    boolean enabled = true, visible = true;
    Runnable action;
    float press;
    boolean pressed;
    int sound = AudioEngine.CLICK;
    /** Icône optionnelle dessinée à gauche du texte. */
    int icon = -1;
    static final int ICON_NONE = -1, ICON_BACK = 0, ICON_CRYSTAL = 1, ICON_PLAY = 2, ICON_PAUSE = 3;

    Button(String label, int color, int style, Runnable action) {
        this.label = label; this.color = color; this.style = style; this.action = action;
    }

    Button set(float l, float t, float rr, float b) { r.set(l, t, rr, b); return this; }

    boolean hit(float x, float y, float slop) {
        return visible && x >= r.left - slop && x <= r.right + slop && y >= r.top - slop && y <= r.bottom + slop;
    }

    void update(float dt) {
        float target = pressed ? 1f : 0f;
        press += (target - press) * Math.min(1f, dt * 18f);
    }

    void draw(Canvas c, Gfx g, float u, float time) {
        if (!visible) return;
        float s = 1f - 0.04f * press;
        float cx = r.centerX(), cy = r.centerY();
        float hw = r.width() * 0.5f * s, hh = r.height() * 0.5f * s;
        g.rect.set(cx - hw, cy - hh, cx + hw, cy + hh);
        int col = enabled ? color : Palette.TEXT_DIM;
        float rad = Math.min(hh, 28f * u);
        if (style == PRIMARY) {
            float breathe = enabled ? 0.85f + 0.15f * (float) Math.sin(time * 3f) : 0.5f;
            g.fill.setColor(Palette.withAlpha(Palette.lerp(col, 0xFF000000, 0.72f - 0.2f * press), 235));
            c.drawRoundRect(g.rect, rad, rad, g.fill);
            g.neonRect(c, g.rect, rad, col, 3.2f * u, breathe + press * 0.3f);
        } else if (style == SECONDARY) {
            g.fill.setColor(Palette.withAlpha(Palette.lerp(0xFF140B26, col, 0.08f + 0.2f * press), 230));
            c.drawRoundRect(g.rect, rad, rad, g.fill);
            g.neonRect(c, g.rect, rad, col, 2.2f * u, enabled ? 0.75f + press * 0.4f : 0.4f);
        } else {
            if (press > 0.02f) {
                g.fill.setColor(Palette.alpha(col, 0.15f * press));
                c.drawRoundRect(g.rect, rad, rad, g.fill);
            }
        }
        float labelSize = (style == PRIMARY ? 46f : 34f) * u * s;
        if (r.height() < 110f * u) labelSize = Math.min(labelSize, r.height() * 0.36f);
        float textX = cx;
        if (icon == ICON_BACK) {
            g.backArrow(c, cx, cy, hh * 0.8f, enabled ? Palette.TEXT : Palette.TEXT_DIM);
            return;
        }
        if (icon == ICON_PAUSE) {
            float bw = hh * 0.22f, bh = hh * 0.55f;
            g.fill.setColor(Palette.TEXT);
            c.drawRoundRect(cx - bw * 2f, cy - bh, cx - bw * 0.6f, cy + bh, bw * 0.4f, bw * 0.4f, g.fill);
            c.drawRoundRect(cx + bw * 0.6f, cy - bh, cx + bw * 2f, cy + bh, bw * 0.4f, bw * 0.4f, g.fill);
            return;
        }
        if (label == null) return;
        int textCol = enabled ? Palette.TEXT : Palette.TEXT_DIM;
        float maxW = r.width() * 0.86f;
        if (icon == ICON_CRYSTAL) {
            float iconS = labelSize * 0.55f;
            float tw = g.measure(label, labelSize, true);
            float total = tw + iconS * 2.6f;
            if (total > maxW) { labelSize *= maxW / total; iconS = labelSize * 0.55f; tw = g.measure(label, labelSize, true); total = tw + iconS * 2.6f; }
            float start = cx - total * 0.5f;
            g.crystalIcon(c, start + iconS, sub == null ? cy : cy - hh * 0.22f, iconS);
            textX = start + iconS * 2.6f + tw * 0.5f;
        } else {
            labelSize = g.fit(label, labelSize, maxW, true);
        }
        float ly = sub == null ? cy : cy - hh * 0.22f;
        g.textMid(c, label, textX, ly, labelSize, textCol, Gfx.CENTER, enabled && style == PRIMARY ? 10f * u : 0f, true);
        if (sub != null) {
            float ss = g.fit(sub, labelSize * 0.55f, maxW, false);
            g.textMid(c, sub, cx, cy + hh * 0.42f, ss, Palette.alpha(textCol, 0.75f), Gfx.CENTER, 0f, false);
        }
    }
}
