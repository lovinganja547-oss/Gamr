package com.neonrush.app;

import android.content.res.AssetManager;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.util.SparseArray;

/** Primitives de dessin néon partagées (aucune allocation dans la boucle de rendu). */
final class Gfx {
    final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
    final Paint textReg = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
    final Path path = new Path();
    final RectF rect = new RectF();
    private final SparseArray<Paint> glowCache = new SparseArray<>();
    final Typeface font;

    Gfx(AssetManager assets) {
        Typeface tf;
        try {
            tf = Typeface.createFromAsset(assets, "fonts/orbitron.ttf");
        } catch (RuntimeException e) {
            tf = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD);
        }
        font = tf;
        fill.setStyle(Paint.Style.FILL);
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeCap(Paint.Cap.ROUND);
        stroke.setStrokeJoin(Paint.Join.ROUND);
        text.setTypeface(font);
        textReg.setTypeface(font);
        try {
            text.setFontVariationSettings("'wght' 800");
            textReg.setFontVariationSettings("'wght' 500");
        } catch (RuntimeException ignored) {
            text.setFakeBoldText(true);
        }
    }

    // ---- texte --------------------------------------------------------------------------------

    static final int LEFT = 0, CENTER = 1, RIGHT = 2;

    void text(Canvas c, String s, float x, float y, float size, int color, int align, float glow, boolean bold) {
        Paint p = bold ? text : textReg;
        p.setTextSize(size);
        p.setColor(color);
        p.setTextAlign(align == CENTER ? Paint.Align.CENTER : (align == RIGHT ? Paint.Align.RIGHT : Paint.Align.LEFT));
        if (glow > 0f) p.setShadowLayer(glow, 0f, 0f, color);
        else p.clearShadowLayer();
        c.drawText(s, x, y, p);
        if (glow > 0f) p.clearShadowLayer();
    }

    void textNum(Canvas c, NumText n, float x, float cy, float size, int color, int align, float glow, boolean bold) {
        Paint p = bold ? text : textReg;
        p.setTextSize(size);
        p.setColor(color);
        p.setTextAlign(align == CENTER ? Paint.Align.CENTER : (align == RIGHT ? Paint.Align.RIGHT : Paint.Align.LEFT));
        if (glow > 0f) p.setShadowLayer(glow, 0f, 0f, color);
        else p.clearShadowLayer();
        c.drawText(n.buf, n.start, n.len, x, cy + size * 0.36f, p);
        if (glow > 0f) p.clearShadowLayer();
    }

    float measureNum(NumText n, float size, boolean bold) {
        Paint p = bold ? text : textReg;
        p.setTextSize(size);
        return p.measureText(n.buf, n.start, n.len);
    }

    /** Texte centré verticalement autour de cy. */
    void textMid(Canvas c, String s, float x, float cy, float size, int color, int align, float glow, boolean bold) {
        text(c, s, x, cy + size * 0.36f, size, color, align, glow, bold);
    }

    float measure(String s, float size, boolean bold) {
        Paint p = bold ? text : textReg;
        p.setTextSize(size);
        return p.measureText(s);
    }

    /** Réduit la taille pour que le texte tienne dans maxW. */
    float fit(String s, float size, float maxW, boolean bold) {
        float w = measure(s, size, bold);
        return w > maxW ? size * maxW / w : size;
    }

    // ---- formes -------------------------------------------------------------------------------

    Paint glowPaint(int color) {
        int key = color | 0xFF000000;
        Paint p = glowCache.get(key);
        if (p == null) {
            p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setShader(new RadialGradient(0f, 0f, 1f,
                    new int[]{Palette.withAlpha(key, 150), Palette.withAlpha(key, 55), Palette.withAlpha(key, 0)},
                    new float[]{0f, 0.35f, 1f}, Shader.TileMode.CLAMP));
            glowCache.put(key, p);
        }
        return p;
    }

    /** Halo radial doux. */
    void glow(Canvas c, float x, float y, float r, int color, float alpha) {
        if (r <= 0f || alpha <= 0.01f) return;
        Paint p = glowPaint(color);
        p.setAlpha((int) (255 * Palette.clamp01(alpha)));
        c.save();
        c.translate(x, y);
        c.scale(r, r);
        c.drawCircle(0f, 0f, 1f, p);
        c.restore();
    }

    void line(Canvas c, float x1, float y1, float x2, float y2, int color, float w) {
        stroke.setColor(color);
        stroke.setStrokeWidth(w);
        c.drawLine(x1, y1, x2, y2, stroke);
    }

    /** Ligne néon : halo large + cœur lumineux. */
    void neonLine(Canvas c, float x1, float y1, float x2, float y2, int color, float w, float intensity) {
        line(c, x1, y1, x2, y2, Palette.alpha(color, 0.18f * intensity), w * 4f);
        line(c, x1, y1, x2, y2, Palette.alpha(color, 0.45f * intensity), w * 2f);
        line(c, x1, y1, x2, y2, Palette.lerp(color, Palette.WHITE, 0.55f), w * 0.8f);
    }

    void neonRect(Canvas c, RectF r, float radius, int color, float w, float intensity) {
        stroke.setColor(Palette.alpha(color, 0.16f * intensity));
        stroke.setStrokeWidth(w * 4f);
        c.drawRoundRect(r, radius, radius, stroke);
        stroke.setColor(Palette.alpha(color, 0.5f * intensity));
        stroke.setStrokeWidth(w * 1.8f);
        c.drawRoundRect(r, radius, radius, stroke);
        stroke.setColor(Palette.alpha(Palette.lerp(color, Palette.WHITE, 0.4f), intensity));
        stroke.setStrokeWidth(w * 0.7f);
        c.drawRoundRect(r, radius, radius, stroke);
    }

    void panel(Canvas c, RectF r, float radius, int fillColor, int border, float w) {
        fill.setColor(fillColor);
        c.drawRoundRect(r, radius, radius, fill);
        if (border != 0) neonRect(c, r, radius, border, w, 1f);
    }

    void circle(Canvas c, float x, float y, float r, int color) {
        fill.setColor(color);
        c.drawCircle(x, y, r, fill);
    }

    void ring(Canvas c, float x, float y, float r, int color, float w) {
        stroke.setColor(color);
        stroke.setStrokeWidth(w);
        c.drawCircle(x, y, r, stroke);
    }

    /** Losange (cristal). sx : écrasement horizontal pour simuler la rotation. */
    void diamond(Canvas c, float x, float y, float s, float sx, int color, int core) {
        Path p = path;
        float hw = s * 0.62f * sx;
        p.reset();
        p.moveTo(x, y - s);
        p.lineTo(x + hw, y - s * 0.15f);
        p.lineTo(x, y + s);
        p.lineTo(x - hw, y - s * 0.15f);
        p.close();
        fill.setColor(color);
        c.drawPath(p, fill);
        p.reset();
        p.moveTo(x, y - s * 0.55f);
        p.lineTo(x + hw * 0.45f, y - s * 0.12f);
        p.lineTo(x, y + s * 0.45f);
        p.lineTo(x - hw * 0.45f, y - s * 0.12f);
        p.close();
        fill.setColor(core);
        c.drawPath(p, fill);
    }

    /** Icône de cristal pour l'interface. */
    void crystalIcon(Canvas c, float x, float y, float s) {
        glow(c, x, y, s * 2.2f, Palette.CYAN, 0.6f);
        diamond(c, x, y, s, 1f, Palette.CYAN, 0xFFE8FFFF);
    }

    void polygon(Canvas c, float x, float y, float r, int n, float rot, int color, float w, boolean filled) {
        Path p = path;
        p.reset();
        for (int i = 0; i < n; i++) {
            double a = rot + i * Math.PI * 2 / n;
            float px = x + (float) Math.cos(a) * r, py = y + (float) Math.sin(a) * r;
            if (i == 0) p.moveTo(px, py); else p.lineTo(px, py);
        }
        p.close();
        if (filled) {
            fill.setColor(color);
            c.drawPath(p, fill);
        } else {
            stroke.setColor(color);
            stroke.setStrokeWidth(w);
            c.drawPath(p, stroke);
        }
    }

    /** Coche de validation. */
    void check(Canvas c, float x, float y, float s, int color) {
        stroke.setColor(color);
        stroke.setStrokeWidth(s * 0.22f);
        Path p = path;
        p.reset();
        p.moveTo(x - s * 0.5f, y);
        p.lineTo(x - s * 0.12f, y + s * 0.38f);
        p.lineTo(x + s * 0.55f, y - s * 0.4f);
        c.drawPath(p, stroke);
    }

    /** Flèche retour. */
    void backArrow(Canvas c, float x, float y, float s, int color) {
        stroke.setColor(color);
        stroke.setStrokeWidth(s * 0.16f);
        Path p = path;
        p.reset();
        p.moveTo(x + s * 0.1f, y - s * 0.45f);
        p.lineTo(x - s * 0.4f, y);
        p.lineTo(x + s * 0.1f, y + s * 0.45f);
        p.moveTo(x - s * 0.35f, y);
        p.lineTo(x + s * 0.5f, y);
        c.drawPath(p, stroke);
    }
}
