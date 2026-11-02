package com.neonrush.app;

/** Historique des positions du joueur (tampon circulaire, coordonnées monde). */
final class Trail {
    static final int N = 28;
    final float[] x = new float[N], y = new float[N];
    int head, count;

    void clear() { head = 0; count = 0; }

    void push(float px, float py) {
        head = (head + 1) % N;
        x[head] = px; y[head] = py;
        if (count < N) count++;
    }

    /** i = 0 : position la plus récente. */
    float x(int i) { return x[(head - i + N * 2) % N]; }

    float y(int i) { return y[(head - i + N * 2) % N]; }
}
