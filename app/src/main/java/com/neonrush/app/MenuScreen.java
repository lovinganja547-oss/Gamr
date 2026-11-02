package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Skins;

/** Écran d'accueil. */
final class MenuScreen extends Screen {
    private final Trail trail = new Trail();
    private float cam;
    private float sphereY;
    private final NumText best = new NumText("RECORD  ", "");

    MenuScreen(Game g) { super(g); }

    @Override
    void layout() {
        float u = g.u, w = g.width, h = g.height;
        float top = g.safeTop;
        float avail = h - top - g.safeBottom;
        sphereY = top + avail * 0.43f;
        float playY = top + avail * 0.61f;
        Button play = new Button("JOUER", Palette.CYAN, Button.PRIMARY, () -> g.go(g.play));
        play.set(w * 0.5f - 320f * u, playY - 78f * u, w * 0.5f + 320f * u, playY + 78f * u);
        buttons.add(play);
        float gy = playY + 120f * u;
        float bw = 300f * u, bh = 120f * u, gap = 30f * u;
        String[] labels = {"BOUTIQUE", "DÉFIS", "STATS", "RÉGLAGES"};
        int[] colors = {Palette.MAGENTA, Palette.GOLD, Palette.VIOLET, Palette.ORANGE};
        Screen[] targets = {g.shop, g.missions, g.stats, g.settings};
        for (int i = 0; i < 4; i++) {
            final Screen target = targets[i];
            Button b = new Button(labels[i], colors[i], Button.SECONDARY, () -> g.go(target));
            float x = w * 0.5f + (i % 2 == 0 ? -bw - gap * 0.5f : gap * 0.5f);
            float y = gy + (i / 2) * (bh + gap);
            b.set(x, y, x + bw, y + bh);
            buttons.add(b);
        }
    }

    @Override
    void enter() {
        g.audio.setMusic(AudioEngine.MUSIC_MENU);
        g.audio.setDuck(1f);
        g.fx.clear();
        trail.clear();
    }

    @Override
    void update(float dt) {
        super.update(dt);
        float u = g.u;
        cam += 900f * dt;
        float wx = 500f + 230f * (float) Math.sin(time * 1.25f) * (float) Math.cos(time * 0.37f);
        float wy = cam + (g.height - sphereY) / u;
        trail.push(wx, wy);
        g.fx.update(dt);
        g.backdrop.update(dt, 520f * u);
    }

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        g.backdrop.draw(c, 0.9f);

        Skins.Skin skin = Skins.get(g.profile.equipped);
        g.fx.draw(c, gx, u, h, cam, 0f, 0f);
        g.painter.trail(c, skin, trail, u, h, cam, time, 0f, 0f, true);
        float sx = trail.x(0) * u;
        g.painter.sphere(c, skin, sx, sphereY, 34f * u, time, 0f);

        // Logo
        float ly = g.safeTop + (h - g.safeTop - g.safeBottom) * 0.17f;
        float flick = ((int) (time * 7f) % 37 == 0) ? 0.55f : 1f;
        c.save();
        c.skew(-0.18f, 0f);
        c.translate(ly * 0.18f, 0f);
        gx.textMid(c, "NEON", w * 0.5f, ly - 70f * u, 190f * u, Palette.alpha(Palette.CYAN, flick), Gfx.CENTER, 30f * u, true);
        gx.textMid(c, "RUSH", w * 0.5f, ly + 110f * u, 190f * u, Palette.MAGENTA, Gfx.CENTER, 30f * u, true);
        c.restore();
        float lineY = ly + 230f * u;
        gx.neonLine(c, w * 0.18f, lineY, w * 0.82f, lineY, Palette.VIOLET, 3f * u, 0.8f);
        float hx = w * 0.18f + (w * 0.64f) * ((time * 0.45f) % 1f);
        gx.glow(c, hx, lineY, 60f * u, Palette.WHITE, 0.9f);

        if (g.profile.bestScore > 0) {
            best.set(g.profile.bestScore);
            gx.textNum(c, best, w * 0.5f, lineY + 60f * u, 36f * u, Palette.GOLD, Gfx.CENTER, 8f * u, true);
        } else {
            gx.textMid(c, "ÉVITE LES PIÈGES • COLLECTE LES CRISTAUX", w * 0.5f, lineY + 60f * u,
                    gx.fit("ÉVITE LES PIÈGES • COLLECTE LES CRISTAUX", 28f * u, w * 0.9f, false), Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        }

        g.drawBank(c, w - 40f * u, g.safeTop + 70f * u);
        g.backdrop.drawVignette(c);
        drawButtons(c);
        gx.textMid(c, "v1.0", 40f * u, h - g.safeBottom - 40f * u, 24f * u, Palette.withAlpha(Palette.TEXT_DIM, 140), Gfx.LEFT, 0f, false);
    }

    @Override
    boolean back() { return false; }
}
