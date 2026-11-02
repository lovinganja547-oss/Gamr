package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.GameWorld;
import com.neonrush.core.Mission;
import com.neonrush.core.Pickup;
import com.neonrush.core.Profile;
import com.neonrush.core.RunStats;
import com.neonrush.core.Skins;

/** Écran de jeu : partie, pause, décompte, fin de partie. */
final class PlayScreen extends Screen implements GameWorld.Listener {
    private static final int READY = 0, PLAYING = 1, PAUSED = 2, COUNTDOWN = 3, DYING = 4, OVER = 5;
    private static final float[] SENS = {1.0f, 1.35f, 1.75f};
    private static final int POPS = 20;

    final GameWorld world = new GameWorld();
    private final Trail trail = new Trail();
    private final RunStats live = new RunStats();
    private Profile.Report report;
    private Skins.Skin skin = Skins.get(0);

    private int state = READY, pausedFrom = READY;
    private float stateTime;
    private float shake, flash;
    private int flashColor = Palette.WHITE;
    private float cam;
    private float missionCheck;
    private final boolean[] missionToasted = new boolean[Profile.SLOTS];
    private boolean recordToasted;

    // Contrôle
    private boolean finger;
    private float anchorFinger, anchorTarget;

    // HUD
    private final NumText scoreText = new NumText();
    private final NumText metersText = new NumText("", " m");
    private final NumText crystalText = new NumText();
    private final NumText comboText = new NumText("COMBO x", "");
    private final NumText overScore = new NumText();
    private final NumText overBest = new NumText("MEILLEUR  ", "");
    private final NumText overMeters = new NumText("", " m");
    private final NumText overCrystals = new NumText("+", "");
    private final NumText overTime = new NumText("", " s");
    private final NumText overTotal = new NumText("+", "");

    // Messages
    private String toastTitle, toastText;
    private int toastColor;
    private float toastTime;
    private final String[] popText = new String[POPS];
    private final float[] popX = new float[POPS], popY = new float[POPS], popLife = new float[POPS];
    private final int[] popColor = new int[POPS];
    private int popNext;
    private final String[] doneDesc = new String[Profile.SLOTS], doneReward = new String[Profile.SLOTS];
    private int doneCount;
    private int nextSkin = -1;
    private String nextSkinLabel = "", nextSkinProgress = "";

    // Boutons
    private Button pauseBtn, resumeBtn, restartBtn, menuBtn, musicBtn, sfxBtn, replayBtn, overMenuBtn;

    private final android.graphics.Paint hudShade = new android.graphics.Paint();

    PlayScreen(Game g) { super(g); }

    @Override
    void layout() {
        float u = g.u, w = g.width, h = g.height;
        hudShade.setShader(new android.graphics.LinearGradient(0, 0, 0, g.safeTop + 280f * u,
                new int[]{0xC005020B, 0x8005020B, 0x0005020B}, new float[]{0f, 0.6f, 1f}, android.graphics.Shader.TileMode.CLAMP));
        pauseBtn = new Button(null, Palette.CYAN, Button.SECONDARY, this::pause);
        pauseBtn.icon = Button.ICON_PAUSE;
        pauseBtn.set(36f * u, g.safeTop + 36f * u, 146f * u, g.safeTop + 146f * u);

        float cy = h * 0.5f;
        resumeBtn = new Button("REPRENDRE", Palette.CYAN, Button.PRIMARY, this::resume);
        resumeBtn.set(w * 0.5f - 300f * u, cy - 170f * u, w * 0.5f + 300f * u, cy - 30f * u);
        restartBtn = new Button("RECOMMENCER", Palette.MAGENTA, Button.SECONDARY, this::startRun);
        restartBtn.set(w * 0.5f - 300f * u, cy + 10f * u, w * 0.5f + 300f * u, cy + 125f * u);
        menuBtn = new Button("MENU", Palette.VIOLET, Button.SECONDARY, () -> g.go(g.menu));
        menuBtn.sound = AudioEngine.BACK;
        menuBtn.set(w * 0.5f - 300f * u, cy + 155f * u, w * 0.5f + 300f * u, cy + 270f * u);
        musicBtn = new Button("", Palette.CYAN, Button.SECONDARY, this::toggleMusic);
        musicBtn.set(w * 0.5f - 300f * u, cy + 320f * u, w * 0.5f - 10f * u, cy + 420f * u);
        sfxBtn = new Button("", Palette.CYAN, Button.SECONDARY, this::toggleSfx);
        sfxBtn.set(w * 0.5f + 10f * u, cy + 320f * u, w * 0.5f + 300f * u, cy + 420f * u);

        float bottom = h - g.safeBottom - 60f * u;
        overMenuBtn = new Button("MENU", Palette.VIOLET, Button.SECONDARY, () -> g.go(g.menu));
        overMenuBtn.sound = AudioEngine.BACK;
        overMenuBtn.set(w * 0.5f - 300f * u, bottom - 115f * u, w * 0.5f + 300f * u, bottom);
        replayBtn = new Button("REJOUER", Palette.CYAN, Button.PRIMARY, this::startRun);
        replayBtn.set(w * 0.5f - 300f * u, bottom - 290f * u, w * 0.5f + 300f * u, bottom - 145f * u);

        buttons.add(pauseBtn);
        buttons.add(resumeBtn);
        buttons.add(restartBtn);
        buttons.add(menuBtn);
        buttons.add(musicBtn);
        buttons.add(sfxBtn);
        buttons.add(replayBtn);
        buttons.add(overMenuBtn);
        refreshButtons();
    }

    private void refreshButtons() {
        if (pauseBtn == null) return;
        boolean paused = state == PAUSED, over = state == OVER;
        pauseBtn.visible = state == PLAYING || state == READY || state == COUNTDOWN;
        resumeBtn.visible = restartBtn.visible = menuBtn.visible = musicBtn.visible = sfxBtn.visible = paused;
        replayBtn.visible = overMenuBtn.visible = over;
        musicBtn.label = g.profile.music ? "MUSIQUE : OUI" : "MUSIQUE : NON";
        sfxBtn.label = g.profile.sfx ? "SONS : OUI" : "SONS : NON";
    }

    private void setState(int s) {
        state = s;
        stateTime = 0f;
        cancelPress();
        refreshButtons();
    }

    @Override
    void enter() { startRun(); }

    @Override
    void exit() {
        g.audio.setDuck(1f);
    }

    private void startRun() {
        float viewH = g.height / g.u;
        world.listener = this;
        world.reset(System.nanoTime() ^ 0x5DEECE66DL, viewH);
        trail.clear();
        g.fx.clear();
        skin = Skins.get(g.profile.equipped);
        report = null;
        shake = flash = 0f;
        finger = false;
        toastTime = 0f;
        missionCheck = 0f;
        recordToasted = g.profile.bestScore <= 0;
        for (int i = 0; i < POPS; i++) popLife[i] = 0f;
        for (int i = 0; i < Profile.SLOTS; i++) missionToasted[i] = false;
        cam = world.py - viewH * 0.22f;
        g.audio.setMusic(AudioEngine.MUSIC_GAME);
        g.audio.setDuck(1f);
        setState(READY);
    }

    // ---- actions -----------------------------------------------------------------------------

    private void pause() {
        if (state != PLAYING && state != COUNTDOWN && state != READY) return;
        pausedFrom = state == READY ? READY : PLAYING;
        finger = false;
        g.audio.setDuck(0.35f);
        setState(PAUSED);
    }

    private void resume() {
        if (state != PAUSED) return;
        g.audio.setDuck(1f);
        finger = false;
        if (pausedFrom == READY) setState(READY);
        else if (g.profile.countdown) setState(COUNTDOWN);
        else setState(PLAYING);
    }

    private void toggleMusic() {
        g.profile.music = !g.profile.music;
        g.audio.setMusicEnabled(g.profile.music);
        g.profile.save();
        refreshButtons();
    }

    private void toggleSfx() {
        g.profile.sfx = !g.profile.sfx;
        g.audio.setSfxEnabled(g.profile.sfx);
        g.profile.save();
        refreshButtons();
    }

    @Override
    void onHostPauseHook() {
        if (state == PLAYING || state == COUNTDOWN) {
            if (g.profile.autoPause) pause();
            else if (g.profile.countdown) setState(COUNTDOWN);
        }
        finger = false;
    }

    @Override
    boolean back() {
        switch (state) {
            case PLAYING: case READY: case COUNTDOWN: pause(); return true;
            case PAUSED: resume(); return true;
            case OVER: g.go(g.menu); return true;
            default: return true;
        }
    }

    // ---- entrées -----------------------------------------------------------------------------

    @Override
    void touch(int action, float x, float y) {
        if (touchButtons(action, x, y)) return;
        if (state != PLAYING && state != READY && state != COUNTDOWN) return;
        float u = g.u;
        switch (action) {
            case DOWN:
                finger = true;
                anchorFinger = x;
                anchorTarget = world.targetX;
                if (state == READY) {
                    setState(PLAYING);
                    g.audio.play(AudioEngine.GO, 0.7f, 1f);
                }
                break;
            case MOVE: {
                if (!finger) break;
                float sens = SENS[g.profile.sensitivity];
                float t = anchorTarget + (x - anchorFinger) / u * sens;
                float lo = GameWorld.PR, hi = GameWorld.W - GameWorld.PR;
                if (t < lo || t > hi) {
                    t = t < lo ? lo : hi;
                    anchorTarget = t;
                    anchorFinger = x;
                }
                world.targetX = t;
                if (!g.profile.tutorialDone && Math.abs(x - anchorFinger) > 80f * u) {
                    g.profile.tutorialDone = true;
                    g.profile.save();
                }
                break;
            }
            default:
                finger = false;
                break;
        }
    }

    // ---- événements du monde -----------------------------------------------------------------

    private void pop(String text, float x, float y, int color) {
        int i = popNext;
        popNext = (popNext + 1) % POPS;
        popText[i] = text; popX[i] = x; popY[i] = y; popLife[i] = 1f; popColor[i] = color;
    }

    private void toast(String title, String text, int color) {
        toastTitle = title; toastText = text; toastColor = color; toastTime = 2.6f;
    }

    @Override
    public void onCrystal(float x, float y, int combo, int points) {
        g.audio.play(AudioEngine.CRYSTAL, 0.55f, 1f + Math.min(combo, 14) * 0.04f);
        g.fx.burst(Particles.SPARK, x, y, 7, 150f, 420f, 0.35f, 4f, Palette.CYAN);
        g.fx.spawn(Particles.RING, x, y, 0f, 0f, 0.3f, 60f, Palette.CYAN, 0f);
        if (combo >= 3) pop("+" + points, x, y + 40f, combo >= 9 ? Palette.GOLD : Palette.CYAN);
    }

    @Override
    public void onPowerUp(int kind, float x, float y) {
        g.audio.play(AudioEngine.POWER, 0.8f, 1f);
        g.haptics.pulse(30, 0.6f);
        int col = WorldRenderer.powerColor(kind);
        g.fx.spawn(Particles.RING, x, y, 0f, 0f, 0.5f, 160f, col, 0f);
        g.fx.burst(Particles.SPARK, x, y, 14, 200f, 600f, 0.45f, 5f, col);
        String name = kind == Pickup.SHIELD ? "BOUCLIER" : (kind == Pickup.MAGNET ? "AIMANT" : "CRISTAUX x2");
        pop(name, x, y + 60f, col);
    }

    @Override
    public void onNearMiss(float x, float y, int points) {
        g.audio.play(AudioEngine.NEAR, 0.5f, 1f);
        g.haptics.pulse(10, 0.25f);
        pop("FRÔLÉ +" + points, x, y + 70f, Palette.MAGENTA);
    }

    @Override
    public void onShieldBreak(float x, float y) {
        g.audio.play(AudioEngine.SHIELD, 0.9f, 1f);
        g.haptics.pulse(45, 0.8f);
        shake = Math.max(shake, 14f);
        flash = 0.5f; flashColor = 0xFF4DA6FF;
        g.fx.burst(Particles.SHARD, x, y, 22, 200f, 700f, 0.6f, 9f, 0xFF8FD0FF);
        g.fx.spawn(Particles.RING, x, y, 0f, 0f, 0.45f, 200f, 0xFF4DA6FF, 0f);
    }

    @Override
    public void onDeath(float x, float y) {
        g.audio.play(AudioEngine.CRASH, 1f, 1f);
        g.haptics.pulse(220, 1f);
        shake = 30f;
        flash = 0.85f; flashColor = Palette.WHITE;
        int col = SkinPainter.glowColor(skin, time);
        g.fx.burst(Particles.SPARK, x, y, 46, 300f, 1300f, 0.8f, 7f, col);
        g.fx.burst(Particles.SHARD, x, y, 26, 150f, 700f, 1.1f, 12f, skin.accent);
        g.fx.burst(Particles.DOT, x, y, 24, 50f, 400f, 1.2f, 10f, Palette.WHITE);
        g.fx.spawn(Particles.RING, x, y, 0f, 0f, 0.7f, 380f, col, 0f);
        g.fx.spawn(Particles.RING, x, y, 0f, 0f, 1.0f, 600f, Palette.MAGENTA, 0f);
        finger = false;
        live.from(world);
        report = g.profile.applyRun(live);
        doneCount = Math.min(Profile.SLOTS, report.completed.size());
        for (int i = 0; i < doneCount; i++) {
            Mission m = report.completed.get(i);
            doneDesc[i] = m.description();
            doneReward[i] = "+" + m.reward;
        }
        nextSkin = -1;
        for (int i = 0; i < Skins.count(); i++) {
            if (!g.profile.owns(i) && (nextSkin < 0 || Skins.get(i).price < Skins.get(nextSkin).price)) nextSkin = i;
        }
        if (nextSkin >= 0) {
            Skins.Skin ns = Skins.get(nextSkin);
            boolean afford = g.profile.bank >= ns.price;
            nextSkinLabel = afford ? ns.name + " : DISPONIBLE !" : "PROCHAIN SKIN : " + ns.name;
            nextSkinProgress = Math.min(g.profile.bank, ns.price) + " / " + ns.price;
        }
        g.audio.setDuck(0.45f);
        setState(DYING);
    }

    // ---- simulation --------------------------------------------------------------------------

    @Override
    void update(float dt) {
        super.update(dt);
        stateTime += dt;
        float u = g.u;
        float viewH = g.height / u;
        float scale = 1f;
        switch (state) {
            case PLAYING:
                world.update(dt);
                if (state == PLAYING) {
                    trail.push(world.px, world.py);
                    missionCheck -= dt;
                    if (missionCheck <= 0f) { missionCheck = 0.25f; checkLiveGoals(); }
                }
                break;
            case COUNTDOWN: {
                int before = (int) ((stateTime - dt) / 0.6f), after = (int) (stateTime / 0.6f);
                if (stateTime - dt <= 0f || after != before) {
                    if (after < 3) g.audio.play(AudioEngine.BEEP, 0.7f, 1f);
                }
                if (stateTime >= 1.8f) {
                    g.audio.play(AudioEngine.GO, 0.7f, 1f);
                    setState(PLAYING);
                }
                break;
            }
            case DYING:
                scale = Math.min(1f, 0.2f + stateTime * 0.8f);
                world.update(dt * scale);
                if (stateTime > 1.25f) {
                    setState(OVER);
                    if (report != null && report.newBest && report.previousBest > 0) g.audio.play(AudioEngine.RECORD, 0.8f, 1f);
                    if (report != null && !report.completed.isEmpty()) g.audio.play(AudioEngine.MISSION, 0.8f, 1f);
                }
                break;
            case OVER:
                world.update(dt * 0.3f);
                break;
            default:
                break;
        }
        boolean frozen = state == PAUSED || state == COUNTDOWN || state == READY;
        if (!frozen) g.fx.update(dt * scale);
        float targetCam = world.py - viewH * 0.22f;
        cam = targetCam;
        float bgSpeed = frozen ? (state == READY ? 160f * u : 0f) : world.speed * u * 0.45f * scale;
        if (state == OVER) bgSpeed = 120f * u;
        g.backdrop.update(dt, bgSpeed);
        shake = Math.max(0f, shake - dt * 60f);
        flash = Math.max(0f, flash - dt * 2.2f);
        if (toastTime > 0f && !frozen) toastTime -= dt;
        if (!frozen) for (int i = 0; i < POPS; i++) if (popLife[i] > 0f) { popLife[i] -= dt * 1.1f; popY[i] += 160f * dt; }
    }

    private void checkLiveGoals() {
        live.from(world);
        Profile p = g.profile;
        for (int i = 0; i < Profile.SLOTS; i++) {
            Mission m = p.missions[i];
            if (!missionToasted[i] && m.progressWith(live, false) >= m.target) {
                missionToasted[i] = true;
                toast("DÉFI ACCOMPLI !", m.description() + "  +" + m.reward, Palette.GOLD);
                g.audio.play(AudioEngine.MISSION, 0.8f, 1f);
                g.haptics.pulse(25, 0.5f);
            }
        }
        if (!recordToasted && live.score > p.bestScore) {
            recordToasted = true;
            toast("NOUVEAU RECORD !", "Continue sur ta lancée", Palette.CYAN);
            g.audio.play(AudioEngine.RECORD, 0.7f, 1f);
        }
    }

    // ---- rendu -------------------------------------------------------------------------------

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        float ox = 0f, oy = 0f;
        if (shake > 0f) {
            ox = (g.fx.rng.nextFloat() - 0.5f) * shake * u;
            oy = (g.fx.rng.nextFloat() - 0.5f) * shake * u;
        }
        g.backdrop.draw(c, 1f);
        WorldRenderer wr = g.worldRenderer;
        wr.setView(u, h, cam, ox, oy);
        float viewTop = cam + h / u;
        wr.drawObstacles(c, world, viewTop);
        wr.drawPickups(c, world, viewTop, world.time);

        if (world.alive) drawPlayer(c, wr, ox, oy);
        g.fx.draw(c, gx, u, h, cam, ox, oy);

        for (int i = 0; i < POPS; i++) {
            if (popLife[i] <= 0f) continue;
            float a = Math.min(1f, popLife[i] * 2f);
            gx.textMid(c, popText[i], wr.sx(popX[i]), wr.sy(popY[i]), 34f * u, Palette.alpha(popColor[i], a), Gfx.CENTER, 8f * u, true);
        }
        g.backdrop.drawVignette(c);
        if (flash > 0f) {
            gx.fill.setColor(Palette.alpha(flashColor, flash * 0.6f));
            c.drawRect(0, 0, w, h, gx.fill);
        }

        if (state != OVER) {
            c.drawRect(0, 0, w, g.safeTop + 280f * u, hudShade);
            drawHud(c);
        }
        switch (state) {
            case READY: drawReady(c); break;
            case COUNTDOWN: drawCountdown(c); break;
            case PAUSED: drawPause(c); break;
            case OVER: drawOver(c); break;
            default: break;
        }
        drawButtons(c);
    }

    private void drawPlayer(Canvas c, WorldRenderer wr, float ox, float oy) {
        final Gfx gx = g.gfx;
        final float u = g.u;
        float sx = wr.sx(world.px), sy = wr.sy(world.py);
        g.painter.trail(c, skin, trail, u, g.height, cam, time, ox, oy, state == PLAYING);
        if (world.magnetTime > 0f) {
            float p = (time * 2f) % 1f;
            gx.ring(c, sx, sy, (400f - 300f * p) * u, Palette.alpha(Palette.MAGENTA, 0.35f * p), 3f * u);
        }
        boolean blink = world.invulnTime > 0f && ((int) (time * 16f)) % 2 == 0;
        if (!blink) {
            float tilt = Math.max(-1f, Math.min(1f, world.pvx / 2500f));
            g.painter.sphere(c, skin, sx, sy, GameWorld.PR * u, time, tilt);
        }
        if (world.shield) {
            float r = (GameWorld.PR + 22f) * u;
            gx.glow(c, sx, sy, r * 1.6f, 0xFF4DA6FF, 0.5f);
            gx.polygon(c, sx, sy, r, 6, time * 1.5f, Palette.withAlpha(0xFF8FD0FF, 220), 4f * u, false);
        }
    }

    private void drawHud(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width;
        float top = g.safeTop;
        scoreText.set(world.score());
        gx.textNum(c, scoreText, w * 0.5f, top + 80f * u, 76f * u, Palette.TEXT, Gfx.CENTER, 14f * u, true);
        metersText.set(world.meters());
        gx.textNum(c, metersText, w * 0.5f, top + 150f * u, 30f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);

        // Cristaux de la partie
        crystalText.set(world.crystals);
        float cs = 40f * u;
        float right = w - 44f * u;
        gx.textNum(c, crystalText, right, top + 90f * u, cs, Palette.TEXT, Gfx.RIGHT, 0f, true);
        float tw = gx.measureNum(crystalText, cs, true);
        gx.crystalIcon(c, right - tw - 32f * u, top + 90f * u, 18f * u);

        // Combo
        if (world.combo >= 3) {
            comboText.set(world.comboMultiplier());
            float k = Math.min(1f, world.comboTimer / GameWorld.COMBO_WINDOW);
            int col = world.comboMultiplier() >= 5 ? Palette.GOLD : Palette.CYAN;
            gx.textNum(c, comboText, w * 0.5f, top + 205f * u, 32f * u, col, Gfx.CENTER, 8f * u, true);
            gx.line(c, w * 0.5f - 110f * u * k, top + 235f * u, w * 0.5f + 110f * u * k, top + 235f * u, Palette.alpha(col, 0.8f), 5f * u);
        }

        // Bonus actifs
        float bx = w - 80f * u, by = top + 190f * u;
        if (world.shield) { drawTimer(c, Pickup.SHIELD, bx, by, 1f); by += 100f * u; }
        if (world.magnetTime > 0f) { drawTimer(c, Pickup.MAGNET, bx, by, world.magnetTime / GameWorld.MAGNET_TIME); by += 100f * u; }
        if (world.doubleTime > 0f) { drawTimer(c, Pickup.DOUBLE, bx, by, world.doubleTime / GameWorld.DOUBLE_TIME); }

        if (toastTime > 0f && toastTitle != null) {
            float a = Math.min(1f, toastTime * 3f) * Math.min(1f, (2.6f - toastTime) * 6f);
            float ty = g.height * 0.3f;
            gx.rect.set(w * 0.07f, ty - 70f * u, w * 0.93f, ty + 70f * u);
            gx.fill.setColor(Palette.alpha(0xE0120A22, a));
            c.drawRoundRect(gx.rect, 24f * u, 24f * u, gx.fill);
            gx.neonRect(c, gx.rect, 24f * u, toastColor, 2.4f * u, a);
            gx.textMid(c, toastTitle, w * 0.5f, ty - 24f * u, 40f * u, Palette.alpha(toastColor, a), Gfx.CENTER, 10f * u, true);
            gx.textMid(c, toastText, w * 0.5f, ty + 30f * u, gx.fit(toastText, 28f * u, w * 0.8f, false), Palette.alpha(Palette.TEXT, a), Gfx.CENTER, 0f, false);
        }
    }

    private void drawTimer(Canvas c, int kind, float x, float y, float k) {
        final Gfx gx = g.gfx;
        final float u = g.u;
        float r = 34f * u;
        g.worldRenderer.drawPowerIcon(c, kind, x, y, r * 0.8f, time);
        gx.rect.set(x - r - 8f * u, y - r - 8f * u, x + r + 8f * u, y + r + 8f * u);
        gx.stroke.setColor(Palette.withAlpha(WorldRenderer.powerColor(kind), 230));
        gx.stroke.setStrokeWidth(5f * u);
        c.drawArc(gx.rect, -90f, 360f * Palette.clamp01(k), false, gx.stroke);
    }

    private void drawReady(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        float sy = g.worldRenderer.sy(world.py);
        float hy = sy + 150f * u;
        float swing = (float) Math.sin(time * 3f);
        float hx = w * 0.5f + swing * 160f * u;
        gx.line(c, w * 0.5f - 200f * u, hy, w * 0.5f + 200f * u, hy, Palette.withAlpha(Palette.CYAN, 70), 6f * u);
        gx.glow(c, hx, hy, 60f * u, Palette.CYAN, 0.9f);
        gx.circle(c, hx, hy, 22f * u, Palette.withAlpha(Palette.WHITE, 220));
        gx.ring(c, hx, hy, (32f + 10f * Math.abs(swing)) * u, Palette.withAlpha(Palette.CYAN, 200), 3f * u);
        String title = g.profile.tutorialDone ? "GLISSE POUR DÉMARRER" : "GLISSE TON DOIGT";
        gx.textMid(c, title, w * 0.5f, h * 0.36f, gx.fit(title, 54f * u, w * 0.9f, true), Palette.TEXT, Gfx.CENTER, 14f * u, true);
        String sub = g.profile.tutorialDone ? "Évite les pièges, ramasse les cristaux" : "La sphère suit ton doigt horizontalement";
        gx.textMid(c, sub, w * 0.5f, h * 0.36f + 70f * u, gx.fit(sub, 30f * u, w * 0.9f, false), Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
    }

    private void drawCountdown(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u;
        int n = 3 - (int) (stateTime / 0.6f);
        if (n < 1) n = 1;
        float k = (stateTime % 0.6f) / 0.6f;
        String s = n == 3 ? "3" : (n == 2 ? "2" : "1");
        gx.textMid(c, s, g.width * 0.5f, g.height * 0.42f, (200f - 60f * k) * u, Palette.alpha(Palette.CYAN, 1f - k * 0.6f), Gfx.CENTER, 30f * u, true);
    }

    private void dim(Canvas c, float a) {
        g.gfx.fill.setColor(Palette.withAlpha(0xFF05020B, (int) (a * 255)));
        c.drawRect(0, 0, g.width, g.height, g.gfx.fill);
    }

    private void drawPause(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        dim(c, Math.min(0.72f, stateTime * 4f));
        gx.rect.set(w * 0.5f - 360f * u, h * 0.5f - 400f * u, w * 0.5f + 360f * u, h * 0.5f + 470f * u);
        gx.panel(c, gx.rect, 40f * u, Palette.PANEL, Palette.VIOLET, 2f * u);
        gx.textMid(c, "PAUSE", w * 0.5f, h * 0.5f - 290f * u, 84f * u, Palette.TEXT, Gfx.CENTER, 18f * u, true);
    }

    private void drawOver(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width;
        if (report == null) return;
        float t = stateTime;
        dim(c, Math.min(0.75f, t * 2f));
        float ease = 1f - (float) Math.pow(1f - Math.min(1f, t / 0.45f), 3);
        float off = (1f - ease) * g.height * 0.6f;

        float contentH = 640f * u + doneCount * 82f * u + (nextSkin >= 0 ? 170f * u : 0f) + 110f * u;
        float areaTop = g.safeTop + 40f * u, areaBottom = replayBtn.r.top - 40f * u;
        float top = Math.max(areaTop, areaTop + (areaBottom - areaTop - contentH) * 0.5f) + off;
        float bottom = top + contentH;
        gx.rect.set(w * 0.06f, top, w * 0.94f, bottom);
        gx.panel(c, gx.rect, 44f * u, Palette.PANEL, report.newBest ? Palette.GOLD : Palette.MAGENTA, 2.2f * u);

        float y = top + 90f * u;
        if (report.newBest) {
            float p = 0.75f + 0.25f * (float) Math.sin(time * 6f);
            gx.textMid(c, "NOUVEAU RECORD !", w * 0.5f, y, gx.fit("NOUVEAU RECORD !", 60f * u, w * 0.8f, true), Palette.alpha(Palette.GOLD, p), Gfx.CENTER, 20f * u, true);
        } else {
            gx.textMid(c, "FIN DE PARTIE", w * 0.5f, y, 60f * u, Palette.MAGENTA, Gfx.CENTER, 16f * u, true);
        }

        float k = Math.min(1f, Math.max(0f, (t - 0.3f) / 0.9f));
        k = 1f - (1f - k) * (1f - k);
        overScore.set(k >= 1f ? live.score : (long) (live.score * k));
        y += 150f * u;
        gx.textMid(c, "SCORE", w * 0.5f, y - 70f * u, 30f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textNum(c, overScore, w * 0.5f, y + 10f * u, 130f * u, Palette.TEXT, Gfx.CENTER, 22f * u, true);
        y += 110f * u;
        overBest.set(g.profile.bestScore);
        gx.textNum(c, overBest, w * 0.5f, y, 34f * u, Palette.GOLD, Gfx.CENTER, 0f, true);

        // Statistiques de la partie
        y += 110f * u;
        float colW = w * 0.88f / 3f;
        float x0 = w * 0.06f + colW * 0.5f;
        overMeters.set(live.meters);
        overCrystals.set(live.crystals);
        overTime.set(live.seconds);
        gx.textMid(c, "DISTANCE", x0, y - 32f * u, 26f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textNum(c, overMeters, x0, y + 22f * u, 42f * u, Palette.TEXT, Gfx.CENTER, 0f, true);
        gx.textMid(c, "CRISTAUX", x0 + colW, y - 32f * u, 26f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textNum(c, overCrystals, x0 + colW, y + 22f * u, 42f * u, Palette.CYAN, Gfx.CENTER, 0f, true);
        gx.textMid(c, "TEMPS", x0 + colW * 2f, y - 32f * u, 26f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
        gx.textNum(c, overTime, x0 + colW * 2f, y + 22f * u, 42f * u, Palette.TEXT, Gfx.CENTER, 0f, true);

        // Défis accomplis
        y += 120f * u;
        for (int i = 0; i < doneCount; i++) {
            gx.rect.set(w * 0.1f, y - 34f * u, w * 0.9f, y + 34f * u);
            gx.panel(c, gx.rect, 20f * u, 0x40FFD36B, 0, 0f);
            gx.check(c, w * 0.1f + 44f * u, y, 30f * u, Palette.GOLD);
            String d = doneDesc[i];
            gx.textMid(c, d, w * 0.1f + 84f * u, y, gx.fit(d, 24f * u, w * 0.56f, false), Palette.TEXT, Gfx.LEFT, 0f, false);
            gx.textMid(c, doneReward[i], w * 0.9f - 70f * u, y, 28f * u, Palette.GOLD, Gfx.RIGHT, 0f, true);
            gx.crystalIcon(c, w * 0.9f - 40f * u, y, 12f * u);
            y += 82f * u;
        }

        // Prochain skin à débloquer
        if (nextSkin >= 0) {
            Skins.Skin ns = Skins.get(nextSkin);
            float by = y + 40f * u;
            g.painter.sphere(c, ns, w * 0.1f + 50f * u, by + 10f * u, 30f * u, time, 0f);
            gx.textMid(c, nextSkinLabel, w * 0.1f + 110f * u, by - 22f * u, gx.fit(nextSkinLabel, 26f * u, w * 0.5f, true), Palette.TEXT, Gfx.LEFT, 0f, true);
            float bl = w * 0.1f + 110f * u, br = w * 0.9f;
            float ratio = Palette.clamp01(g.profile.bank / (float) Math.max(1, ns.price));
            gx.rect.set(bl, by + 18f * u, br, by + 42f * u);
            gx.panel(c, gx.rect, 12f * u, 0xFF0C0618, 0, 0f);
            gx.rect.set(bl, by + 18f * u, bl + (br - bl) * ratio, by + 42f * u);
            gx.fill.setColor(ratio >= 1f ? Palette.GREEN : ns.glow);
            c.drawRoundRect(gx.rect, 12f * u, 12f * u, gx.fill);
            gx.textMid(c, nextSkinProgress, br, by - 22f * u, 24f * u, ratio >= 1f ? Palette.GREEN : Palette.TEXT_DIM, Gfx.RIGHT, 0f, true);
            y += 170f * u;
        }

        // Total gagné
        overTotal.set(report.runCrystals + report.missionCrystals);
        float ty = y + 10f * u;
        gx.textMid(c, "GAINS", w * 0.5f - 60f * u, ty, 30f * u, Palette.TEXT_DIM, Gfx.RIGHT, 0f, false);
        gx.textNum(c, overTotal, w * 0.5f - 30f * u, ty, 44f * u, Palette.CYAN, Gfx.LEFT, 10f * u, true);
        float tw = gx.measureNum(overTotal, 44f * u, true);
        gx.crystalIcon(c, w * 0.5f - 30f * u + tw + 34f * u, ty, 16f * u);
    }
}
