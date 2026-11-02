package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Profile;
import com.neonrush.core.Skins;

/** Statistiques et records. */
final class StatsScreen extends Screen {
    private final String[] labels = {
            "MEILLEURE DISTANCE", "PLUS LONGUE SURVIE", "MEILLEUR COMBO", "PARTIES JOUÉES", "DISTANCE TOTALE",
            "CRISTAUX COLLECTÉS", "TEMPS DE JEU TOTAL", "FRÔLEMENTS", "BONUS RAMASSÉS", "DÉFIS ACCOMPLIS", "SKINS DÉBLOQUÉS"};
    private final String[] values = new String[labels.length];
    private String best = "0";

    StatsScreen(Game g) { super(g); }

    @Override
    void layout() { addBackButton(); }

    private static String group(long v) {
        String s = Long.toString(Math.abs(v));
        StringBuilder b = new StringBuilder(s.length() + 6);
        int first = s.length() % 3;
        if (first > 0) b.append(s, 0, first);
        for (int i = first; i < s.length(); i += 3) {
            if (b.length() > 0) b.append(' ');
            b.append(s, i, i + 3);
        }
        return (v < 0 ? "-" : "") + b;
    }

    static String duration(long ms) {
        long s = ms / 1000;
        long h = s / 3600, m = (s % 3600) / 60, sec = s % 60;
        if (h > 0) return h + " h " + (m < 10 ? "0" : "") + m + " min";
        if (m > 0) return m + " min " + (sec < 10 ? "0" : "") + sec + " s";
        return sec + " s";
    }

    @Override
    void enter() {
        Profile p = g.profile;
        best = group(p.bestScore);
        values[0] = group(p.bestMeters) + " m";
        values[1] = duration(p.bestSeconds * 1000L);
        values[2] = "x " + p.bestCombo;
        values[3] = group(p.games);
        values[4] = group(p.totalMeters) + " m";
        values[5] = group(p.totalCrystals);
        values[6] = duration(p.totalPlayMs);
        values[7] = group(p.totalNearMisses);
        values[8] = group(p.totalPowerUps);
        values[9] = group(p.missionsDone);
        values[10] = p.ownedCount() + " / " + Skins.count();
    }

    @Override
    void update(float dt) {
        super.update(dt);
        g.backdrop.update(dt, 120f * g.u);
    }

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        g.backdrop.draw(c, 0.6f);
        g.backdrop.drawVignette(c);

        float top = g.safeTop + 200f * u;
        gx.rect.set(40f * u, top, w - 40f * u, top + 220f * u);
        gx.panel(c, gx.rect, 36f * u, Palette.PANEL_LIGHT, Palette.GOLD, 2f * u);
        gx.textMid(c, "MEILLEUR SCORE", w * 0.5f, top + 60f * u, 30f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textMid(c, best, w * 0.5f, top + 145f * u, 96f * u, Palette.GOLD, Gfx.CENTER, 18f * u, true);

        float y0 = top + 250f * u;
        float avail = h - g.safeBottom - 40f * u - y0;
        float rowH = Math.min(100f * u, avail / labels.length);
        for (int i = 0; i < labels.length; i++) {
            float y = y0 + i * rowH;
            gx.rect.set(40f * u, y + 6f * u, w - 40f * u, y + rowH - 6f * u);
            gx.panel(c, gx.rect, 22f * u, i % 2 == 0 ? 0xC0140B26 : 0xC01A0F33, 0, 0f);
            float cy = y + rowH * 0.5f;
            float ts = Math.min(28f * u, rowH * 0.32f);
            gx.textMid(c, labels[i], 80f * u, cy, ts, Palette.TEXT_DIM, Gfx.LEFT, 0f, false);
            gx.textMid(c, values[i], w - 80f * u, cy, ts * 1.25f, i == 5 ? Palette.CYAN : Palette.TEXT, Gfx.RIGHT, 0f, true);
        }
        drawHeader(c, "STATISTIQUES");
        drawButtons(c);
    }

    @Override
    boolean back() {
        g.go(g.menu);
        return true;
    }
}
