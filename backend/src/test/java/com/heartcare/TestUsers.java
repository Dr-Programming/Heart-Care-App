package com.heartcare;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Hands out unique, well-formed Ethiopian phone numbers for test fixtures.
 *
 * <p>`users.phone` is UNIQUE and the Testcontainer database is shared by every test class in
 * the JVM, so fixtures cannot hard-code a number or derive one per class — either would
 * collide across classes and fail intermittently. A single JVM-wide sequence cannot.
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
