package com.neonrush.app;

/** Synthèse procédurale de la musique et des effets (aucun contenu audio externe). */
final class Synth {
    static final int SR = 22050;
    private static final float TAU = 6.2831855f;
    private static int noiseSeed = 22222;

    private static float noise() {
        noiseSeed = noiseSeed * 1103515245 + 12345;
        return ((noiseSeed >>> 9) & 0x7FFF) / 16383.5f - 1f;
    }

    private static final float[] MIDI = new float[128];
    static {
        for (int i = 0; i < 128; i++) MIDI[i] = 440f * (float) Math.pow(2.0, (i - 69) / 12.0);
    }
    private static final int[] ARP = {1, 2, 3, 2, 3, 1};

    static float midi(int n) { return MIDI[n < 0 ? 0 : (n > 127 ? 127 : n)]; }

    private static float softClip(float x) {
        if (x > 3f) return 1f;
        if (x < -3f) return -1f;
        return x * (27f + x * x) / (27f + 9f * x * x);
    }

    static short[] toPcm(float[] f, float gain) {
        short[] s = new short[f.length];
        for (int i = 0; i < f.length; i++) s[i] = (short) (softClip(f[i] * gain) * 30000f);
        return s;
    }

    // ---- Musique ------------------------------------------------------------------------------

    /** Accords : [basse, note1, note2, note3] en MIDI. */
    private static final int[][] CHORDS = {{45, 57, 60, 64}, {41, 57, 60, 65}, {48, 55, 60, 64}, {43, 55, 59, 62}};
    private static final int[][] CHORDS_B = {{45, 57, 60, 64}, {41, 57, 60, 65}, {38, 57, 62, 65}, {40, 56, 59, 64}};
    /** Mélodie (pas de croches) : -1 = silence. */
    private static final int[] LEAD = {
            76, -1, 74, 76, -1, 79, 76, -1, 74, -1, 72, -1, 69, -1, -1, -1,
            72, -1, 74, 76, -1, 77, 76, -1, 74, -1, 72, 74, -1, -1, -1, -1,
            76, -1, 79, 81, -1, 79, 76, -1, 72, -1, 74, -1, 76, -1, -1, -1,
            71, -1, 72, 74, -1, 76, 74, -1, 71, -1, 68, -1, 71, -1, -1, -1};

    static short[] music(boolean game) {
        final float bpm = game ? 122f : 92f;
        final int bars = game ? 16 : 8;
        final float beat = 60f / bpm;
        final int spb = Math.round(beat * SR);
        final int n = spb * 4 * bars;
        final float[] out = new float[n];
        final float[] lead = game ? new float[n] : null;

        float bassPh = 0f, bassLp = 0f, arpPh = 0f, arpLp = 0f, hatLp = 0f, leadPh = 0f, vibPh = 0f;
        float[] padPh = new float[6];
        float padLp = 0f;
        final int s16 = spb / 4, s8 = spb / 2;

        for (int i = 0; i < n; i++) {
            int bar = i / (spb * 4);
            int[][] prog = (game && bar >= 8) ? CHORDS_B : CHORDS;
            int[] ch = prog[bar % 4];
            int inBeat = i % spb;
            int beatIdx = (i / spb) % 4;
            float tb = inBeat / (float) SR;
            float side = 1f - 0.55f * (float) Math.exp(-tb * 9f);
            float v = 0f;

            // Basse : croches, saut d'octave
            int e8 = i / s8;
            float t8 = (i % s8) / (float) SR;
            int bassNote = ch[0] + (((e8 & 3) == 2) ? 12 : 0);
            bassPh += midi(bassNote) / SR;
            if (bassPh >= 1f) bassPh -= 1f;
            float saw = bassPh * 2f - 1f;
            float env8 = (float) Math.exp(-t8 * (game ? 7f : 4f));
            float cut = 0.05f + 0.22f * env8;
            bassLp += cut * (saw - bassLp);
            v += bassLp * (game ? 0.42f : 0.30f) * side * (0.55f + 0.45f * env8);

            // Arpège
            int step = game ? s16 : s8;
            int e = i / step;
            float te = (i % step) / (float) SR;
            int k = e % 6;
            int note = ch[ARP[k]] + ((e / 6) % 2 == 0 ? 12 : 0);
            arpPh += midi(note) / SR;
            if (arpPh >= 1f) arpPh -= 1f;
            float sq = arpPh < 0.32f ? 1f : -1f;
            arpLp += 0.18f * (sq - arpLp);
            v += arpLp * (float) Math.exp(-te * (game ? 13f : 7f)) * (game ? 0.12f : 0.10f) * (0.6f + 0.4f * side);

            // Nappe
            float pad = 0f;
            for (int j = 0; j < 3; j++) {
                float f = midi(ch[j + 1]);
                padPh[j * 2] += f * 1.004f / SR;
                padPh[j * 2 + 1] += f * 0.996f / SR;
                if (padPh[j * 2] >= 1f) padPh[j * 2] -= 1f;
                if (padPh[j * 2 + 1] >= 1f) padPh[j * 2 + 1] -= 1f;
                pad += padPh[j * 2] + padPh[j * 2 + 1] - 1f;
            }
            padLp += 0.035f * (pad - padLp);
            v += padLp * (game ? 0.055f : 0.085f) * side;

            // Grosse caisse
            boolean kickBeat = game || beatIdx == 0 || beatIdx == 2;
            if (kickBeat && tb < 0.35f) {
                float ph = TAU * (44f * tb + 120f * (1f - (float) Math.exp(-tb * 30f)) / 30f);
                v += (float) Math.sin(ph) * (float) Math.exp(-tb * 8f) * (game ? 0.85f : 0.55f);
            }
            // Caisse claire / clap
            if (game && (beatIdx == 1 || beatIdx == 3) && tb < 0.25f) {
                float nz = noise();
                v += nz * (float) Math.exp(-tb * 16f) * 0.22f + (float) Math.sin(TAU * 185f * tb) * (float) Math.exp(-tb * 30f) * 0.18f;
            }
            // Charleston
            float nzh = noise();
            hatLp += 0.45f * (nzh - hatLp);
            float hp = nzh - hatLp;
            int h16 = i % s16;
            int idx16 = (i / s16) % 4;
            float th = h16 / (float) SR;
            if (idx16 == 2) v += hp * (float) Math.exp(-th * 45f) * (game ? 0.16f : 0.08f);
            else if (game) v += hp * (float) Math.exp(-th * 90f) * 0.05f;

            // Mélodie (seconde moitié du morceau de jeu)
            if (lead != null && bar >= 8) {
                int le = (i / s8) % LEAD.length;
                int ln = LEAD[le];
                float tl = (i % s8) / (float) SR;
                if (ln < 0) {
                    // prolongation de la note précédente
                    int prev = le;
                    int back = 0;
                    while (prev >= 0 && LEAD[prev] < 0 && back < 3) { prev--; back++; }
                    if (prev >= 0 && LEAD[prev] >= 0) { ln = LEAD[prev]; tl += back * s8 / (float) SR; }
                }
                if (ln >= 0) {
                    vibPh += 5.5f / SR;
                    float f = midi(ln) * (1f + 0.004f * (float) Math.sin(TAU * vibPh));
                    leadPh += f / SR;
                    if (leadPh >= 1f) leadPh -= 1f;
                    float tri = 1f - 4f * Math.abs(leadPh - 0.5f);
                    float env = Math.min(1f, tl * 60f) * (float) Math.exp(-tl * 1.6f);
                    lead[i] = tri * env * 0.13f;
                }
            }
            out[i] = v;
        }

        if (lead != null) {
            int d = (int) (s8 * 1.5f);
            for (int i = 0; i < n; i++) {
                float l = lead[i];
                int j = i - d;
                if (j >= 0) lead[i] = l + lead[j] * 0.35f;
                out[i] += lead[i];
            }
        }
        return toPcm(out, 0.9f);
    }

    // ---- Effets -------------------------------------------------------------------------------

    private static float[] buf(float seconds) { return new float[(int) (seconds * SR)]; }

    static float[] crystal() {
        float[] b = buf(0.22f);
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float env = (float) Math.exp(-t * 22f) * Math.min(1f, t * 400f);
            b[i] = ((float) Math.sin(TAU * 1318.5f * t) * 0.55f + (float) Math.sin(TAU * 1975.5f * t) * 0.3f
                    + (float) Math.sin(TAU * 2637f * t) * 0.12f * (float) Math.exp(-t * 40f)) * env * 0.55f;
        }
        return b;
    }

    static float[] crash() {
        float[] b = buf(0.9f);
        float lp = 0f, ph = 0f;
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float a = 0.5f * (float) Math.exp(-t * 3.5f) + 0.02f;
            lp += a * (noise() - lp);
            float f = 40f + 220f * (float) Math.exp(-t * 6f);
            ph += f / SR;
            float boom = (float) Math.sin(TAU * ph) * (float) Math.exp(-t * 4f);
            b[i] = (lp * 0.9f + boom * 0.8f) * (float) Math.exp(-t * 3f) * Math.min(1f, t * 300f);
        }
        return b;
    }

    static float[] click(float freq) {
        float[] b = buf(0.06f);
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            b[i] = (float) Math.sin(TAU * freq * t) * (float) Math.exp(-t * 70f) * Math.min(1f, t * 2000f) * 0.45f;
        }
        return b;
    }

    static float[] arpeggio(int[] notes, float noteLen, float decay, float gain) {
        float[] b = buf(noteLen * notes.length + 0.45f);
        for (int k = 0; k < notes.length; k++) {
            float f = midi(notes[k]);
            int start = (int) (k * noteLen * SR);
            for (int i = start; i < b.length; i++) {
                float t = (i - start) / (float) SR;
                float env = (float) Math.exp(-t * decay) * Math.min(1f, t * 300f);
                if (env < 0.001f) break;
                float ph = f * t;
                float tri = 1f - 4f * Math.abs((ph - (float) Math.floor(ph)) - 0.5f);
                b[i] += (tri * 0.6f + (float) Math.sin(TAU * f * 2f * t) * 0.25f) * env * gain;
            }
        }
        return b;
    }

    static float[] power() {
        float[] b = buf(0.4f);
        float ph = 0f, lp = 0f;
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float f = 300f + 1500f * t / 0.4f;
            ph += f / SR;
            float sq = (ph - (float) Math.floor(ph)) < 0.5f ? 1f : -1f;
            lp += 0.15f * (sq - lp);
            b[i] = lp * 0.35f * (1f - t / 0.4f) * Math.min(1f, t * 200f);
        }
        return b;
    }

    static float[] whoosh() {
        float[] b = buf(0.3f);
        float lp = 0f;
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float a = 0.05f + 0.4f * (t / 0.3f);
            lp += a * (noise() - lp);
            float env = (float) Math.sin(Math.PI * t / 0.3f);
            b[i] = lp * env * 0.5f;
        }
        return b;
    }

    static float[] shatter() {
        float[] b = buf(0.5f);
        float lp = 0f;
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float nz = noise();
            lp += 0.5f * (nz - lp);
            float hp = nz - lp;
            b[i] = (hp * 0.5f + ((float) Math.sin(TAU * 2400f * t) + (float) Math.sin(TAU * 3170f * t)) * 0.18f)
                    * (float) Math.exp(-t * 9f) * Math.min(1f, t * 800f);
        }
        return b;
    }

    static float[] beep(float freq, float len) {
        float[] b = buf(len);
        for (int i = 0; i < b.length; i++) {
            float t = i / (float) SR;
            float env = Math.min(1f, t * 300f) * Math.min(1f, (len - t) * 40f);
            b[i] = ((float) Math.sin(TAU * freq * t) * 0.7f + (float) Math.sin(TAU * freq * 2f * t) * 0.15f) * env * 0.4f;
        }
        return b;
    }

    /** Fichier WAV PCM 16 bits mono. */
    static byte[] wav(float[] data) {
        short[] pcm = toPcm(data, 1f);
        int len = pcm.length * 2;
        byte[] b = new byte[44 + len];
        putStr(b, 0, "RIFF"); putInt(b, 4, 36 + len); putStr(b, 8, "WAVE");
        putStr(b, 12, "fmt "); putInt(b, 16, 16); putShort(b, 20, 1); putShort(b, 22, 1);
        putInt(b, 24, SR); putInt(b, 28, SR * 2); putShort(b, 32, 2); putShort(b, 34, 16);
        putStr(b, 36, "data"); putInt(b, 40, len);
        for (int i = 0; i < pcm.length; i++) {
            b[44 + i * 2] = (byte) (pcm[i] & 0xFF);
            b[45 + i * 2] = (byte) ((pcm[i] >> 8) & 0xFF);
        }
        return b;
    }

    private static void putStr(byte[] b, int o, String s) { for (int i = 0; i < 4; i++) b[o + i] = (byte) s.charAt(i); }

    private static void putInt(byte[] b, int o, int v) {
        b[o] = (byte) v; b[o + 1] = (byte) (v >> 8); b[o + 2] = (byte) (v >> 16); b[o + 3] = (byte) (v >> 24);
    }

    private static void putShort(byte[] b, int o, int v) { b[o] = (byte) v; b[o + 1] = (byte) (v >> 8); }

    private Synth() {}
}
