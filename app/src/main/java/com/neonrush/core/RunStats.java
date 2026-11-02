package com.neonrush.core;

/** Résultats d'une partie (ou état en cours). */
public final class RunStats {
    public int score, crystals, meters, seconds, nearMisses, powerUps, bestCombo, lasers;
    public float playTime;

    public void from(GameWorld w) {
        score = w.score();
        crystals = w.crystals;
        meters = w.meters();
        playTime = w.runTime;
        seconds = (int) w.runTime;
        nearMisses = w.nearMisses;
        powerUps = w.powerUps;
        bestCombo = w.bestCombo;
        lasers = w.lasersPassed;
    }
}
