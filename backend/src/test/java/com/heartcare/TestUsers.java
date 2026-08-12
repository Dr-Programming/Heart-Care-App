package com.heartcare;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Hands out unique, well-formed Ethiopian phone numbers for test fixtures.
 *
 * <p>`users.phone` is UNIQUE and the Testcontainer database is shared by every test class in
 * the JVM, so fixtures cannot hard-code a number or derive one per class — either would
 * collide across classes and fail intermittently. A single JVM-wide sequence cannot.
 *
 * <p><strong>This is only collision-free because the sequence and the database have the same
 * lifetime.</strong> Surefire runs at its defaults (one forked JVM, {@code reuseForks=true}) and
 * {@code AbstractIntegrationTest} starts a fresh container per JVM, so the fixed base below is
 * reset exactly when the data it guards is discarded. Enabling Testcontainers reuse, pointing the
 * suite at a persistent database, or raising {@code forkCount} against a shared container breaks
 * that pairing and reintroduces the collisions this class exists to prevent — seed the base from
 * {@link System#nanoTime()} if any of those change.
 */
public final class TestUsers {

    private static final AtomicLong SEQUENCE = new AtomicLong(910_000_000L);

    private TestUsers() {
    }

    /** e.g. {@code +251910000001} — matches the {@code ^\+251\d{9}$} contract. */
    public static String nextPhone() {
        return "+251" + SEQUENCE.incrementAndGet();
    }
}
