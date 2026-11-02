package com.neonrush.core;

/** Pilote automatique à anticipation, utilisé pour vérifier que les motifs générés sont franchissables. */
public final class Bot {
    private static final float HORIZON = 1.1f, H = 1f / 40f, MARGIN = 4f;
    private float plan = 500f;
    private int tick;

    public void drive(GameWorld w) {
        if ((tick++ % 3) != 0) { w.targetX = plan; return; }
        float best = -1e9f, bestX = plan;
        for (float cand = 20f; cand <= 980f; cand += 30f) {
            float s = evaluate(w, cand);
            s -= Math.abs(cand - plan) * 0.02f;
            if (s > best) { best = s; bestX = cand; }
        }
        plan = bestX;
        w.targetX = plan;
    }

    private float evaluate(GameWorld w, float target) {
        float x = w.px, y = w.py, t = w.time;
        float crystals = 0f;
        for (float tt = 0f; tt < HORIZON; tt += H) {
            // sous-pas identiques au jeu
            for (int k = 0; k < 3; k++) {
                float h = H / 3f;
                x = GameWorld.stepLateral(x, target, h);
                y += GameWorld.speedAt(y) * h;
                t += h;
                for (int i = 0, n = w.obstacles.size(); i < n; i++) {
                    Obstacle o = w.obstacles.get(i);
                    if (o.top() < y - 40f || o.bottom() > y + 40f) continue;
                    if (o.distance(x, y, t) < GameWorld.HIT + MARGIN) return tt * 1000f + crystals;
                }
            }
            for (int i = 0, n = w.pickups.size(); i < n; i++) {
                Pickup p = w.pickups.get(i);
                float dx = p.x - x, dy = p.y - y;
                if (dx * dx + dy * dy < GameWorld.PICK * GameWorld.PICK) crystals += 3f;
            }
        }
        return HORIZON * 1000f + 2000f + crystals;
    }
}
