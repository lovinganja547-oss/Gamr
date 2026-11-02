package com.neonrush.app;

import static org.junit.Assert.*;

import android.app.Application;
import android.graphics.Bitmap;
import android.graphics.Canvas;

import com.neonrush.core.Bot;
import com.neonrush.core.Profile;
import com.neonrush.core.Skins;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;

import java.io.File;
import java.io.FileOutputStream;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
public class ScreensRenderTest {
    private static final int W = 1080, H = 2340;
    private final File out = new File(System.getProperty("shots.dir", "build/shots"));

    private Bitmap frame(Game g) {
        Bitmap b = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        g.draw(c);
        return b;
    }

    private void save(Bitmap b, String name) throws Exception {
        out.mkdirs();
        Bitmap small = Bitmap.createScaledBitmap(b, W / 2, H / 2, true);
        try (FileOutputStream os = new FileOutputStream(new File(out, name + ".png"))) {
            small.compress(Bitmap.CompressFormat.PNG, 100, os);
        }
    }

    private void run(Game g, float seconds) {
        int n = (int) (seconds * 60);
        for (int i = 0; i < n; i++) g.update(1f / 60f);
    }

    /** Vérifie qu'une image n'est pas vide (plusieurs couleurs distinctes). */
    private void assertRich(Bitmap b) {
        java.util.HashSet<Integer> colors = new java.util.HashSet<>();
        for (int y = 0; y < H; y += 37) for (int x = 0; x < W; x += 29) colors.add(b.getPixel(x, y));
        assertTrue("image trop uniforme : " + colors.size(), colors.size() > 40);
    }

    private void tap(Game g, Button b) {
        g.touch(Screen.DOWN, b.r.centerX(), b.r.centerY());
        g.update(1f / 60f);
        g.touch(Screen.UP, b.r.centerX(), b.r.centerY());
        g.update(1f / 60f);
    }

    private Button find(Screen s, String label) {
        for (Button b : s.buttons) if (label.equals(b.label) && b.visible) return b;
        fail("bouton introuvable : " + label);
        return null;
    }

    @Test
    public void fullFlowAndScreenshots() throws Exception {
        Application app = RuntimeEnvironment.getApplication();
        Game g = new Game(app);
        g.resize(W, H, 80, 0);
        g.profile.bank = 1200;
        run(g, 1.0f);
        Bitmap b = frame(g);
        assertRich(b);
        save(b, "01_menu");

        // Menu -> Jouer
        tap(g, find(g.menu, "JOUER"));
        run(g, 0.6f);
        assertSame(g.play, g.current);
        save(frame(g), "02_ready");

        // Démarrage + pilotage par le bot via des glissements simulés
        PlayScreen p = g.play;
        g.touch(Screen.DOWN, W * 0.5f, H * 0.8f);
        Bot bot = new Bot();
        float fingerX = W * 0.5f;
        float anchorWorld = p.world.targetX;
        int frames = 0;
        boolean shotMid = false;
        while (p.world.alive && frames < 60 * 45) {
            bot.drive(p.world);
            // Convertit la cible du bot en mouvement de doigt (sensibilité normale = 1.35)
            float want = p.world.targetX;
            fingerX = W * 0.5f + (want - anchorWorld) * g.u / 1.35f;
            g.touch(Screen.MOVE, fingerX, H * 0.8f);
            g.update(1f / 60f);
            frames++;
            if (!shotMid && frames == 60 * 12) { save(frame(g), "03_play"); shotMid = true; }
        }
        assertTrue("la partie aurait dû durer : " + frames, frames > 60 * 10);
        save(frame(g), "04_play_late");

        // Pause / reprise
        if (p.world.alive) {
            tap(g, p.buttons.get(0));
            run(g, 0.4f);
            save(frame(g), "05_pause");
            tap(g, find(p, "REPRENDRE"));
            run(g, 2.0f);
        }
        g.touch(Screen.UP, fingerX, H * 0.8f);
        // Laisse le joueur mourir
        int guard = 0;
        while (p.world.alive && guard++ < 60 * 300) { p.world.targetX = 500f; g.update(1f / 60f); }
        assertFalse(p.world.alive);
        run(g, 1.0f);
        save(frame(g), "06_dying");
        run(g, 1.5f);
        b = frame(g);
        assertRich(b);
        save(b, "07_gameover");
        assertEquals(1, g.profile.games);
        assertTrue(g.profile.bestScore > 0);

        // Rejouer puis menu
        tap(g, find(p, "MENU"));
        run(g, 0.6f);
        assertSame(g.menu, g.current);

        // Boutique : achat d'un skin
        tap(g, find(g.menu, "BOUTIQUE"));
        run(g, 0.6f);
        assertSame(g.shop, g.current);
        long bank = g.profile.bank;
        // Sélectionne le skin 1 (PULSAR, 100)
        ShopScreen shop = g.shop;
        float cardX = 40f * g.u + (shop.buttons.size() > 0 ? 0 : 0);
        g.touch(Screen.DOWN, W * 0.5f, g.safeTop + 200f * g.u + 120f * g.u);
        g.touch(Screen.UP, W * 0.5f, g.safeTop + 200f * g.u + 120f * g.u);
        g.update(1f / 60f);
        Button act = null;
        for (Button bb : shop.buttons) if (bb.style == Button.PRIMARY) act = bb;
        assertNotNull(act);
        assertTrue(act.enabled);
        tap(g, act);
        assertTrue(g.profile.owns(1));
        assertEquals(1, g.profile.equipped);
        assertEquals(bank - Skins.get(1).price, g.profile.bank);
        run(g, 0.3f);
        save(frame(g), "08_shop");

        // Scroll boutique
        g.touch(Screen.DOWN, W * 0.5f, H * 0.5f);
        for (int i = 0; i < 20; i++) { g.touch(Screen.MOVE, W * 0.5f, H * 0.5f - i * 40); g.update(1f / 60f); }
        g.touch(Screen.UP, W * 0.5f, H * 0.5f - 800);
        run(g, 1f);
        save(frame(g), "09_shop_scrolled");

        assertTrue(g.back());
        run(g, 0.6f);
        tap(g, find(g.menu, "STATS"));
        run(g, 0.6f);
        save(frame(g), "10_stats");
        assertTrue(g.back());
        run(g, 0.6f);
        tap(g, find(g.menu, "DÉFIS"));
        run(g, 0.6f);
        save(frame(g), "11_missions");
        assertTrue(g.back());
        run(g, 0.6f);
        tap(g, find(g.menu, "RÉGLAGES"));
        run(g, 0.6f);
        assertSame(g.settings, g.current);
        boolean music = g.profile.music;
        Button row0 = g.settings.buttons.get(1);
        tap(g, row0);
        assertEquals(!music, g.profile.music);
        save(frame(g), "12_settings");
        tap(g, row0);
        assertEquals(music, g.profile.music);
        assertTrue(g.back());
        run(g, 0.6f);
        assertFalse("retour sur le menu = quitter", g.back());

        // Persistance : un nouveau profil relit les mêmes données
        Profile reloaded = new Profile(new PrefsStore(app));
        assertEquals(g.profile.bank, reloaded.bank);
        assertEquals(g.profile.bestScore, reloaded.bestScore);
        assertEquals(g.profile.games, reloaded.games);
        assertTrue(reloaded.owns(1));
        assertEquals(1, reloaded.equipped);
        g.audio.release();
    }

    @Test
    public void allSkinsRender() throws Exception {
        Application app = RuntimeEnvironment.getApplication();
        Game g = new Game(app);
        g.resize(W, H, 0, 0);
        Bitmap b = Bitmap.createBitmap(W, 900, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        c.drawColor(0xFF07040F);
        Trail t = new Trail();
        for (int i = 0; i < Skins.count(); i++) {
            float x = 140 + (i % 5) * 200, y = 150 + (i / 5) * 280;
            g.painter.sphere(c, Skins.get(i), x, y, 45, 1.3f + i, 0.2f);
            g.gfx.textMid(c, Skins.get(i).name, x, y + 110, 26, 0xFFFFFFFF, Gfx.CENTER, 0, true);
        }
        out.mkdirs();
        try (FileOutputStream os = new FileOutputStream(new File(out, "13_skins.png"))) {
            b.compress(Bitmap.CompressFormat.PNG, 100, os);
        }
        g.audio.release();
    }
}
