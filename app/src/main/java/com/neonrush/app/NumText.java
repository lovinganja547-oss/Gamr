package com.neonrush.app;

/** Formatage d'entiers sans allocation (séparateur de milliers à la française). */
final class NumText {
    final char[] buf = new char[24];
    int start, len;
    private long value = Long.MIN_VALUE;
    private final String prefix, suffix;

    NumText() { this("", ""); }

    NumText(String prefix, String suffix) { this.prefix = prefix; this.suffix = suffix; }

    NumText set(long v) {
        if (v == value) return this;
        value = v;
        int p = buf.length;
        for (int i = suffix.length() - 1; i >= 0; i--) buf[--p] = suffix.charAt(i);
        boolean neg = v < 0;
        long a = Math.abs(v);
        int digits = 0;
        do {
            if (digits > 0 && digits % 3 == 0) buf[--p] = ' ';
            buf[--p] = (char) ('0' + (a % 10));
            a /= 10;
            digits++;
        } while (a > 0 && p > prefix.length() + 2);
        if (neg) buf[--p] = '-';
        for (int i = prefix.length() - 1; i >= 0; i--) buf[--p] = prefix.charAt(i);
        start = p;
        len = buf.length - p;
        return this;
    }

    @Override public String toString() { return new String(buf, start, len); }
}
