package com.neonrush.app;

import android.content.Context;
import android.content.SharedPreferences;

import com.neonrush.core.SaveStore;

/** Sauvegarde locale via SharedPreferences. */
final class PrefsStore implements SaveStore {
    private final SharedPreferences prefs;
    private SharedPreferences.Editor editor;

    PrefsStore(Context ctx) {
        prefs = ctx.getSharedPreferences("neonrush_save", Context.MODE_PRIVATE);
    }

    @Override
    public long getLong(String key, long def) {
        try {
            return prefs.getLong(key, def);
        } catch (ClassCastException e) {
            return def;
        }
    }

    @Override
    public void putLong(String key, long value) {
        if (editor == null) editor = prefs.edit();
        editor.putLong(key, value);
    }

    @Override
    public void commit() {
        if (editor != null) {
            editor.apply();
            editor = null;
        }
    }
}
