package com.neonrush.core;

import java.util.HashMap;

/** Stockage en mémoire, utilisé pour les tests. */
public final class MemoryStore implements SaveStore {
    public final HashMap<String, Long> map = new HashMap<>();
    public int commits;

    @Override public long getLong(String key, long def) { Long v = map.get(key); return v == null ? def : v; }
    @Override public void putLong(String key, long value) { map.put(key, value); }
    @Override public void commit() { commits++; }
}
