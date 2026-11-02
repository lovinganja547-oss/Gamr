package com.neonrush.core;

/** Objet ramassable : cristal ou bonus. */
public final class Pickup {
    public static final int CRYSTAL = 0, SHIELD = 1, MAGNET = 2, DOUBLE = 3;
    public int kind;
    public float x, y;
    public boolean attracted;
    public float phase;

    void reset() { kind = CRYSTAL; x = y = 0f; attracted = false; phase = 0f; }
}
