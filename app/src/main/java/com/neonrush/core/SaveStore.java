package com.neonrush.core;

/** Abstraction du stockage clé/valeur (SharedPreferences sur Android, mémoire en test). */
public interface SaveStore {
    long getLong(String key, long def);
    void putLong(String key, long value);
    void commit();
}
