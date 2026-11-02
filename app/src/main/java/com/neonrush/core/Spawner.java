package com.neonrush.core;

/**
 * Génération procédurale par motifs. Chaque motif garantit au moins un passage praticable ;
 * l'espacement entre motifs dépend de la vitesse pour laisser un temps de réaction suffisant.
 */
final class Spawner {
    static final int GATE = 0, ZIGZAG = 1, SLIDER = 2, SLIDER_PAIR = 3, LASER_SIDE = 4, LASER_DOUBLE = 5,
            LASER_CROSS = 6, SPINNER = 7, SPINNER_DUO = 8, MINES = 9, ZONE = 10, TUNNEL = 11, BREAK = 12;
    private static final int COUNT = 13;
    private static final float[] WEIGHT = {3.0f, 2.2f, 2.0f, 1.6f, 2.0f, 1.6f, 1.2f, 1.6f, 1.2f, 2.0f, 1.3f, 1.3f, 1.0f};
    private static final float[] MIN_D = {0f, 0.08f, 0.03f, 0.28f, 0.06f, 0.2f, 0.32f, 0.14f, 0.5f, 0f, 0.12f, 0.24f, 0f};
    private static final float W = GameWorld.W;
    private static final float TAU = 6.2831855f;

    private final GameWorld w;
    private final float[] weights = new float[COUNT];
    private float cursor;
    private int last = -1;
    private int sincePower;
    private int count;
    private final float[] mineX = new float[16], mineY = new float[16], mineR = new float[16], mineA = new float[16];

    Spawner(GameWorld w) { this.w = w; }

    void reset(float startY) {
        cursor = startY;
        last = -1;
        sincePower = 0;
        count = 0;
    }

    void ensure(float upTo) {
        while (cursor < upTo) spawnNext();
    }

    private static float lerp(float a, float b, float t) { return a + (b - a) * t; }

    private void spawnNext() {
        final Rng r = w.rng;
        float y = cursor;
        float d = GameWorld.difficultyAt(y);
        int p = count == 0 ? BREAK : pick(d);
        float end = build(p, y, d);
        last = p;
        count++;
        sincePower++;
        float sp = GameWorld.speedAt(end);
        float gap = sp * lerp(0.62f, 0.40f, d) + 90f;
        if (p != BREAK && r.chance(0.35f)) {
            float gx = r.range(140f, W - 140f);
            float mid = end + gap * 0.5f;
            for (int i = -1; i <= 1; i++) w.newPickup(Pickup.CRYSTAL, gx, mid + i * 70f);
        }
        cursor = end + gap;
    }

    private int pick(float d) {
        final Rng r = w.rng;
        float total = 0f;
        for (int i = 0; i < COUNT; i++) {
            float wt = (d >= MIN_D[i] && i != last) ? WEIGHT[i] : 0f;
            if (i == BREAK) wt = (last == BREAK) ? 0f : 1.0f + 1.0f * (1f - d);
            weights[i] = wt;
            total += wt;
        }
        float v = r.nextFloat() * total;
        for (int i = 0; i < COUNT; i++) {
            v -= weights[i];
            if (v < 0f && weights[i] > 0f) return i;
        }
        return GATE;
    }

    private float build(int p, float y, float d) {
        switch (p) {
            case GATE: return gate(y, d, w.rng.range(0f, 1f), true);
            case ZIGZAG: return zigzag(y, d);
            case SLIDER: return slider(y, d);
            case SLIDER_PAIR: return sliderPair(y, d);
            case LASER_SIDE: return laserSide(y, d);
            case LASER_DOUBLE: return laserDouble(y, d);
            case LASER_CROSS: return laserCross(y, d);
            case SPINNER: return spinner(y, d);
            case SPINNER_DUO: return spinnerDuo(y, d);
            case MINES: return mines(y, d);
            case ZONE: return zone(y, d);
            case TUNNEL: return tunnel(y, d);
            default: return crystalBreak(y, d);
        }
    }

    // ---- primitives -------------------------------------------------------------------------

    private void bar(float x, float y, float bw, float bh) {
        if (bw <= 1f) return;
        Obstacle o = w.newObstacle(Obstacle.BAR);
        o.x = x; o.y = y; o.w = bw; o.h = bh;
    }

    private void laser(float x, float y, float len, float d, float offset) {
        Obstacle o = w.newObstacle(Obstacle.LASER);
        o.x = x; o.y = y; o.w = len;
        o.offDur = lerp(1.1f, 0.75f, d);
        o.warnDur = 0.6f;
        o.onDur = lerp(0.9f, 1.4f, d);
        o.timeOffset = offset;
    }

    private void crystal(float x, float y) { w.newPickup(Pickup.CRYSTAL, x, y); }

    private boolean powerOrCrystal(float x, float y, float prob) {
        if (sincePower >= 5 && w.rng.chance(prob)) {
            w.newPickup(Pickup.SHIELD + w.rng.nextInt(3), x, y);
            sincePower = 0;
            return true;
        }
        crystal(x, y);
        return false;
    }

    // ---- motifs -----------------------------------------------------------------------------

    /** Barrière avec ouverture ; pos dans [0,1] place l'ouverture. */
    private float gate(float y, float d, float pos, boolean withCrystals) {
        final float thick = 46f;
        float g = lerp(400f, 240f, d) + w.rng.range(-20f, 20f);
        float minX = g * 0.5f + 30f, maxX = W - g * 0.5f - 30f;
        float gx = lerp(minX, maxX, pos);
        bar(0f, y, gx - g * 0.5f, thick);
        bar(gx + g * 0.5f, y, W - (gx + g * 0.5f), thick);
        if (withCrystals) {
            crystal(gx, y - 110f);
            powerOrCrystal(gx, y + thick * 0.5f, 0.15f);
            crystal(gx, y + 150f);
        }
        return y + thick;
    }

    private float zigzag(float y, float d) {
        final Rng r = w.rng;
        int n = d > 0.55f ? 3 : 2;
        float spacing = lerp(560f, 400f, d);
        boolean right = r.chance(0.5f);
        float end = y;
        float prevX = -1f;
        for (int i = 0; i < n; i++) {
            float pos = right ? r.range(0.78f, 1f) : r.range(0f, 0.22f);
            float g = lerp(400f, 240f, d);
            float gx = lerp(g * 0.5f + 30f, W - g * 0.5f - 30f, pos);
            float gy = y + i * spacing;
            end = gate(gy, d, pos, false);
            crystal(gx, gy + 23f);
            if (prevX >= 0f) {
                for (int k = 1; k <= 2; k++) {
                    float t = k / 3f;
                    crystal(lerp(prevX, gx, t), gy - spacing + 23f + spacing * t);
                }
            }
            prevX = gx;
            right = !right;
        }
        return end;
    }

    private float slider(float y, float d) {
        final Rng r = w.rng;
        float bw = lerp(380f, 500f, d), thick = 52f;
        Obstacle o = w.newObstacle(Obstacle.SLIDER);
        o.w = bw; o.h = thick; o.y = y;
        o.x = (W - bw) * 0.5f;
        o.amp = (W - bw) * 0.5f;
        o.freq = lerp(1.5f, 2.8f, d);
        o.phase = r.range(0f, TAU);
        crystal(500f, y - 160f);
        crystal(500f, y - 90f);
        powerOrCrystal(500f, y + 170f, 0.12f);
        return y + thick;
    }

    private float sliderPair(float y, float d) {
        final Rng r = w.rng;
        float bw = lerp(320f, 420f, d), thick = 50f;
        float spacing = lerp(330f, 270f, d);
        float ph = r.range(0f, TAU), f = lerp(1.6f, 2.6f, d);
        for (int i = 0; i < 2; i++) {
            Obstacle o = w.newObstacle(Obstacle.SLIDER);
            o.w = bw; o.h = thick; o.y = y + i * spacing;
            o.x = (W - bw) * 0.5f;
            o.amp = (W - bw) * 0.5f;
            o.freq = f;
            o.phase = ph + i * 3.1415927f;
        }
        float mid = y + thick + (spacing - thick) * 0.5f;
        crystal(r.range(200f, 800f), mid);
        return y + spacing + thick;
    }

    private float laserSide(float y, float d) {
        final Rng r = w.rng;
        boolean left = r.chance(0.5f);
        float cover = lerp(0.56f, 0.72f, d) * W;
        float x = left ? 0f : W - cover;
        laser(x, y, cover, d, r.range(0f, 3f));
        float free = left ? (cover + W) * 0.5f : (W - cover) * 0.5f;
        crystal(free, y - 90f);
        crystal(free, y);
        crystal(free, y + 90f);
        float risky = left ? cover * 0.45f : W - cover * 0.45f;
        crystal(risky, y);
        return y + Obstacle.LASER_HALF * 2f;
    }

    private float laserDouble(float y, float d) {
        final Rng r = w.rng;
        boolean left = r.chance(0.5f);
        float cover = lerp(0.58f, 0.70f, d) * W;
        float spacing = lerp(460f, 330f, d);
        float off = r.range(0f, 3f);
        boolean sync = r.chance(0.5f);
        for (int i = 0; i < 2; i++) {
            float x = left ? 0f : W - cover;
            float ly = y + i * spacing;
            laser(x, ly, cover, d, sync ? off : r.range(0f, 3f));
            float free = left ? (cover + W) * 0.5f : (W - cover) * 0.5f;
            crystal(free, ly);
            left = !left;
        }
        crystal(500f, y + spacing * 0.5f);
        return y + spacing + Obstacle.LASER_HALF * 2f;
    }

    private float laserCross(float y, float d) {
        final Rng r = w.rng;
        float len = lerp(360f, 410f, d);
        float off = r.range(0f, 3f);
        laser(0f, y, len, d, off);
        laser(W - len, y, len, d, off);
        crystal(500f, y - 90f);
        powerOrCrystal(500f, y, 0.2f);
        crystal(500f, y + 90f);
        crystal(len * 0.4f, y);
        crystal(W - len * 0.4f, y);
        return y + Obstacle.LASER_HALF * 2f;
    }

    private float spinner(float y, float d) {
        final Rng r = w.rng;
        float hl = lerp(240f, 320f, d);
        float cx = r.range(400f, 600f);
        float cy = y + hl + Obstacle.SPINNER_HALF;
        Obstacle o = w.newObstacle(Obstacle.SPINNER);
        o.x = cx; o.y = cy; o.r = hl;
        o.freq = lerp(1.4f, 2.6f, d) * r.sign();
        o.phase = r.range(0f, TAU);
        crystal(cx - hl * 0.7f, cy);
        crystal(cx + hl * 0.7f, cy);
        crystal(cx, cy - hl - 110f);
        crystal(cx, cy + hl + 110f);
        return cy + hl + Obstacle.SPINNER_HALF;
    }

    private float spinnerDuo(float y, float d) {
        final Rng r = w.rng;
        float hl = 200f;
        float cy = y + hl + Obstacle.SPINNER_HALF;
        float f = lerp(1.5f, 2.4f, d);
        float s = r.sign();
        float ph = r.range(0f, TAU);
        for (int i = 0; i < 2; i++) {
            Obstacle o = w.newObstacle(Obstacle.SPINNER);
            o.x = i == 0 ? 250f : 750f; o.y = cy; o.r = hl;
            o.freq = f * (i == 0 ? s : -s);
            o.phase = i == 0 ? ph : 3.1415927f - ph;
        }
        crystal(500f, cy - 70f);
        powerOrCrystal(500f, cy, 0.2f);
        crystal(500f, cy + 70f);
        return cy + hl + Obstacle.SPINNER_HALF;
    }

    private float mines(float y, float d) {
        final Rng r = w.rng;
        float hf = lerp(650f, 950f, d);
        int n = Math.round(lerp(4f, 9f, d)) + r.nextInt(2);
        float x0 = r.range(200f, 800f), x1 = r.range(200f, 800f);
        int placed = 0;
        final int maxTry = n * 60;
        final float[] mx = mineX, my = mineY, mr = mineR, ma = mineA;
        for (int t = 0; t < maxTry && placed < n; t++) {
            float cx = r.range(45f, W - 45f);
            float cy = y + r.range(0f, hf);
            float rad = r.range(28f, 38f);
            float amp = (d > 0.3f && r.chance(0.5f)) ? r.range(20f, 60f) : 0f;
            if (cx - amp < 30f || cx + amp > W - 30f) amp = 0f;
            float u = (cy - y) / hf;
            float s = u * u * (3f - 2f * u);
            float corridor = lerp(x0, x1, s);
            if (Math.abs(cx - corridor) - amp - rad * 0.85f < GameWorld.HIT + 30f) continue;
            boolean ok = true;
            for (int k = 0; k < placed; k++) {
                float dx = cx - mx[k], dy = cy - my[k];
                float minD = (rad + mr[k]) * 0.85f + amp + ma[k] + 70f;
                if (dx * dx + dy * dy < minD * minD) { ok = false; break; }
            }
            if (!ok) continue;
            mx[placed] = cx; my[placed] = cy; mr[placed] = rad; ma[placed] = amp;
            placed++;
            Obstacle o = w.newObstacle(Obstacle.MINE);
            o.x = cx; o.y = cy; o.r = rad;
            o.amp = amp; o.freq = 1.6f; o.phase = r.range(0f, TAU);
        }
        int cn = (int) (hf / 150f);
        for (int i = 0; i <= cn; i++) {
            float u = i / (float) cn;
            float s = u * u * (3f - 2f * u);
            crystal(lerp(x0, x1, s), y + hf * u);
        }
        return y + hf;
    }

    private float zone(float y, float d) {
        final Rng r = w.rng;
        float zw = lerp(480f, 680f, d), zh = lerp(320f, 460f, d);
        boolean left = r.chance(0.5f);
        Obstacle o = w.newObstacle(Obstacle.ZONE);
        o.x = left ? 0f : W - zw; o.y = y; o.w = zw; o.h = zh;
        o.offDur = lerp(1.2f, 0.9f, d);
        o.warnDur = 0.65f;
        o.onDur = lerp(1.1f, 1.5f, d);
        o.timeOffset = r.range(0f, 3f);
        float zc = o.x + zw * 0.5f;
        float free = left ? (zw + W) * 0.5f : (W - zw) * 0.5f;
        for (int i = 0; i < 3; i++) crystal(zc, y + zh * (0.2f + 0.3f * i));
        crystal(free, y + zh * 0.3f);
        crystal(free, y + zh * 0.7f);
        return y + zh;
    }

    private float tunnel(float y, float d) {
        final Rng r = w.rng;
        int segs = (int) lerp(4f, 7.99f, d);
        final float segH = 150f;
        float cw = lerp(380f, 290f, d);
        float lo = cw * 0.5f + 40f, hi = W - cw * 0.5f - 40f;
        float xc = r.range(lo, hi);
        for (int i = 0; i < segs; i++) {
            if (i > 0) {
                float shift = r.range(60f, 150f) * r.sign();
                if (xc + shift < lo || xc + shift > hi) shift = -shift;
                xc = Math.max(lo, Math.min(hi, xc + shift));
            }
            float sy = y + i * segH;
            bar(0f, sy, xc - cw * 0.5f, segH);
            bar(xc + cw * 0.5f, sy, W - (xc + cw * 0.5f), segH);
            crystal(xc, sy + segH * 0.5f);
        }
        return y + segs * segH;
    }

    private float crystalBreak(float y, float d) {
        final Rng r = w.rng;
        float len = lerp(700f, 500f, d);
        int n = 9;
        float a = r.range(150f, 330f), ph = r.range(0f, TAU);
        for (int i = 0; i < n; i++) {
            float u = i / (float) (n - 1);
            crystal(500f + a * (float) Math.sin(ph + u * 4.2f), y + len * u * 0.85f);
        }
        if (count > 0) powerOrCrystal(500f + a * (float) Math.sin(ph + 4.9f), y + len, 0.6f);
        return y + len;
    }
}
