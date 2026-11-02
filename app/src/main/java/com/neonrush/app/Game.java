package com.neonrush.app;

import android.content.Context;
import android.graphics.Canvas;

import com.neonrush.core.Profile;

/** Chef d'orchestre : ressources partagées, écrans et transitions. Utilisé uniquement par le thread de jeu. */
final class Game {
    final Context ctx;
    final Profile profile;
    final AudioEngine audio;
    final Haptics haptics;
    final Gfx gfx;
    final Backdrop backdrop = new Backdrop();
    final Particles fx = new Particles();
    final SkinPainter painter;
    final WorldRenderer worldRenderer;

    int width, height;
    float u = 1f, safeTop, safeBottom;

    final MenuScreen menu;
    final PlayScreen play;
    final ShopScreen shop;
    final StatsScreen stats;
    final MissionsScreen missions;
    final SettingsScreen settings;
    private final Screen[] all;

    Screen current;
    private Screen next;
    private float fade = 1f;
    private final NumText bankText = new NumText();
    float time;

    Game(Context ctx) {
        this.ctx = ctx;
        profile = new Profile(new PrefsStore(ctx));
        audio = new AudioEngine(ctx);
        haptics = new Haptics(ctx);
        gfx = new Gfx(ctx.getAssets());
        painter = new SkinPainter(gfx, fx);
        worldRenderer = new WorldRenderer(gfx);
        audio.setMusicEnabled(profile.music);
        audio.setSfxEnabled(profile.sfx);
        haptics.level = profile.vibration;
        menu = new MenuScreen(this);
        play = new PlayScreen(this);
        shop = new ShopScreen(this);
        stats = new StatsScreen(this);
        missions = new MissionsScreen(this);
        settings = new SettingsScreen(this);
        all = new Screen[]{menu, play, shop, stats, missions, settings};
        current = menu;
    }

    private boolean started;

    void resize(int w, int h, float insetTop, float insetBottom) {
        if (w <= 0 || h <= 0) return;
        if (w == width && h == height && insetTop == safeTop && insetBottom == safeBottom && started) return;
        width = w; height = h;
        u = w / 1000f;
        safeTop = Math.max(insetTop, 0f);
        safeBottom = Math.max(insetBottom, 0f);
        backdrop.resize(w, h);
        for (Screen s : all) {
            s.cancelPress();
            s.buttons.clear();
            s.layout();
        }
        if (!started) {
            started = true;
            audio.start();
            current.enter();
        }
    }

    boolean ready() { return started; }

    void go(Screen s) {
        if (next != null || s == current) return;
        next = s;
        current.cancelPress();
    }

    void update(float dt) {
        time += dt;
        if (next != null) {
            fade += dt / 0.16f;
            if (fade >= 1f) {
                fade = 1f;
                current.exit();
                current = next;
                next = null;
                current.enter();
            }
        } else if (fade > 0f) {
            fade = Math.max(0f, fade - dt / 0.24f);
        }
        current.update(dt);
    }

    void draw(Canvas c) {
        current.draw(c);
        if (fade > 0.001f) {
            gfx.fill.setColor(Palette.withAlpha(0xFF05020B, (int) (255 * fade)));
            c.drawRect(0, 0, width, height, gfx.fill);
        }
    }

    void touch(int action, float x, float y) {
        if (next != null || fade > 0.6f) {
            if (action == Screen.UP || action == Screen.CANCEL) current.touch(Screen.CANCEL, x, y);
            return;
        }
        current.touch(action, x, y);
    }

    boolean back() {
        if (next != null) return true;
        return current.back();
    }

    void onHostPause() {
        if (started) current.onHostPauseHook();
        profile.save();
    }

    void onHostResume() {
        if (started) current.onHostResumeHook();
    }

    /** Pastille de cristaux alignée à droite sur rightX. */
    void drawBank(Canvas c, float rightX, float cy) {
        bankText.set(profile.bank);
        float s = 40f * u;
        float tw = gfx.measureNum(bankText, s, true);
        float pad = 22f * u, icon = 18f * u;
        float left = rightX - tw - pad * 2f - icon * 2.4f;
        gfx.rect.set(left, cy - 36f * u, rightX, cy + 36f * u);
        gfx.panel(c, gfx.rect, 36f * u, 0xD0120A22, Palette.CYAN, 1.6f * u);
        gfx.crystalIcon(c, left + pad + icon, cy, icon);
        gfx.textNum(c, bankText, rightX - pad, cy, s, Palette.TEXT, Gfx.RIGHT, 0f, true);
    }

    /** Conversion écran -> monde pour les particules d'interface (cam = 0, base = height). */
    float wx(float sx) { return sx / u; }

    float wy(float sy) { return (height - sy) / u; }
}
