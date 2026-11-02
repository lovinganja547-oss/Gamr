package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Mission;
import com.neonrush.core.Profile;

/** Défis en cours et récompenses. */
final class MissionsScreen extends Screen {
    private final String[] desc = new String[Profile.SLOTS], prog = new String[Profile.SLOTS], reward = new String[Profile.SLOTS];
    private final float[] ratio = new float[Profile.SLOTS];
    private String doneText = "";
    private static final int[] COLORS = {Palette.CYAN, Palette.MAGENTA, Palette.ORANGE};
    private static final String[] TITLES = {"DÉFI 1", "DÉFI 2", "DÉFI 3"};

    MissionsScreen(Game g) { super(g); }

    @Override
    void layout() {
        addBackButton();
        float u = g.u, w = g.width, h = g.height;
        Button play = new Button("JOUER", Palette.CYAN, Button.PRIMARY, () -> g.go(g.play));
        float b = h - g.safeBottom - 70f * u;
        play.set(w * 0.5f - 300f * u, b - 140f * u, w * 0.5f + 300f * u, b);
        buttons.add(play);
    }

    @Override
    void enter() {
        Profile p = g.profile;
        for (int i = 0; i < Profile.SLOTS; i++) {
            Mission m = p.missions[i];
            desc[i] = m.description();
            int shown = Math.min(m.progress, m.target);
            prog[i] = shown + " / " + m.target;
            reward[i] = "+" + m.reward;
            ratio[i] = m.target > 0 ? Math.min(1f, m.progress / (float) m.target) : 0f;
        }
        doneText = "DÉFIS ACCOMPLIS : " + p.missionsDone;
    }

    @Override
    void update(float dt) {
        super.update(dt);
        g.backdrop.update(dt, 120f * g.u);
    }

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width;
        g.backdrop.draw(c, 0.6f);
        g.backdrop.drawVignette(c);
        float y = g.safeTop + 220f * u;
        gx.textMid(c, "Termine un défi pour gagner des cristaux.", w * 0.5f, y, gx.fit("Termine un défi pour gagner des cristaux.", 28f * u, w * 0.88f, false), Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textMid(c, "Les gains sont versés à la fin de la partie.", w * 0.5f, y + 44f * u, gx.fit("Les gains sont versés à la fin de la partie.", 28f * u, w * 0.88f, false), Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        y += 110f * u;
        for (int i = 0; i < Profile.SLOTS; i++) {
            float ch = 250f * u;
            int col = COLORS[i % COLORS.length];
            gx.rect.set(40f * u, y, w - 40f * u, y + ch);
            gx.panel(c, gx.rect, 34f * u, Palette.PANEL_LIGHT, col, 1.8f * u);
            gx.textMid(c, TITLES[i % TITLES.length], 80f * u, y + 52f * u, 26f * u, col, Gfx.LEFT, 0f, true);
            gx.textMid(c, reward[i], w - 110f * u, y + 52f * u, 34f * u, Palette.GOLD, Gfx.RIGHT, 0f, true);
            gx.crystalIcon(c, w - 82f * u, y + 52f * u, 14f * u);
            gx.textMid(c, desc[i], 80f * u, y + 115f * u, gx.fit(desc[i], 36f * u, w - 160f * u, true), Palette.TEXT, Gfx.LEFT, 0f, true);
            float bl = 80f * u, br = w - 260f * u, by = y + 190f * u;
            gx.rect.set(bl, by - 14f * u, br, by + 14f * u);
            gx.panel(c, gx.rect, 14f * u, 0xFF0C0618, 0, 0f);
            if (ratio[i] > 0f) {
                gx.rect.set(bl, by - 14f * u, bl + (br - bl) * ratio[i], by + 14f * u);
                gx.fill.setColor(col);
                c.drawRoundRect(gx.rect, 14f * u, 14f * u, gx.fill);
                gx.glow(c, bl + (br - bl) * ratio[i], by, 40f * u, col, 0.8f);
            }
            gx.textMid(c, prog[i], w - 80f * u, by, gx.fit(prog[i], 28f * u, 160f * u, true), Palette.TEXT, Gfx.RIGHT, 0f, true);
            y += ch + 30f * u;
        }
        gx.textMid(c, doneText, w * 0.5f, y + 30f * u, 30f * u, Palette.GOLD, Gfx.CENTER, 0f, true);
        drawHeader(c, "DÉFIS");
        drawButtons(c);
    }

    @Override
    boolean back() {
        g.go(g.menu);
        return true;
    }
}
