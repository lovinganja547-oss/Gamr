package com.neonrush.core;

import java.util.ArrayList;

/** Simulation complète d'une partie, indépendante d'Android (testable sur JVM). */
public final class GameWorld {
    public static final float W = 1000f;
    /** Rayon visuel du joueur. */
    public static final float PR = 26f;
    /** Rayon de collision (légèrement plus petit : sensation de justesse). */
    public static final float HIT = 21f;
    public static final float NEAR = 38f;
    public static final float PICK = 46f;
    public static final float LAT_K = 16f;
    public static final float LAT_MAX = 2900f;
    public static final float STEP = 1f / 120f;
    public static final float COMBO_WINDOW = 1.6f;
    public static final float MAGNET_TIME = 8f, DOUBLE_TIME = 10f, INVULN_TIME = 1.3f;
    public static final float UNITS_PER_METER = 10f;

    public interface Listener {
        void onCrystal(float x, float y, int combo, int points);
        void onPowerUp(int kind, float x, float y);
        void onNearMiss(float x, float y, int points);
        void onShieldBreak(float x, float y);
        void onDeath(float x, float y);
    }

    public final ArrayList<Obstacle> obstacles = new ArrayList<>(64);
    public final ArrayList<Pickup> pickups = new ArrayList<>(64);
    private final ArrayList<Obstacle> freeObs = new ArrayList<>(64);
    private final ArrayList<Pickup> freePick = new ArrayList<>(64);
    public final Rng rng = new Rng(1);
    private final Spawner spawner = new Spawner(this);

    public Listener listener;
    public float viewH = 2000f;

    public float time;
    public float px, py, pvx, targetX;
    public float speed;
    public boolean alive;

    public int crystals, bonusScore, combo, bestCombo, nearMisses, powerUps, lasersPassed, obstaclesPassed;
    public float comboTimer, nearCooldown;
    public boolean shield;
    public float magnetTime, doubleTime, invulnTime;
    public float runTime;

    public void reset(long seed, float viewHeight) {
        for (int i = obstacles.size() - 1; i >= 0; i--) freeObs.add(obstacles.get(i));
        for (int i = pickups.size() - 1; i >= 0; i--) freePick.add(pickups.get(i));
        obstacles.clear();
        pickups.clear();
        rng.setSeed(seed);
        viewH = viewHeight;
        time = 0f; runTime = 0f;
        px = targetX = W * 0.5f; py = 0f; pvx = 0f;
        speed = speedAt(0f);
        alive = true;
        crystals = bonusScore = combo = bestCombo = nearMisses = powerUps = lasersPassed = obstaclesPassed = 0;
        comboTimer = nearCooldown = 0f;
        shield = false;
        magnetTime = doubleTime = invulnTime = 0f;
        spawner.reset(viewH * 0.85f);
        spawner.ensure(py + viewH * 1.3f + 600f);
    }

    public static float speedAt(float y) {
        return 560f + 860f * (1f - (float) Math.exp(-y / 70000f));
    }

    public static float difficultyAt(float y) {
        float d = y / 130000f;
        return d > 1f ? 1f : (d < 0f ? 0f : d);
    }

    public int score() { return (int) (py / UNITS_PER_METER) + bonusScore; }

    public int meters() { return (int) (py / UNITS_PER_METER); }

    public float difficulty() { return difficultyAt(py); }

    public int comboMultiplier() { return Math.min(1 + combo / 3, 5); }

    /** Modèle de déplacement latéral partagé (jeu et tests). */
    public static float stepLateral(float x, float target, float h) {
        float nx = x + (target - x) * (1f - (float) Math.exp(-LAT_K * h));
        float maxD = LAT_MAX * h;
        if (nx - x > maxD) nx = x + maxD; else if (x - nx > maxD) nx = x - maxD;
        if (nx < PR) nx = PR; else if (nx > W - PR) nx = W - PR;
        return nx;
    }

    public void update(float dt) {
        if (dt <= 0f) return;
        if (!alive) { time += dt; return; }
        int n = (int) Math.ceil(dt / STEP);
        float h = dt / n;
        for (int i = 0; i < n && alive; i++) step(h);
        spawner.ensure(py + viewH * 1.3f + 600f);
        cull();
    }

    private void step(float h) {
        time += h;
        runTime += h;
        speed = speedAt(py);
        py += speed * h;
        float nx = stepLateral(px, targetX, h);
        pvx = (nx - px) / h;
        px = nx;

        if (comboTimer > 0f) { comboTimer -= h; if (comboTimer <= 0f) combo = 0; }
        if (nearCooldown > 0f) nearCooldown -= h;
        if (magnetTime > 0f) magnetTime -= h;
        if (doubleTime > 0f) doubleTime -= h;
        if (invulnTime > 0f) invulnTime -= h;

        collideObstacles();
        if (alive) collectPickups(h);
    }

    private void collideObstacles() {
        final float reach = PR + NEAR + 40f;
        for (int i = 0, n = obstacles.size(); i < n; i++) {
            Obstacle o = obstacles.get(i);
            if (o.passed) continue;
            if (o.bottom() > py + reach) continue;
            if (o.top() < py - PR) {
                o.passed = true;
                obstaclesPassed++;
                if (o.type == Obstacle.LASER) lasersPassed++;
                if (o.minDist >= HIT && o.minDist < HIT + NEAR && nearCooldown <= 0f) {
                    nearMisses++;
                    nearCooldown = 0.5f;
                    int pts = 25 * (doubleTime > 0f ? 2 : 1);
                    bonusScore += pts;
                    if (listener != null) listener.onNearMiss(px, py, pts);
                }
                continue;
            }
            float d = o.distance(px, py, time);
            if (d < o.minDist) o.minDist = d;
            if (d < HIT && invulnTime <= 0f) {
                if (shield) {
                    shield = false;
                    invulnTime = INVULN_TIME;
                    o.minDist = Float.MAX_VALUE;
                    if (listener != null) listener.onShieldBreak(px, py);
                } else {
                    alive = false;
                    if (listener != null) listener.onDeath(px, py);
                    return;
                }
            }
        }
    }

    private void collectPickups(float h) {
        final boolean magnet = magnetTime > 0f;
        for (int i = pickups.size() - 1; i >= 0; i--) {
            Pickup p = pickups.get(i);
            float dx = px - p.x, dy = py - p.y;
            float d2 = dx * dx + dy * dy;
            if (p.kind == Pickup.CRYSTAL && magnet && (p.attracted || d2 < 400f * 400f) && p.y > py - 120f) {
                p.attracted = true;
                float d = (float) Math.sqrt(d2);
                if (d > 1f) {
                    float sp = (1800f + speed) * h;
                    float k = Math.min(1f, sp / d);
                    p.x += dx * k;
                    p.y += dy * k;
                    dx = px - p.x; dy = py - p.y; d2 = dx * dx + dy * dy;
                }
            }
            if (d2 < PICK * PICK) {
                collect(p);
                pickups.remove(i);
                freePick.add(p);
            }
        }
    }

    private void collect(Pickup p) {
        if (p.kind == Pickup.CRYSTAL) {
            int gain = doubleTime > 0f ? 2 : 1;
            crystals += gain;
            combo++;
            if (combo > bestCombo) bestCombo = combo;
            comboTimer = COMBO_WINDOW;
            int pts = 10 * comboMultiplier() * gain;
            bonusScore += pts;
            if (listener != null) listener.onCrystal(p.x, p.y, combo, pts);
        } else {
            powerUps++;
            if (p.kind == Pickup.SHIELD) shield = true;
            else if (p.kind == Pickup.MAGNET) magnetTime = MAGNET_TIME;
            else if (p.kind == Pickup.DOUBLE) doubleTime = DOUBLE_TIME;
            bonusScore += 50;
            if (listener != null) listener.onPowerUp(p.kind, p.x, p.y);
        }
    }

    private void cull() {
        float limit = py - viewH * 0.35f - 300f;
        for (int i = obstacles.size() - 1; i >= 0; i--) {
            Obstacle o = obstacles.get(i);
            if (o.top() < limit) {
                int last = obstacles.size() - 1;
                obstacles.set(i, obstacles.get(last));
                obstacles.remove(last);
                freeObs.add(o);
            }
        }
        for (int i = pickups.size() - 1; i >= 0; i--) {
            Pickup p = pickups.get(i);
            if (p.y < limit) {
                int last = pickups.size() - 1;
                pickups.set(i, pickups.get(last));
                pickups.remove(last);
                freePick.add(p);
            }
        }
    }

    Obstacle newObstacle(int type) {
        Obstacle o = freeObs.isEmpty() ? new Obstacle() : freeObs.remove(freeObs.size() - 1);
        o.reset();
        o.type = type;
        o.seed = rng.nextInt(1 << 20);
        obstacles.add(o);
        return o;
    }

    Pickup newPickup(int kind, float x, float y) {
        Pickup p = freePick.isEmpty() ? new Pickup() : freePick.remove(freePick.size() - 1);
        p.reset();
        p.kind = kind;
        p.x = Math.max(PR + 10f, Math.min(W - PR - 10f, x));
        p.y = y;
        p.phase = rng.nextFloat() * 6.2831855f;
        pickups.add(p);
        return p;
    }
}
