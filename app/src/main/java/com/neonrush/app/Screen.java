package com.neonrush.app;

import android.graphics.Canvas;

import java.util.ArrayList;

/** Écran du jeu : gère ses boutons, son animation et ses entrées. */
abstract class Screen {
    static final int DOWN = 0, MOVE = 1, UP = 2, CANCEL = 3;
    final Game g;
    final ArrayList<Button> buttons = new ArrayList<>();
    private Button pressed;
    private float downX, downY;
    float time;

    Screen(Game g) { this.g = g; }

    /** Appelé quand la taille de l'écran change. */
    void layout() {}

    void enter() {}

    void exit() {}

    void update(float dt) {
        time += dt;
        for (int i = 0, n = buttons.size(); i < n; i++) buttons.get(i).update(dt);
    }

    abstract void draw(Canvas c);

    void drawButtons(Canvas c) {
        for (int i = 0, n = buttons.size(); i < n; i++) buttons.get(i).draw(c, g.gfx, g.u, time);
    }

    /** Retourne true si l'événement a été consommé par un bouton. */
    boolean touchButtons(int action, float x, float y) {
        switch (action) {
            case DOWN:
                downX = x; downY = y;
                for (int i = buttons.size() - 1; i >= 0; i--) {
                    Button b = buttons.get(i);
                    if (b.visible && b.hit(x, y, 6f * g.u)) {
                        pressed = b;
                        b.pressed = true;
                        return true;
                    }
                }
                return false;
            case MOVE:
                if (pressed != null) {
                    if (!pressed.hit(x, y, 30f * g.u)) { pressed.pressed = false; pressed = null; }
                    return true;
                }
                return false;
            case UP: {
                Button b = pressed;
                if (b == null) return false;
                b.pressed = false;
                pressed = null;
                if (b.hit(x, y, 30f * g.u)) {
                    if (b.enabled) {
                        g.audio.play(b.sound);
                        g.haptics.tick();
                        if (b.action != null) b.action.run();
                    } else {
                        g.audio.play(AudioEngine.DENY, 0.6f, 1f);
                    }
                }
                return true;
            }
            default:
                if (pressed != null) { pressed.pressed = false; pressed = null; }
                return false;
        }
    }

    void cancelPress() {
        if (pressed != null) { pressed.pressed = false; pressed = null; }
    }

    void touch(int action, float x, float y) { touchButtons(action, x, y); }

    void onHostPauseHook() {}

    void onHostResumeHook() {}

    /** Retour système ; false = laisser l'application se fermer. */
    boolean back() { return false; }

    // Utilitaires de mise en page
    float u() { return g.u; }

    /** Bouton retour en haut à gauche + titre. */
    Button addBackButton() {
        float u = g.u;
        Button b = new Button(null, Palette.CYAN, Button.SECONDARY, () -> g.go(g.menu));
        b.icon = Button.ICON_BACK;
        b.sound = AudioEngine.BACK;
        b.set(40f * u, g.safeTop + 40f * u, 150f * u, g.safeTop + 150f * u);
        buttons.add(b);
        return b;
    }

    void drawHeader(Canvas c, String title) {
        float u = g.u;
        float cy = g.safeTop + 95f * u;
        g.gfx.textMid(c, title, g.width * 0.5f, cy, g.gfx.fit(title, 64f * u, 600f * u, true), Palette.TEXT, Gfx.CENTER, 16f * u, true);
        g.drawBank(c, g.width - 40f * u, cy);
    }
}
