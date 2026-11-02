package com.neonrush.core;

/**
 * Obstacle du monde. Toutes les positions dynamiques sont des fonctions pures du temps de jeu,
 * ce qui rend la simulation déterministe et la détection de collision fiable.
 */
public final class Obstacle {
    public static final int BAR = 0, SLIDER = 1, LASER = 2, SPINNER = 3, MINE = 4, ZONE = 5;
    public static final int OFF = 0, WARN = 1, ON = 2;

    public static final float LASER_HALF = 9f;
    public static final float SPINNER_HALF = 11f;
    public static final float SPINNER_HUB = 22f;

    public int type;
    /** BAR/SLIDER/ZONE : rectangle (x = gauche, y = bas). LASER : de x à x+w à la hauteur y. SPINNER/MINE : centre. */
    public float x, y, w, h;
    /** SLIDER/MINE : oscillation horizontale. SPINNER : freq = vitesse angulaire, phase = angle initial. */
    public float amp, freq, phase;
    /** MINE : rayon. SPINNER : demi-longueur. */
    public float r;
    /** LASER/ZONE : cycle off -> avertissement -> actif. */
    public float offDur, warnDur, onDur, timeOffset;

    public boolean passed;
    public float minDist;
    public int seed;

    void reset() {
        type = BAR; x = y = w = h = amp = freq = phase = r = 0f;
        offDur = warnDur = onDur = timeOffset = 0f;
        passed = false; minDist = Float.MAX_VALUE; seed = 0;
    }

    public float period() { return offDur + warnDur + onDur; }

    public float offsetX(float t) {
        return amp == 0f ? 0f : amp * (float) Math.sin(freq * t + phase);
    }

    public float angle(float t) { return phase + freq * t; }

    private float cyclePos(float t) {
        float p = period();
        float v = (t + timeOffset) % p;
        return v < 0 ? v + p : v;
    }

    public int state(float t) {
        if (type != LASER && type != ZONE) return ON;
        float c = cyclePos(t);
        if (c < offDur) return OFF;
        if (c < offDur + warnDur) return WARN;
        return ON;
    }

    /** Progression [0,1] dans l'état courant (utile pour les animations). */
    public float stateProgress(float t) {
        if (type != LASER && type != ZONE) return 0f;
        float c = cyclePos(t);
        if (c < offDur) return c / offDur;
        if (c < offDur + warnDur) return (c - offDur) / warnDur;
        return (c - offDur - warnDur) / onDur;
    }

    public float top() {
        switch (type) {
            case LASER: return y + LASER_HALF;
            case SPINNER: return y + r + SPINNER_HALF;
            case MINE: return y + r;
            default: return y + h;
        }
    }

    public float bottom() {
        switch (type) {
            case LASER: return y - LASER_HALF;
            case SPINNER: return y - r - SPINNER_HALF;
            case MINE: return y - r;
            default: return y;
        }
    }

    /**
     * Distance entre le centre (px,py) et la surface solide de l'obstacle au temps t.
     * Retourne Float.MAX_VALUE si l'obstacle est inoffensif à cet instant.
     */
    public float distance(float px, float py, float t) {
        switch (type) {
            case BAR:
                return rectDist(px, py, x, y, x + w, y + h);
            case SLIDER: {
                float ox = x + offsetX(t);
                return rectDist(px, py, ox, y, ox + w, y + h);
            }
            case LASER:
                if (state(t) != ON) return Float.MAX_VALUE;
                return segDist(px, py, x, y, x + w, y) - LASER_HALF;
            case SPINNER: {
                float a = angle(t);
                float dx = (float) Math.cos(a) * r, dy = (float) Math.sin(a) * r;
                float d1 = segDist(px, py, x - dx, y - dy, x + dx, y + dy) - SPINNER_HALF;
                float d2 = hypot(px - x, py - y) - SPINNER_HUB;
                return Math.min(d1, d2);
            }
            case MINE:
                return hypot(px - (x + offsetX(t)), py - y) - r * 0.85f;
            case ZONE:
                if (state(t) != ON) return Float.MAX_VALUE;
                // Zone tolérante : il faut réellement entrer dedans.
                return rectDist(px, py, x, y, x + w, y + h) + 14f;
            default:
                return Float.MAX_VALUE;
        }
    }

    public static float hypot(float dx, float dy) { return (float) Math.sqrt(dx * dx + dy * dy); }

    public static float rectDist(float px, float py, float l, float b, float rr, float tt) {
        float dx = Math.max(Math.max(l - px, 0f), px - rr);
        float dy = Math.max(Math.max(b - py, 0f), py - tt);
        return (float) Math.sqrt(dx * dx + dy * dy);
    }

    public static float segDist(float px, float py, float ax, float ay, float bx, float by) {
        float vx = bx - ax, vy = by - ay;
        float len2 = vx * vx + vy * vy;
        float u = len2 > 0f ? ((px - ax) * vx + (py - ay) * vy) / len2 : 0f;
        if (u < 0f) u = 0f; else if (u > 1f) u = 1f;
        float cx = ax + vx * u - px, cy = ay + vy * u - py;
        return (float) Math.sqrt(cx * cx + cy * cy);
    }
}
