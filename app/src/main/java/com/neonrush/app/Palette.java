package com.neonrush.app;

/** Palette néon commune. */
final class Palette {
    static final int BG_TOP = 0xFF07040F;
    static final int BG_BOTTOM = 0xFF1A0730;
    static final int CYAN = 0xFF00E5FF;
    static final int MAGENTA = 0xFFFF2BD6;
    static final int VIOLET = 0xFF9B4DFF;
    static final int ORANGE = 0xFFFF8A1F;
    static final int RED = 0xFFFF3355;
    static final int GOLD = 0xFFFFD36B;
    static final int GREEN = 0xFF39FF9A;
    static final int WHITE = 0xFFFFFFFF;
    static final int TEXT = 0xFFEAF6FF;
    static final int TEXT_DIM = 0xFF8C86B8;
    static final int PANEL = 0xE0140B26;
    static final int PANEL_LIGHT = 0xF01E1238;

    static int alpha(int color, float a) {
        int al = (int) (((color >>> 24) & 0xFF) * clamp01(a));
        return (al << 24) | (color & 0x00FFFFFF);
    }

    static int withAlpha(int color, int a) {
        return (Math.max(0, Math.min(255, a)) << 24) | (color & 0x00FFFFFF);
    }

    static int lerp(int c1, int c2, float t) {
        t = clamp01(t);
        int a = (int) (((c1 >>> 24) & 0xFF) + (((c2 >>> 24) & 0xFF) - ((c1 >>> 24) & 0xFF)) * t);
        int r = (int) (((c1 >> 16) & 0xFF) + (((c2 >> 16) & 0xFF) - ((c1 >> 16) & 0xFF)) * t);
        int g = (int) (((c1 >> 8) & 0xFF) + (((c2 >> 8) & 0xFF) - ((c1 >> 8) & 0xFF)) * t);
        int b = (int) ((c1 & 0xFF) + ((c2 & 0xFF) - (c1 & 0xFF)) * t);
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    /** Teinte quantifiée (h dans [0,1)), saturation forte, pour l'effet arc-en-ciel. */
    static int hue(float h) {
        h = h - (float) Math.floor(h);
        float r = Math.abs(h * 6f - 3f) - 1f;
        float g = 2f - Math.abs(h * 6f - 2f);
        float b = 2f - Math.abs(h * 6f - 4f);
        int ri = (int) (clamp01(r) * 255f), gi = (int) (clamp01(g) * 255f), bi = (int) (clamp01(b) * 255f);
        return 0xFF000000 | (ri << 16) | (gi << 8) | bi;
    }

    static float clamp01(float v) { return v < 0f ? 0f : (v > 1f ? 1f : v); }

    private Palette() {}
}
