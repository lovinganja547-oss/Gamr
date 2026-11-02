package com.neonrush.app;

import android.graphics.Canvas;

import com.neonrush.core.Profile;
import com.neonrush.core.Skins;

/** Boutique de skins avec grille défilante et panneau de détail. */
final class ShopScreen extends Screen {
    private static final int COLS = 3;
    private int selected;
    private float scroll, scrollVel, maxScroll;
    private float gridTop, gridBottom, cardW, cardH, gap, margin, panelTop;
    private boolean dragging, downInGrid;
    private float downY, lastY, downX;
    private long lastMoveNs;
    private Button action;
    private float unlockAnim;
    private int unlockIdx = -1;
    private final String[] priceText = new String[Skins.count()];

    ShopScreen(Game g) {
        super(g);
        for (int i = 0; i < priceText.length; i++) priceText[i] = String.valueOf(Skins.get(i).price);
    }

    @Override
    void layout() {
        float u = g.u, w = g.width, h = g.height;
        addBackButton();
        margin = 40f * u;
        gap = 24f * u;
        cardW = (w - margin * 2f - gap * (COLS - 1)) / COLS;
        cardH = 320f * u;
        gridTop = g.safeTop + 200f * u;
        panelTop = h - g.safeBottom - 400f * u;
        gridBottom = panelTop - 20f * u;
        int rows = (Skins.count() + COLS - 1) / COLS;
        float content = rows * cardH + (rows - 1) * gap + 20f * u;
        maxScroll = Math.max(0f, content - (gridBottom - gridTop));
        action = new Button("", Palette.CYAN, Button.PRIMARY, this::onAction);
        action.set(w * 0.42f, panelTop + 220f * u, w - 50f * u, panelTop + 350f * u);
        buttons.add(action);
        refresh();
    }

    @Override
    void enter() {
        selected = g.profile.equipped;
        scroll = 0f;
        scrollVel = 0f;
        unlockAnim = 0f;
        g.fx.clear();
        // Fait défiler jusqu'au skin équipé.
        float rowY = (selected / COLS) * (cardH + gap);
        scroll = Math.max(0f, Math.min(maxScroll, rowY - (gridBottom - gridTop - cardH) * 0.5f));
        refresh();
    }

    private void refresh() {
        if (action == null) return;
        Profile p = g.profile;
        Skins.Skin s = Skins.get(selected);
        action.sub = null;
        action.icon = Button.ICON_NONE;
        if (p.equipped == selected) {
            action.label = "ÉQUIPÉ";
            action.enabled = false;
            action.color = Palette.GREEN;
        } else if (p.owns(selected)) {
            action.label = "ÉQUIPER";
            action.enabled = true;
            action.color = Palette.CYAN;
        } else if (p.bank >= s.price) {
            action.label = priceText[selected];
            action.icon = Button.ICON_CRYSTAL;
            action.sub = "ACHETER";
            action.enabled = true;
            action.color = Palette.MAGENTA;
        } else {
            action.label = priceText[selected];
            action.icon = Button.ICON_CRYSTAL;
            action.sub = "IL MANQUE " + (s.price - p.bank);
            action.enabled = false;
            action.color = Palette.TEXT_DIM;
        }
    }

    private void onAction() {
        Profile p = g.profile;
        if (p.owns(selected)) {
            p.equip(selected);
        } else if (p.buy(selected)) {
            g.audio.play(AudioEngine.UNLOCK, 0.9f, 1f);
            g.haptics.pulse(60, 0.8f);
            unlockAnim = 1f;
            unlockIdx = selected;
            float cx = cardX(selected) + cardW * 0.5f, cy = cardY(selected) + cardH * 0.4f;
            int col = Skins.get(selected).glow;
            g.fx.burst(Particles.SPARK, g.wx(cx), g.wy(cy), 40, 200f, 900f, 0.7f, 6f, col);
            g.fx.burst(Particles.SHARD, g.wx(cx), g.wy(cy), 18, 100f, 500f, 0.9f, 10f, Palette.WHITE);
            g.fx.spawn(Particles.RING, g.wx(cx), g.wy(cy), 0f, 0f, 0.6f, 300f, col, 0f);
        }
        refresh();
    }

    private float cardX(int i) { return margin + (i % COLS) * (cardW + gap); }

    private float cardY(int i) { return gridTop + 10f * g.u + (i / COLS) * (cardH + gap) - scroll; }

    @Override
    void touch(int action, float x, float y) {
        if (touchButtons(action, x, y)) return;
        float u = g.u;
        switch (action) {
            case DOWN:
                downInGrid = y >= gridTop && y <= gridBottom;
                dragging = false;
                downX = x; downY = lastY = y;
                scrollVel = 0f;
                lastMoveNs = System.nanoTime();
                break;
            case MOVE:
                if (!downInGrid) break;
                if (!dragging && Math.abs(y - downY) > 18f * u) dragging = true;
                if (dragging) {
                    long now = System.nanoTime();
                    float dts = Math.max(0.001f, (now - lastMoveNs) / 1e9f);
                    float dy = y - lastY;
                    scroll = Math.max(-60f * u, Math.min(maxScroll + 60f * u, scroll - dy));
                    scrollVel = scrollVel * 0.3f + (-dy / dts) * 0.7f;
                    lastMoveNs = now;
                }
                lastY = y;
                break;
            case UP:
                if (downInGrid && !dragging) {
                    for (int i = 0; i < Skins.count(); i++) {
                        float cx = cardX(i), cy = cardY(i);
                        if (x >= cx && x <= cx + cardW && y >= cy && y <= cy + cardH && cy + cardH > gridTop && cy < gridBottom) {
                            if (selected != i) {
                                selected = i;
                                g.audio.play(AudioEngine.CLICK, 0.8f, 1.1f);
                                g.haptics.tick();
                                refresh();
                            }
                            break;
                        }
                    }
                }
                if ((System.nanoTime() - lastMoveNs) > 80_000_000L) scrollVel = 0f;
                downInGrid = false;
                dragging = false;
                break;
            default:
                downInGrid = false;
                dragging = false;
                break;
        }
    }

    @Override
    void update(float dt) {
        super.update(dt);
        if (!dragging) {
            scroll += scrollVel * dt;
            scrollVel *= (float) Math.pow(0.04, dt);
            if (Math.abs(scrollVel) < 5f) scrollVel = 0f;
            if (scroll < 0f) { scroll += (0f - scroll) * Math.min(1f, dt * 12f); if (scrollVel < 0f) scrollVel = 0f; }
            if (scroll > maxScroll) { scroll += (maxScroll - scroll) * Math.min(1f, dt * 12f); if (scrollVel > 0f) scrollVel = 0f; }
        }
        if (unlockAnim > 0f) unlockAnim = Math.max(0f, unlockAnim - dt * 0.8f);
        g.fx.update(dt);
        g.backdrop.update(dt, 120f * g.u);
    }

    @Override
    void draw(Canvas c) {
        final Gfx gx = g.gfx;
        final float u = g.u, w = g.width, h = g.height;
        final Profile p = g.profile;
        g.backdrop.draw(c, 0.6f);

        c.save();
        c.clipRect(0, gridTop, w, gridBottom);
        for (int i = 0; i < Skins.count(); i++) {
            float x = cardX(i), y = cardY(i);
            if (y > gridBottom || y + cardH < gridTop) continue;
            Skins.Skin s = Skins.get(i);
            boolean owned = p.owns(i), sel = i == selected, eq = i == p.equipped;
            gx.rect.set(x, y, x + cardW, y + cardH);
            int border = sel ? Palette.CYAN : (owned ? Palette.VIOLET : 0x00000000);
            gx.fill.setColor(sel ? 0xF0201040 : 0xD0140B26);
            c.drawRoundRect(gx.rect, 28f * u, 28f * u, gx.fill);
            if (border != 0) gx.neonRect(c, gx.rect, 28f * u, border, (sel ? 2.6f : 1.4f) * u, sel ? 1f : 0.6f);
            else {
                gx.stroke.setColor(0x40FFFFFF);
                gx.stroke.setStrokeWidth(1.5f * u);
                c.drawRoundRect(gx.rect, 28f * u, 28f * u, gx.stroke);
            }
            float cx = x + cardW * 0.5f, sy = y + cardH * 0.4f;
            float scaleAnim = (i == unlockIdx && unlockAnim > 0f) ? 1f + 0.4f * unlockAnim : 1f;
            g.painter.sphere(c, s, cx, sy, 40f * u * scaleAnim, time + i, 0f);
            if (!owned) {
                gx.fill.setColor(0x8A0A0614);
                c.drawCircle(cx, sy, 90f * u, gx.fill);
                drawLock(c, cx, sy, u);
            }
            gx.textMid(c, s.name, cx, y + cardH * 0.74f, gx.fit(s.name, 30f * u, cardW * 0.9f, true), Palette.TEXT, Gfx.CENTER, 0f, true);
            float ly = y + cardH * 0.88f;
            if (eq) gx.textMid(c, "ÉQUIPÉ", cx, ly, 24f * u, Palette.GREEN, Gfx.CENTER, 0f, true);
            else if (owned) gx.textMid(c, "POSSÉDÉ", cx, ly, 24f * u, Palette.TEXT_DIM, Gfx.CENTER, 0f, false);
            else {
                String pr = priceText[i];
                float tw = gx.measure(pr, 26f * u, true);
                boolean afford = p.bank >= s.price;
                gx.crystalIcon(c, cx - tw * 0.5f - 14f * u, ly, 11f * u);
                gx.textMid(c, pr, cx + 12f * u, ly, 26f * u, afford ? Palette.CYAN : Palette.TEXT_DIM, Gfx.CENTER, 0f, true);
            }
        }
        g.fx.draw(c, gx, u, h, 0f, 0f, 0f);
        c.restore();

        // Fondu en haut/bas de la grille
        gx.line(c, margin, gridTop, w - margin, gridTop, 0x30FFFFFF, 2f * u);
        gx.line(c, margin, gridBottom, w - margin, gridBottom, 0x30FFFFFF, 2f * u);

        // Panneau de détail
        Skins.Skin s = Skins.get(selected);
        gx.rect.set(30f * u, panelTop, w - 30f * u, h - g.safeBottom - 30f * u);
        gx.panel(c, gx.rect, 40f * u, Palette.PANEL_LIGHT, s.glow, 2f * u);
        float px = w * 0.2f, py = panelTop + 185f * u;
        g.painter.sphere(c, s, px, py, 62f * u, time, (float) Math.sin(time * 2f) * 0.5f);
        gx.textMid(c, s.name, w * 0.42f, panelTop + 85f * u, gx.fit(s.name, 56f * u, w * 0.54f, true), Palette.TEXT, Gfx.LEFT, 12f * u, true);
        gx.textMid(c, s.tagline, w * 0.42f, panelTop + 150f * u, gx.fit(s.tagline, 28f * u, w * 0.54f, false), Palette.TEXT_DIM, Gfx.LEFT, 0f, false);

        g.backdrop.drawVignette(c);
        drawHeader(c, "BOUTIQUE");
        drawButtons(c);
    }

    private void drawLock(Canvas c, float cx, float cy, float u) {
        final Gfx gx = g.gfx;
        gx.rect.set(cx - 24f * u, cy - 4f * u, cx + 24f * u, cy + 34f * u);
        gx.fill.setColor(0xFFB9B3E0);
        c.drawRoundRect(gx.rect, 6f * u, 6f * u, gx.fill);
        gx.rect.set(cx - 16f * u, cy - 30f * u, cx + 16f * u, cy + 6f * u);
        gx.stroke.setColor(0xFFB9B3E0);
        gx.stroke.setStrokeWidth(7f * u);
        c.drawArc(gx.rect, 180f, 180f, false, gx.stroke);
        gx.circle(c, cx, cy + 13f * u, 5f * u, 0xFF1A0F33);
    }

    @Override
    boolean back() {
        g.go(g.menu);
        return true;
    }
}
