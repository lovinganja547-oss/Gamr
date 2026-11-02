package com.neonrush.app;

import android.graphics.Bitmap;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Shader;

import com.neonrush.core.GameWorld;
import com.neonrush.core.Obstacle;
import com.neonrush.core.Pickup;

/** Rendu des obstacles et objets du monde. */
final class WorldRenderer {
    private final Gfx g;
    private final Paint stripeBar = new Paint(), stripeSlider = new Paint(), stripeZone = new Paint();
    private final Matrix m = new Matrix();
    private float u, base, cam, ox, oy;

    WorldRenderer(Gfx g) {
        this.g = g;
        stripeBar.setShader(stripes(0x40FF2BD6));
        stripeSlider.setShader(stripes(0x48FF8A1F));
        stripeZone.setShader(stripes(0xFFFF5A1F));
    }

    private static BitmapShader stripes(int color) {
        int s = 32;
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        p.setStrokeWidth(7f);
        for (int k = -1; k <= 1; k++) c.drawLine(k * s - 2, s + 2, k * s + s + 2, -2, p);
        return new BitmapShader(b, Shader.TileMode.REPEAT, Shader.TileMode.REPEAT);
    }

    void setView(float u, float base, float cam, float ox, float oy) {
        this.u = u; this.base = base; this.cam = cam; this.ox = ox; this.oy = oy;
        float scroll = (cam * u) % 64f;
        m.setScale(u * 1.6f, u * 1.6f);
        m.postTranslate(ox, oy + scroll);
        stripeBar.getShader().setLocalMatrix(m);
        stripeSlider.getShader().setLocalMatrix(m);
        stripeZone.getShader().setLocalMatrix(m);
    }

    float sx(float x) { return x * u + ox; }

    float sy(float y) { return base - (y - cam) * u + oy; }

    void drawObstacles(Canvas c, GameWorld w, float viewTop) {
        final float t = w.time;
        // Zones d'abord (au sol), puis le reste.
        for (int pass = 0; pass < 2; pass++) {
            for (int i = 0, n = w.obstacles.size(); i < n; i++) {
                Obstacle o = w.obstacles.get(i);
                if (o.bottom() > viewTop || o.top() < cam - 200f) continue;
                boolean zone = o.type == Obstacle.ZONE;
                if ((pass == 0) != zone) continue;
                switch (o.type) {
                    case Obstacle.BAR: drawBlock(c, o.x, o.y, o.w, o.h, Palette.MAGENTA, stripeBar); break;
                    case Obstacle.SLIDER: drawBlock(c, o.x + o.offsetX(t), o.y, o.w, o.h, Palette.ORANGE, stripeSlider); break;
                    case Obstacle.LASER: drawLaser(c, o, t); break;
                    case Obstacle.SPINNER: drawSpinner(c, o, t); break;
                    case Obstacle.MINE: drawMine(c, o, t); break;
                    case Obstacle.ZONE: drawZone(c, o, t); break;
                    default: break;
                }
            }
        }
    }

    private void drawBlock(Canvas c, float x, float y, float bw, float bh, int color, Paint stripes) {
        float l = sx(x), r = sx(x + bw), top = sy(y + bh), bot = sy(y);
        g.rect.set(l, top, r, bot);
        g.fill.setColor(Palette.withAlpha(Palette.lerp(color, 0xFF000000, 0.75f), 210));
        c.drawRect(g.rect, g.fill);
        c.drawRect(g.rect, stripes);
        g.neonRect(c, g.rect, 6f * u, color, 3f * u, 1f);
    }

    private void drawLaser(Canvas c, Obstacle o, float t) {
        int st = o.state(t);
        float p = o.stateProgress(t);
        float x1 = sx(o.x), x2 = sx(o.x + o.w), y = sy(o.y);
        boolean fromLeft = o.x <= 1f;
        float wallX = fromLeft ? x1 : x2, tipX = fromLeft ? x2 : x1;
        int beam = Palette.RED;
        if (st == Obstacle.ON) {
            float flick = 0.85f + 0.15f * (float) Math.sin(t * 60f + o.seed);
            g.line(c, x1, y, x2, y, Palette.withAlpha(Palette.MAGENTA, 50), 46f * u * flick);
            g.line(c, x1, y, x2, y, Palette.withAlpha(beam, 140), 22f * u * flick);
            g.line(c, x1, y, x2, y, 0xFFFFE6EE, 8f * u);
        } else if (st == Obstacle.WARN) {
            float blink = ((int) (p * (6f + p * 10f))) % 2 == 0 ? 1f : 0.35f;
            g.line(c, x1, y, x2, y, Palette.alpha(beam, 0.75f * blink), (2f + 4f * p) * u);
        } else {
            g.stroke.setColor(Palette.withAlpha(beam, 60));
            g.stroke.setStrokeWidth(2f * u);
            float step = 26f * u;
            float dir = x2 > x1 ? 1f : -1f;
            for (float xx = x1; (xx - x2) * dir < 0f; xx += step * dir)
                c.drawLine(xx, y, xx + step * 0.45f * dir, y, g.stroke);
        }
        // Émetteurs
        float charge = st == Obstacle.ON ? 1f : (st == Obstacle.WARN ? 0.4f + 0.6f * p : 0.2f);
        g.glow(c, tipX, y, 40f * u, beam, 0.4f + 0.6f * charge);
        g.circle(c, tipX, y, 11f * u, 0xFF2A0A1A);
        g.ring(c, tipX, y, 11f * u, Palette.lerp(beam, Palette.WHITE, charge * 0.6f), 4f * u);
        g.rect.set(wallX - 18f * u, y - 26f * u, wallX + 18f * u, y + 26f * u);
        g.panel(c, g.rect, 6f * u, 0xFF1C0A26, beam, 2.5f * u);
        g.circle(c, wallX + (fromLeft ? 6f : -6f) * u, y, 7f * u, Palette.lerp(0xFF551122, Palette.WHITE, charge));
    }

    private void drawSpinner(Canvas c, Obstacle o, float t) {
        float cx = sx(o.x), cy = sy(o.y);
        float r = o.r * u;
        for (int k = 2; k >= 0; k--) {
            float a = -(o.angle(t) - o.freq * 0.035f * k);
            float dx = (float) Math.cos(a) * r, dy = (float) Math.sin(a) * r;
            if (k == 0) {
                g.neonLine(c, cx - dx, cy - dy, cx + dx, cy + dy, Palette.VIOLET, Obstacle.SPINNER_HALF * 2f * u * 0.55f, 1f);
            } else {
                g.line(c, cx - dx, cy - dy, cx + dx, cy + dy, Palette.withAlpha(Palette.VIOLET, 50 / k), Obstacle.SPINNER_HALF * 2f * u);
            }
        }
        g.glow(c, cx, cy, 70f * u, Palette.VIOLET, 0.8f);
        g.circle(c, cx, cy, Obstacle.SPINNER_HUB * u, 0xFF1A0B33);
        g.ring(c, cx, cy, Obstacle.SPINNER_HUB * u, 0xFFD9B8FF, 4f * u);
        g.circle(c, cx, cy, 7f * u, Palette.WHITE);
    }

    private void drawMine(Canvas c, Obstacle o, float t) {
        float cx = sx(o.x + o.offsetX(t)), cy = sy(o.y);
        float r = o.r * u;
        float pulse = (t * 1.2f + o.seed * 0.001f) % 1f;
        g.ring(c, cx, cy, r * (1.1f + pulse * 1.3f), Palette.alpha(Palette.ORANGE, (1f - pulse) * 0.6f), 3f * u);
        g.glow(c, cx, cy, r * 2.4f, Palette.ORANGE, 0.6f);
        float rot = t * 1.5f + o.seed;
        for (int i = 0; i < 8; i++) {
            double a = rot + i * Math.PI / 4;
            float ca = (float) Math.cos(a), sa = (float) Math.sin(a);
            g.line(c, cx + ca * r * 0.7f, cy + sa * r * 0.7f, cx + ca * r * 1.28f, cy + sa * r * 1.28f, Palette.ORANGE, 5f * u);
        }
        g.circle(c, cx, cy, r * 0.9f, 0xFF2A1205);
        g.ring(c, cx, cy, r * 0.9f, 0xFFFFB061, 4f * u);
        boolean blink = ((int) (t * 4f + o.seed)) % 2 == 0;
        g.circle(c, cx, cy, r * 0.32f, blink ? 0xFFFF3B3B : 0xFF7A1A10);
        if (blink) g.glow(c, cx, cy, r * 1.0f, 0xFFFF3B3B, 0.7f);
    }

    private void drawZone(Canvas c, Obstacle o, float t) {
        int st = o.state(t);
        float p = o.stateProgress(t);
        float l = sx(o.x), r = sx(o.x + o.w), top = sy(o.y + o.h), bot = sy(o.y);
        g.rect.set(l, top, r, bot);
        if (st == Obstacle.ON) {
            g.fill.setColor(0x66FF3D14);
            c.drawRect(g.rect, g.fill);
            stripeZone.setAlpha(150);
            c.drawRect(g.rect, stripeZone);
            g.neonRect(c, g.rect, 4f * u, Palette.ORANGE, 3f * u, 1f);
            // Arcs électriques
            int seed = (int) (t * 18f) + o.seed;
            g.stroke.setColor(0xFFFFF0C0);
            g.stroke.setStrokeWidth(3f * u);
            for (int k = 0; k < 3; k++) {
                g.path.reset();
                float yy = top + (bot - top) * (0.2f + 0.3f * k);
                g.path.moveTo(l, yy);
                int segs = 8;
                for (int s = 1; s <= segs; s++) {
                    seed = seed * 1103515245 + 12345;
                    float jitter = ((seed >>> 16) & 0xFF) / 255f - 0.5f;
                    g.path.lineTo(l + (r - l) * s / segs, yy + jitter * 60f * u);
                }
                c.drawPath(g.path, g.stroke);
            }
        } else {
            float a = st == Obstacle.WARN ? (((int) (p * 8f)) % 2 == 0 ? 0.9f : 0.4f) : 0.25f;
            g.fill.setColor(Palette.alpha(0x30FF5A1F, a));
            c.drawRect(g.rect, g.fill);
            stripeZone.setAlpha((int) (60 * a));
            c.drawRect(g.rect, stripeZone);
            g.stroke.setColor(Palette.alpha(Palette.ORANGE, a));
            g.stroke.setStrokeWidth(2.5f * u);
            c.drawRect(g.rect, g.stroke);
            if (st == Obstacle.WARN) {
                float cx = (l + r) * 0.5f, cy = (top + bot) * 0.5f;
                g.polygon(c, cx, cy, 46f * u, 3, -1.5708f, Palette.alpha(Palette.ORANGE, a), 5f * u, false);
                g.line(c, cx, cy - 14f * u, cx, cy + 6f * u, Palette.alpha(Palette.ORANGE, a), 6f * u);
                g.circle(c, cx, cy + 16f * u, 3.5f * u, Palette.alpha(Palette.ORANGE, a));
            }
        }
    }

    void drawPickups(Canvas c, GameWorld w, float viewTop, float time) {
        for (int i = 0, n = w.pickups.size(); i < n; i++) {
            Pickup p = w.pickups.get(i);
            if (p.y > viewTop + 60f || p.y < cam - 100f) continue;
            float x = sx(p.x), y = sy(p.y) + (float) Math.sin(time * 3f + p.phase) * 5f * u;
            if (p.kind == Pickup.CRYSTAL) {
                float spin = (float) Math.cos(time * 3.2f + p.phase);
                g.glow(c, x, y, 52f * u, Palette.CYAN, 0.75f);
                g.diamond(c, x, y, 20f * u, 0.35f + 0.65f * Math.abs(spin), spin > 0 ? 0xFF22E8FF : 0xFF00A8D8, 0xFFE8FFFF);
            } else {
                drawPowerIcon(c, p.kind, x, y, 30f * u, time + p.phase);
            }
        }
    }

    static int powerColor(int kind) {
        switch (kind) {
            case Pickup.SHIELD: return 0xFF4DA6FF;
            case Pickup.MAGNET: return Palette.MAGENTA;
            default: return Palette.GOLD;
        }
    }

    void drawPowerIcon(Canvas c, int kind, float x, float y, float r, float time) {
        int col = powerColor(kind);
        float pulse = (time * 1.4f) % 1f;
        g.glow(c, x, y, r * 2.6f, col, 0.8f);
        g.ring(c, x, y, r * (1.05f + pulse * 0.7f), Palette.alpha(col, 1f - pulse), r * 0.08f);
        g.polygon(c, x, y, r, 6, time * 0.8f, 0xFF120A24, 0f, true);
        g.polygon(c, x, y, r, 6, time * 0.8f, col, r * 0.12f, false);
        switch (kind) {
            case Pickup.SHIELD:
                g.path.reset();
                g.path.moveTo(x, y - r * 0.55f);
                g.path.lineTo(x + r * 0.45f, y - r * 0.35f);
                g.path.lineTo(x + r * 0.38f, y + r * 0.15f);
                g.path.lineTo(x, y + r * 0.58f);
                g.path.lineTo(x - r * 0.38f, y + r * 0.15f);
                g.path.lineTo(x - r * 0.45f, y - r * 0.35f);
                g.path.close();
                g.stroke.setColor(Palette.WHITE);
                g.stroke.setStrokeWidth(r * 0.12f);
                c.drawPath(g.path, g.stroke);
                break;
            case Pickup.MAGNET:
                g.rect.set(x - r * 0.42f, y - r * 0.42f, x + r * 0.42f, y + r * 0.42f);
                g.stroke.setColor(Palette.WHITE);
                g.stroke.setStrokeWidth(r * 0.2f);
                c.drawArc(g.rect, 0f, 180f, false, g.stroke);
                g.line(c, x - r * 0.42f, y, x - r * 0.42f, y - r * 0.4f, Palette.WHITE, r * 0.2f);
                g.line(c, x + r * 0.42f, y, x + r * 0.42f, y - r * 0.4f, Palette.WHITE, r * 0.2f);
                break;
            default:
                g.textMid(c, "x2", x, y, r * 0.75f, Palette.WHITE, Gfx.CENTER, 0f, true);
                break;
        }
    }
}
