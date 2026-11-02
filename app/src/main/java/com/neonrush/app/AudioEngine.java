package com.neonrush.app;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.media.SoundPool;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/** Musique en streaming (thread dédié, fondus) et effets via SoundPool. Tout est généré au démarrage. */
final class AudioEngine {
    static final int CRYSTAL = 0, CRASH = 1, CLICK = 2, BACK = 3, UNLOCK = 4, POWER = 5, NEAR = 6, SHIELD = 7,
            MISSION = 8, BEEP = 9, GO = 10, RECORD = 11, DENY = 12;
    private static final int SFX_COUNT = 13;
    static final int MUSIC_NONE = 0, MUSIC_MENU = 1, MUSIC_GAME = 2;
    private static final String TAG = "NeonRush";

    private final Context ctx;
    private SoundPool pool;
    private final int[] ids = new int[SFX_COUNT];
    private final boolean[] loaded = new boolean[SFX_COUNT];
    private final long[] lastPlay = new long[SFX_COUNT];

    private volatile short[] menuTrack, gameTrack;
    private volatile int wantedTrack = MUSIC_NONE;
    private volatile boolean musicOn = true, sfxOn = true, hostPaused, released;
    private volatile float duck = 1f;
    private Thread musicThread;
    private final Object lock = new Object();

    AudioEngine(Context ctx) {
        this.ctx = ctx.getApplicationContext();
        AudioAttributes attrs = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();
        pool = new SoundPool.Builder().setMaxStreams(8).setAudioAttributes(attrs).build();
        pool.setOnLoadCompleteListener((sp, sampleId, status) -> {
            if (status != 0) return;
            for (int i = 0; i < SFX_COUNT; i++) if (ids[i] == sampleId) loaded[i] = true;
        });
        Thread gen = new Thread(this::generate, "NeonRush-AudioGen");
        gen.setPriority(Thread.MIN_PRIORITY + 1);
        gen.start();
    }

    private void generate() {
        try {
            File dir = new File(ctx.getCacheDir(), "sfx");
            if (!dir.exists() && !dir.mkdirs()) Log.w(TAG, "cache sfx indisponible");
            float[][] fx = new float[SFX_COUNT][];
            fx[CRYSTAL] = Synth.crystal();
            fx[CRASH] = Synth.crash();
            fx[CLICK] = Synth.click(1250f);
            fx[BACK] = Synth.click(820f);
            fx[UNLOCK] = Synth.arpeggio(new int[]{72, 76, 79, 84, 88}, 0.07f, 6f, 0.4f);
            fx[POWER] = Synth.power();
            fx[NEAR] = Synth.whoosh();
            fx[SHIELD] = Synth.shatter();
            fx[MISSION] = Synth.arpeggio(new int[]{79, 84}, 0.11f, 5f, 0.45f);
            fx[BEEP] = Synth.beep(880f, 0.09f);
            fx[GO] = Synth.beep(1320f, 0.18f);
            fx[RECORD] = Synth.arpeggio(new int[]{72, 76, 79, 83, 84, 88, 91}, 0.06f, 5f, 0.35f);
            fx[DENY] = Synth.beep(220f, 0.12f);
            for (int i = 0; i < SFX_COUNT; i++) {
                if (released) return;
                File f = new File(dir, "s" + i + ".wav");
                try (FileOutputStream os = new FileOutputStream(f)) {
                    os.write(Synth.wav(fx[i]));
                }
                SoundPool p = pool;
                if (p != null) ids[i] = p.load(f.getAbsolutePath(), 1);
            }
            menuTrack = Synth.music(false);
            if (released) return;
            synchronized (lock) { lock.notifyAll(); }
            gameTrack = Synth.music(true);
            synchronized (lock) { lock.notifyAll(); }
        } catch (IOException | RuntimeException e) {
            Log.e(TAG, "génération audio", e);
        }
    }

    void start() {
        if (musicThread != null) return;
        musicThread = new Thread(this::musicLoop, "NeonRush-Music");
        musicThread.setPriority(Thread.MAX_PRIORITY);
        musicThread.start();
    }

    private void musicLoop() {
        final int sr = Synth.SR;
        int min = AudioTrack.getMinBufferSize(sr, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
        if (min <= 0) min = 4096;
        AudioTrack track;
        try {
            track = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    .setAudioFormat(new AudioFormat.Builder()
                            .setSampleRate(sr)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                    .setBufferSizeInBytes(Math.max(min * 2, 8192))
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build();
        } catch (RuntimeException e) {
            Log.e(TAG, "AudioTrack", e);
            return;
        }
        final short[] chunk = new short[1024];
        short[] cur = null;
        int curId = MUSIC_NONE, pos = 0;
        float gain = 0f, vol = 1f;
        boolean playing = false;
        try {
            while (!released) {
                int want = (musicOn && !hostPaused) ? wantedTrack : MUSIC_NONE;
                short[] wantBuf = want == MUSIC_MENU ? menuTrack : (want == MUSIC_GAME ? gameTrack : null);
                if (wantBuf == null && cur == null) {
                    if (playing) { track.pause(); track.flush(); playing = false; }
                    synchronized (lock) {
                        try { lock.wait(250); } catch (InterruptedException e) { return; }
                    }
                    continue;
                }
                if (!playing) { track.play(); playing = true; }
                boolean switching = wantBuf != cur;
                float targetVol = duck;
                for (int i = 0; i < chunk.length; i++) {
                    if (switching) {
                        gain -= 1f / (0.35f * sr);
                        if (gain <= 0f) {
                            gain = 0f;
                            cur = wantBuf;
                            curId = want;
                            pos = 0;
                            switching = false;
                        }
                    } else if (gain < 1f) {
                        gain = Math.min(1f, gain + 1f / (0.6f * sr));
                    }
                    vol += (targetVol - vol) * 0.0005f;
                    short[] b = cur;
                    if (b == null) { chunk[i] = 0; continue; }
                    chunk[i] = (short) (b[pos] * gain * vol * 0.75f);
                    if (++pos >= b.length) pos = 0;
                }
                if (curId == MUSIC_NONE && cur == null) gain = 0f;
                track.write(chunk, 0, chunk.length);
            }
        } finally {
            try { track.stop(); } catch (RuntimeException ignored) { }
            track.release();
        }
    }

    void setMusic(int which) {
        wantedTrack = which;
        synchronized (lock) { lock.notifyAll(); }
    }

    void setMusicEnabled(boolean on) {
        musicOn = on;
        synchronized (lock) { lock.notifyAll(); }
    }

    void setSfxEnabled(boolean on) { sfxOn = on; }

    /** Atténuation (pause, fin de partie). */
    void setDuck(float v) { duck = v; }

    void play(int id) { play(id, 1f, 1f); }

    void play(int id, float volume, float rate) {
        if (!sfxOn || hostPaused || id < 0 || id >= SFX_COUNT || !loaded[id]) return;
        long now = System.nanoTime();
        if (now - lastPlay[id] < 35_000_000L) return; // anti-saturation
        lastPlay[id] = now;
        SoundPool p = pool;
        if (p != null) p.play(ids[id], volume, volume, 1, 0, Math.max(0.5f, Math.min(2f, rate)));
    }

    void onHostPause() {
        hostPaused = true;
        SoundPool p = pool;
        if (p != null) p.autoPause();
        synchronized (lock) { lock.notifyAll(); }
    }

    void onHostResume() {
        hostPaused = false;
        SoundPool p = pool;
        if (p != null) p.autoResume();
        synchronized (lock) { lock.notifyAll(); }
    }

    void release() {
        released = true;
        synchronized (lock) { lock.notifyAll(); }
        if (musicThread != null) {
            try { musicThread.join(500); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
            musicThread = null;
        }
        SoundPool p = pool;
        pool = null;
        if (p != null) p.release();
    }
}
