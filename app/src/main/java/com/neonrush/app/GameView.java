package com.neonrush.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Canvas;
import android.os.Build;
import android.util.Log;
import android.view.DisplayCutout;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.WindowInsets;

/** Surface de rendu + thread de jeu. Les entrées sont mises en file et traitées sur le thread de jeu. */
@SuppressLint("ViewConstructor")
final class GameView extends SurfaceView implements SurfaceHolder.Callback, Runnable {
    private static final String TAG = "NeonRush";
    private static final int QMAX = 128;

    private final Game game;
    private final Activity activity;
    private Thread thread;
    private volatile boolean running;
    private boolean surfaceReady, resumed;
    private volatile int surfW, surfH;
    private volatile float insetTop, insetBottom;

    private final Object qLock = new Object();
    private final int[] qAct = new int[QMAX];
    private final float[] qX = new float[QMAX], qY = new float[QMAX];
    private int qCount;
    private boolean backQueued;
    private int activePointer = -1;

    GameView(Activity activity, Game game) {
        super(activity);
        this.activity = activity;
        this.game = game;
        getHolder().addCallback(this);
        setFocusable(true);
        setKeepScreenOn(true);
    }

    @Override
    public WindowInsets onApplyWindowInsets(WindowInsets insets) {
        float top = 0f, bottom = 0f;
        if (Build.VERSION.SDK_INT >= 28) {
            DisplayCutout cut = insets.getDisplayCutout();
            if (cut != null) {
                top = cut.getSafeInsetTop();
                bottom = cut.getSafeInsetBottom();
            }
        }
        if (Build.VERSION.SDK_INT >= 30) {
            android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
            top = Math.max(top, bars.top);
            bottom = Math.max(bottom, bars.bottom);
        }
        insetTop = top;
        insetBottom = bottom;
        return super.onApplyWindowInsets(insets);
    }

    // ---- cycle de vie -------------------------------------------------------------------------

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                holder.getSurface().setFrameRate(60f, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT);
            } catch (RuntimeException ignored) { }
        }
        surfaceReady = true;
        startIfPossible();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        surfW = width;
        surfH = height;
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        surfaceReady = false;
        stopThread();
    }

    void onResume() {
        resumed = true;
        startIfPossible();
    }

    void onPause() {
        resumed = false;
        stopThread();
        // Thread de jeu arrêté : accès exclusif aux objets du jeu.
        game.onHostPause();
    }

    private void startIfPossible() {
        if (!surfaceReady || !resumed || thread != null) return;
        running = true;
        thread = new Thread(this, "NeonRush-Game");
        thread.setPriority(Thread.MAX_PRIORITY - 1);
        thread.start();
    }

    private void stopThread() {
        running = false;
        Thread t = thread;
        thread = null;
        if (t != null) {
            boolean interrupted = false;
            while (t.isAlive()) {
                try { t.join(); } catch (InterruptedException e) { interrupted = true; }
            }
            if (interrupted) Thread.currentThread().interrupt();
        }
    }

    // ---- entrées ------------------------------------------------------------------------------

    void queueBack() {
        synchronized (qLock) { backQueued = true; }
    }

    private void push(int act, float x, float y) {
        synchronized (qLock) {
            if (act == Screen.MOVE && qCount > 0 && qAct[qCount - 1] == Screen.MOVE) {
                qX[qCount - 1] = x; qY[qCount - 1] = y;
                return;
            }
            if (qCount >= QMAX) return;
            qAct[qCount] = act; qX[qCount] = x; qY[qCount] = y;
            qCount++;
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    @Override
    public boolean onTouchEvent(MotionEvent e) {
        int am = e.getActionMasked();
        switch (am) {
            case MotionEvent.ACTION_DOWN:
                activePointer = e.getPointerId(0);
                push(Screen.DOWN, e.getX(0), e.getY(0));
                break;
            case MotionEvent.ACTION_POINTER_DOWN:
                if (activePointer == -1) {
                    int idx = e.getActionIndex();
                    activePointer = e.getPointerId(idx);
                    push(Screen.DOWN, e.getX(idx), e.getY(idx));
                }
                break;
            case MotionEvent.ACTION_MOVE: {
                int idx = e.findPointerIndex(activePointer);
                if (idx >= 0) push(Screen.MOVE, e.getX(idx), e.getY(idx));
                break;
            }
            case MotionEvent.ACTION_POINTER_UP:
            case MotionEvent.ACTION_UP: {
                int idx = e.getActionIndex();
                if (e.getPointerId(idx) == activePointer) {
                    push(Screen.UP, e.getX(idx), e.getY(idx));
                    activePointer = -1;
                }
                break;
            }
            case MotionEvent.ACTION_CANCEL:
                if (activePointer != -1) push(Screen.CANCEL, 0f, 0f);
                activePointer = -1;
                break;
            default:
                break;
        }
        return true;
    }

    // ---- boucle -------------------------------------------------------------------------------

    private final int[] lAct = new int[QMAX];
    private final float[] lX = new float[QMAX], lY = new float[QMAX];

    @Override
    public void run() {
        final SurfaceHolder holder = getHolder();
        game.resize(surfW, surfH, insetTop, insetBottom);
        game.onHostResume();
        long last = System.nanoTime();
        while (running) {
            long now = System.nanoTime();
            float dt = (now - last) / 1e9f;
            if (dt < 0.006f) {
                try { Thread.sleep(2); } catch (InterruptedException e) { break; }
                continue;
            }
            last = now;
            if (dt > 0.05f) dt = 0.05f;

            game.resize(surfW, surfH, insetTop, insetBottom);
            if (!game.ready()) {
                try { Thread.sleep(16); } catch (InterruptedException e) { break; }
                continue;
            }

            int n;
            boolean back;
            synchronized (qLock) {
                n = qCount;
                System.arraycopy(qAct, 0, lAct, 0, n);
                System.arraycopy(qX, 0, lX, 0, n);
                System.arraycopy(qY, 0, lY, 0, n);
                qCount = 0;
                back = backQueued;
                backQueued = false;
            }
            for (int i = 0; i < n; i++) game.touch(lAct[i], lX[i], lY[i]);
            if (back && !game.back()) activity.runOnUiThread(activity::finish);

            game.update(dt);

            Canvas c = null;
            try {
                c = holder.lockHardwareCanvas();
            } catch (RuntimeException e) {
                Log.w(TAG, "lockHardwareCanvas", e);
            }
            if (c == null) {
                try { Thread.sleep(16); } catch (InterruptedException e) { break; }
                continue;
            }
            try {
                game.draw(c);
            } finally {
                try {
                    holder.unlockCanvasAndPost(c);
                } catch (RuntimeException e) {
                    Log.w(TAG, "unlockCanvasAndPost", e);
                }
            }
        }
    }
}
