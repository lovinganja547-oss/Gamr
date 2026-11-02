package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Profile;

/** Réglages : audio, vibration, contrôles, pause, réinitialisation. */
final class SettingsScreen extends Screen {
    private static final int MUSIC = 0, SFX = 1, VIB = 2, SENS = 3, AUTOPAUSE = 4, COUNTDOWN = 5, ROWS = 6;
    private static final String[] LABELS = {"MUSIQUE", "EFFETS SONORES", "VIBRATION", "SENSIBILITÉ", "PAUSE AUTO", "DÉCOMPTE"};
    private static final String[] HINTS = {
            "Bande-son électro du jeu",
            "Cristaux, collisions, menus",
            "Retour haptique",
            "Vitesse de la sphère sous le doigt",
            "Pause quand tu quittes l'application",
            "3 • 2 • 1 avant de reprendre"};
    private static final String[] VIB_TXT = {"NON", "FAIBLE", "FORTE"};
    private static final String[] SENS_TXT = {"FAIBLE", "NORMALE", "ÉLEVÉE"};
    private final Button[] rows = new Button[ROWS];
    private Button reset;
    private float resetArm;

    SettingsScreen(Game g) { super(g); }

    @Override
    void layout() {
        addBackButton();
        float u = g.u, w = g.width, h = g.height;
        float y = g.safeTop + 210f * u;
        float avail = h - g.safeBottom - 330f * u - y;
        float rowH = Math.min(175f * u, avail / ROWS);
        for (int i = 0; i < ROWS; i++) {
            final int idx = i;
            Button b = new Button(null, Palette.CYAN, Button.GHOST, () -> toggle(idx));
            b.set(40f * u, y + i * rowH + 8f * u, w - 40f * u, y + (i + 1) * rowH - 8f * u);
            rows[i] = b;
            buttons.add(b);
        }
        reset = new Button("RÉINITIALISER LA PROGRESSION", Palette.RED, Button.SECONDARY, this::onReset);
        float rb = h - g.safeBottom - 150f * u;
        reset.set(60f * u, rb - 110f * u, w - 60f * u, rb);
        buttons.add(reset);
    }

    @Override
    void enter() {
        resetArm = 0f;
        if (reset != null) reset.label = "RÉINITIALISER LA PROGRESSION";
    }

    private void toggle(int i) {
        Profile p = g.profile;
        switch (i) {
            case MUSIC: p.music = !p.music; g.audio.setMusicEnabled(p.music); break;
            case SFX: p.sfx = !p.sfx; g.audio.setSfxEnabled(p.sfx); break;
            case VIB: p.vibration = (p.vibration + 1) % 3; g.haptics.level = p.vibration; g.haptics.pulse(40, 0.8f); break;
            case SENS: p.sensitivity = (p.sensitivity + 1) % 3; break;
            case AUTOPAUSE: p.autoPause = !p.autoPause; break;
            case COUNTDOWN: p.countdown = !p.countdown; break;
            default: break;
        }
        p.save();
    }

    private void onReset() {
        if (resetArm <= 0f) {
            resetArm = 3f;
            reset.label = "TOUCHE ENCORE POUR CONFIRMER";
            return;
        }
        g.profile.resetProgress();
        g.audio.setMusicEnabled(g.profile.music);
        g.audio.setSfxEnabled(g.profile.sfx);
        resetArm = 0f;
        reset.label = "PROGRESSION RÉINITIALISÉE";
    }

    @Override
    void update(float dt) {
        super.update(dt);
        if (resetArm > 0f) {
            resetArm -= dt;
            if (resetArm <= 0f) reset.label = "RÉINITIALISER LA PROGRESSION";
        }
        g.backdrop.update(dt, 120f * g.u);
    }

    private String value(int i) {
        Profile p = g.profile;
        switch (i) {
            case MUSIC: return p.music ? "OUI" : "NON";
            case SFX: return p.sfx ? "OUI" : "NON";
            case VIB: return VIB_TXT[p.vibration];
            case SENS: return SENS_TXT[p.sensitivity];
            case AUTOPAUSE: return p.autoPause ? "OUI" : "NON";
            default: return p.countdown ? "OUI" : "NON";
        }
    }

    private boolean isOn(int i) {
        Profile p = g.profile;
        switch (i) {
            case MUSIC: return p.music;
            case SFX: return p.sfx;
            case VIB: return p.vibration > 0;
            case SENS: return true;
            case AUTOPAUSE: return p.autoPause;
            default: return p.countdown;
        }
    }

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        g.backdrop.draw(c, 0.6f);
        g.backdrop.drawVignette(c);
        for (int i = 0; i < ROWS; i++) {
            Button b = rows[i];
            float s = 1f - 0.02f * b.press;
            float cx = b.r.centerX(), cy = b.r.centerY();
            float hw = b.r.width() * 0.5f * s, hh = b.r.height() * 0.5f * s;
            gx.rect.set(cx - hw, cy - hh, cx + hw, cy + hh);
            gx.panel(c, gx.rect, 28f * u, b.press > 0.05f ? 0xF0241444 : Palette.PANEL_LIGHT, 0, 0f);
            float ts = Math.min(36f * u, hh * 0.5f);
            gx.textMid(c, LABELS[i], b.r.left + 40f * u, cy - hh * 0.22f, ts, Palette.TEXT, Gfx.LEFT, 0f, true);
            gx.textMid(c, HINTS[i], b.r.left + 40f * u, cy + hh * 0.38f, gx.fit(HINTS[i], ts * 0.66f, b.r.width() * 0.56f, false), Palette.TEXT_DIM, Gfx.LEFT, 0f, false);
            boolean on = isOn(i);
            int col = on ? Palette.CYAN : Palette.TEXT_DIM;
            float pw = 210f * u, ph = Math.min(76f * u, hh * 1.1f);
            float pr = b.r.right - 30f * u;
            gx.rect.set(pr - pw, cy - ph * 0.5f, pr, cy + ph * 0.5f);
            gx.fill.setColor(on ? 0x5000E5FF : 0x30FFFFFF);
            c.drawRoundRect(gx.rect, ph * 0.5f, ph * 0.5f, gx.fill);
            gx.neonRect(c, gx.rect, ph * 0.5f, col, 1.8f * u, on ? 1f : 0.4f);
            String v = value(i);
            gx.textMid(c, v, pr - pw * 0.5f, cy, gx.fit(v, 30f * u, pw * 0.85f, true), on ? Palette.WHITE : Palette.TEXT_DIM, Gfx.CENTER, 0f, true);
        }
        String credit = "Neon Rush 1.0 • Musique et sons générés par le jeu • Police Orbitron (SIL OFL)";
        gx.textMid(c, credit, w * 0.5f, h - g.safeBottom - 70f * u, gx.fit(credit, 24f * u, w * 0.9f, false), Palette.withAlpha(Palette.TEXT_DIM, 170), Gfx.CENTER, 0f, false);
        drawHeader(c, "RÉGLAGES");
        drawButtons(c);
    }

    @Override
    boolean back() {
        g.go(g.menu);
        return true;
    }
}
