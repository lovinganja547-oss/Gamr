package com.neonrush.app;

import android.content.Context;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;

/** Retour haptique avec niveau réglable (0 = off, 1 = faible, 2 = fort). */
final class Haptics {
    private final Vibrator vibrator;
    private final boolean amplitude;
    int level = 1;

    Haptics(Context ctx) {
        Vibrator v = null;
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager vm = (VibratorManager) ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                if (vm != null) v = vm.getDefaultVibrator();
            } else {
                v = (Vibrator) ctx.getSystemService(Context.VIBRATOR_SERVICE);
            }
        } catch (RuntimeException ignored) {
            v = null;
        }
        vibrator = (v != null && v.hasVibrator()) ? v : null;
        amplitude = vibrator != null && vibrator.hasAmplitudeControl();
    }

    /** strength dans [0,1]. */
    void pulse(int ms, float strength) {
        if (vibrator == null || level == 0) return;
        float s = strength * (level == 1 ? 0.45f : 1f);
        int dur = level == 1 ? Math.max(8, (int) (ms * 0.7f)) : ms;
        try {
            int amp = amplitude ? Math.max(1, Math.min(255, (int) (s * 255f))) : VibrationEffect.DEFAULT_AMPLITUDE;
            vibrator.vibrate(VibrationEffect.createOneShot(dur, amp));
        } catch (RuntimeException ignored) {
            // Certains appareils refusent les vibrations (mode économie) : on ignore.
        }
    }

    void tick() { pulse(12, 0.35f); }
}
