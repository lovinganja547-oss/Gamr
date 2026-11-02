package com.neonrush.core;

import static org.junit.Assert.*;

import org.junit.Test;

public class GameplayTest {

    static final class Counter implements GameWorld.Listener {
        int crystals, power, near, shield, death;
        public void onCrystal(float x, float y, int c, int p) { crystals++; }
        public void onPowerUp(int k, float x, float y) { power++; }
        public void onNearMiss(float x, float y, int p) { near++; }
        public void onShieldBreak(float x, float y) { shield++; }
        public void onDeath(float x, float y) { death++; }
    }

    private static int[] simulate(long seed, float maxSeconds, boolean bot) {
        GameWorld w = new GameWorld();
        Counter c = new Counter();
        w.listener = c;
        w.reset(seed, 2166f);
        Bot b = new Bot();
        float dt = 1f / 60f;
        while (w.alive && w.runTime < maxSeconds) {
            if (bot) b.drive(w);
            w.update(dt);
            assertTrue("trop d'obstacles actifs", w.obstacles.size() < 200);
            assertTrue("trop de bonus actifs", w.pickups.size() < 300);
        }
        return new int[]{(int) w.runTime, w.score(), w.crystals, w.meters(), c.death, w.nearMisses, w.powerUps};
    }

    @Test
    public void idlePlayerDiesEventually() {
        int[] r = simulate(42, 300, false);
        assertEquals(1, r[4]);
    }

    @Test
    public void botSurvivesEarlyGameOnManySeeds() {
        int early = 0, total = 0;
        long sumT = 0;
        int minT = Integer.MAX_VALUE;
        StringBuilder sb = new StringBuilder();
        for (long seed = 1; seed <= 40; seed++) {
            int[] r = simulate(seed * 7919L, 240, true);
            total++;
            sumT += r[0];
            minT = Math.min(minT, r[0]);
            if (r[0] < 60) early++;
            sb.append(seed).append(':').append(r[0]).append("s/").append(r[1]).append("pts/").append(r[2]).append("c ");
        }
        System.out.println("BOT " + sb);
        System.out.println("BOT moyenne=" + (sumT / total) + "s min=" + minT + "s morts<60s=" + early);
        assertTrue("motifs injustes en début de partie : " + early, early <= 2);
    }

    @Test
    public void deterministicGeneration() {
        assertArrayEquals(simulate(99, 90, true), simulate(99, 90, true));
    }

    @Test
    public void collisionPrimitives() {
        assertEquals(0f, Obstacle.rectDist(5, 5, 0, 0, 10, 10), 1e-4);
        assertEquals(5f, Obstacle.rectDist(15, 5, 0, 0, 10, 10), 1e-4);
        assertEquals(5f, Obstacle.segDist(5, 5, 0, 0, 10, 0), 1e-4);
        Obstacle l = new Obstacle();
        l.reset();
        l.type = Obstacle.LASER; l.x = 0; l.y = 100; l.w = 500;
        l.offDur = 1; l.warnDur = 0.5f; l.onDur = 1;
        assertEquals(Obstacle.OFF, l.state(0.2f));
        assertEquals(Obstacle.WARN, l.state(1.2f));
        assertEquals(Obstacle.ON, l.state(2f));
        assertEquals(Float.MAX_VALUE, l.distance(100, 100, 0.2f), 0f);
        assertTrue(l.distance(100, 100, 2f) < 0f);
    }

    @Test
    public void shieldAbsorbsOneHit() {
        GameWorld w = new GameWorld();
        Counter c = new Counter();
        w.listener = c;
        w.reset(5, 2000f);
        w.obstacles.clear();
        w.pickups.clear();
        w.shield = true;
        Obstacle o = w.newObstacle(Obstacle.BAR);
        o.x = 0; o.y = 50; o.w = 1000; o.h = 40;
        for (int i = 0; i < 30 && w.alive; i++) w.update(1f / 60f);
        assertTrue(w.alive);
        assertEquals(1, c.shield);
    }
}
