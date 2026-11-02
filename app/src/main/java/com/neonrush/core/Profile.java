package com.neonrush.core;

import java.util.ArrayList;

/** Progression, statistiques et réglages du joueur, sauvegardés de façon persistante. */
public final class Profile {
    public static final int SLOTS = 3;

    // Monnaie & skins
    public long bank;
    public long ownedSkins = 1L;
    public int equipped;

    // Statistiques
    public int bestScore, bestMeters, bestSeconds, bestCombo;
    public int games;
    public long totalMeters, totalCrystals, totalPlayMs, totalNearMisses, totalPowerUps;
    public int missionsDone;

    // Défis
    public final Mission[] missions = new Mission[SLOTS];
    public int nextSerial;

    // Réglages
    public boolean music = true, sfx = true, autoPause = true, countdown = true, tutorialDone;
    public int vibration = 1;
    public int sensitivity = 1;

    private final SaveStore store;

    public Profile(SaveStore store) {
        this.store = store;
        load();
    }

    public static final class Report {
        public boolean newBest;
        public int previousBest;
        public int runCrystals;
        public int missionCrystals;
        public final ArrayList<Mission> completed = new ArrayList<>(3);
    }

    public boolean owns(int skin) { return skin >= 0 && skin < 64 && (ownedSkins & (1L << skin)) != 0; }

    /** Achat d'un skin. Retourne false si fonds insuffisants ou déjà possédé. */
    public boolean buy(int skin) {
        if (skin < 0 || skin >= Skins.count() || owns(skin)) return false;
        int price = Skins.get(skin).price;
        if (bank < price) return false;
        bank -= price;
        ownedSkins |= 1L << skin;
        equipped = skin;
        save();
        return true;
    }

    public boolean equip(int skin) {
        if (!owns(skin)) return false;
        equipped = skin;
        save();
        return true;
    }

    public int ownedCount() { return Long.bitCount(ownedSkins & ((1L << Skins.count()) - 1)); }

    /** Intègre une partie terminée : stats, record, cristaux et défis. */
    public Report applyRun(RunStats s) {
        Report r = new Report();
        r.previousBest = bestScore;
        r.newBest = s.score > bestScore;
        games++;
        if (s.score > bestScore) bestScore = s.score;
        if (s.meters > bestMeters) bestMeters = s.meters;
        if (s.seconds > bestSeconds) bestSeconds = s.seconds;
        if (s.bestCombo > bestCombo) bestCombo = s.bestCombo;
        totalMeters += s.meters;
        totalCrystals += s.crystals;
        totalPlayMs += (long) (s.playTime * 1000f);
        totalNearMisses += s.nearMisses;
        totalPowerUps += s.powerUps;
        bank += s.crystals;
        r.runCrystals = s.crystals;
        for (int i = 0; i < SLOTS; i++) {
            Mission m = missions[i];
            m.progress = m.progressWith(s, true);
            if (m.isDone()) {
                r.completed.add(m);
                r.missionCrystals += m.reward;
                bank += m.reward;
                missionsDone++;
                missions[i] = Mission.create(nextSerial++);
            }
        }
        save();
        return r;
    }

    public void resetProgress() {
        bank = 0; ownedSkins = 1L; equipped = 0;
        bestScore = bestMeters = bestSeconds = bestCombo = games = missionsDone = 0;
        totalMeters = totalCrystals = totalPlayMs = totalNearMisses = totalPowerUps = 0;
        for (int i = 0; i < SLOTS; i++) missions[i] = Mission.create(i);
        nextSerial = SLOTS;
        tutorialDone = false;
        save();
    }

    private long g(String k, long d) { return store.getLong(k, d); }

    private void load() {
        bank = g("bank", 0);
        ownedSkins = g("owned", 1L) | 1L;
        equipped = (int) g("equipped", 0);
        if (!owns(equipped) || equipped >= Skins.count()) equipped = 0;
        bestScore = (int) g("bestScore", 0);
        bestMeters = (int) g("bestMeters", 0);
        bestSeconds = (int) g("bestSeconds", 0);
        bestCombo = (int) g("bestCombo", 0);
        games = (int) g("games", 0);
        totalMeters = g("totalMeters", 0);
        totalCrystals = g("totalCrystals", 0);
        totalPlayMs = g("totalPlayMs", 0);
        totalNearMisses = g("totalNear", 0);
        totalPowerUps = g("totalPowerUps", 0);
        missionsDone = (int) g("missionsDone", 0);
        nextSerial = (int) g("nextSerial", SLOTS);
        for (int i = 0; i < SLOTS; i++) {
            int serial = (int) g("m" + i + "serial", i);
            Mission m = Mission.create(serial);
            m.progress = (int) g("m" + i + "progress", 0);
            missions[i] = m;
        }
        music = g("music", 1) != 0;
        sfx = g("sfx", 1) != 0;
        autoPause = g("autoPause", 1) != 0;
        countdown = g("countdown", 1) != 0;
        tutorialDone = g("tutorial", 0) != 0;
        vibration = clamp((int) g("vibration", 1), 0, 2);
        sensitivity = clamp((int) g("sensitivity", 1), 0, 2);
    }

    private static int clamp(int v, int a, int b) { return v < a ? a : (v > b ? b : v); }

    public void save() {
        SaveStore s = store;
        s.putLong("bank", bank);
        s.putLong("owned", ownedSkins);
        s.putLong("equipped", equipped);
        s.putLong("bestScore", bestScore);
        s.putLong("bestMeters", bestMeters);
        s.putLong("bestSeconds", bestSeconds);
        s.putLong("bestCombo", bestCombo);
        s.putLong("games", games);
        s.putLong("totalMeters", totalMeters);
        s.putLong("totalCrystals", totalCrystals);
        s.putLong("totalPlayMs", totalPlayMs);
        s.putLong("totalNear", totalNearMisses);
        s.putLong("totalPowerUps", totalPowerUps);
        s.putLong("missionsDone", missionsDone);
        s.putLong("nextSerial", nextSerial);
        for (int i = 0; i < SLOTS; i++) {
            s.putLong("m" + i + "serial", missions[i].serial);
            s.putLong("m" + i + "progress", missions[i].progress);
        }
        s.putLong("music", music ? 1 : 0);
        s.putLong("sfx", sfx ? 1 : 0);
        s.putLong("autoPause", autoPause ? 1 : 0);
        s.putLong("countdown", countdown ? 1 : 0);
        s.putLong("tutorial", tutorialDone ? 1 : 0);
        s.putLong("vibration", vibration);
        s.putLong("sensitivity", sensitivity);
        s.commit();
    }
}
