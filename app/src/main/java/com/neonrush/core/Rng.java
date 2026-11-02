package com.neonrush.core;

/** Générateur pseudo-aléatoire rapide et déterministe (xorshift64*). */
public final class Rng {
    private long s;

    public Rng(long seed) { setSeed(seed); }

    public void setSeed(long seed) {
        s = seed ^ 0x9E3779B97F4A7C15L;
        if (s == 0) s = 0x2545F4914F6CDD1DL;
        for (int i = 0; i < 4; i++) nextLong();
    }

    public long nextLong() {
        s ^= s >>> 12;
        s ^= s << 25;
        s ^= s >>> 27;
        return s * 0x2545F4914F6CDD1DL;
    }

    /** [0,1) */
    public float nextFloat() { return (nextLong() >>> 40) * 0x1.0p-24f; }

    public float range(float a, float b) { return a + (b - a) * nextFloat(); }

    /** [0,n) */
    public int nextInt(int n) { return (int) ((nextLong() >>> 33) % n); }

    public boolean chance(float p) { return nextFloat() < p; }

    public float sign() { return (nextLong() & 1L) == 0 ? 1f : -1f; }
}
