package com.neonrush.core;

/** Défi : objectif chiffré récompensé en cristaux. */
public final class Mission {
    public static final int SCORE_RUN = 0, CRYSTALS_RUN = 1, GAMES = 2, SURVIVE_RUN = 3, DIST_TOTAL = 4,
            NEARMISS_RUN = 5, POWERUPS_TOTAL = 6, COMBO_RUN = 7, LASERS_TOTAL = 8;
    private static final int[] ORDER = {SCORE_RUN, CRYSTALS_RUN, GAMES, SURVIVE_RUN, DIST_TOTAL,
            NEARMISS_RUN, POWERUPS_TOTAL, COMBO_RUN, LASERS_TOTAL};
    private static final int[][] TARGETS = {
            {1000, 2500, 4500, 7000, 10000, 14000},
            {25, 45, 70, 100, 130, 170},
            {3, 5, 8, 10, 12, 15},
            {30, 50, 75, 100, 130, 160},
            {3000, 8000, 15000, 25000, 40000, 60000},
            {3, 6, 10, 14, 18, 24},
            {3, 6, 10, 15, 20, 30},
            {6, 10, 15, 20, 26, 32},
            {10, 25, 50, 80, 120, 170},
    };
    private static final int[] STEPS = {4000, 40, 5, 30, 25000, 6, 10, 6, 50};
    private static final int[] REWARDS = {60, 100, 150, 220, 300, 400};

    public int serial, type, target, progress, reward;

    public static Mission create(int serial) {
        Mission m = new Mission();
        m.serial = serial;
        m.type = ORDER[serial % ORDER.length];
        int tier = serial / ORDER.length;
        int[] t = TARGETS[m.type];
        m.target = tier < t.length ? t[tier] : t[t.length - 1] + STEPS[m.type] * (tier - t.length + 1);
        m.reward = tier < REWARDS.length ? REWARDS[tier] : REWARDS[REWARDS.length - 1] + 120 * (tier - REWARDS.length + 1);
        m.progress = 0;
        return m;
    }

    public boolean isCumulative() {
        return type == GAMES || type == DIST_TOTAL || type == POWERUPS_TOTAL || type == LASERS_TOTAL;
    }

    private int runValue(RunStats s, boolean finished) {
        switch (type) {
            case SCORE_RUN: return s.score;
            case CRYSTALS_RUN: return s.crystals;
            case GAMES: return finished ? 1 : 0;
            case SURVIVE_RUN: return s.seconds;
            case DIST_TOTAL: return s.meters;
            case NEARMISS_RUN: return s.nearMisses;
            case POWERUPS_TOTAL: return s.powerUps;
            case COMBO_RUN: return s.bestCombo;
            case LASERS_TOTAL: return s.lasers;
            default: return 0;
        }
    }

    /** Progression qu'aurait le défi en tenant compte de la partie (en cours ou terminée). */
    public int progressWith(RunStats s, boolean finished) {
        int v = runValue(s, finished);
        long p = isCumulative() ? (long) progress + v : Math.max(progress, v);
        return (int) Math.min(p, Integer.MAX_VALUE);
    }

    public boolean isDone() { return progress >= target; }

    public String description() {
        switch (type) {
            case SCORE_RUN: return "Atteins " + target + " points en une partie";
            case CRYSTALS_RUN: return "Collecte " + target + " cristaux en une partie";
            case GAMES: return "Joue " + target + " parties";
            case SURVIVE_RUN: return "Survis " + target + " secondes en une partie";
            case DIST_TOTAL: return "Parcours " + target + " m au total";
            case NEARMISS_RUN: return "Réussis " + target + " frôlements en une partie";
            case POWERUPS_TOTAL: return "Ramasse " + target + " bonus";
            case COMBO_RUN: return "Enchaîne un combo de " + target + " cristaux";
            case LASERS_TOTAL: return "Franchis " + target + " lasers";
            default: return "";
        }
    }
}
