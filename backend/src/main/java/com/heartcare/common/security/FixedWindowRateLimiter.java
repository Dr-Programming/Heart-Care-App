package com.heartcare.common.security;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory fixed-window counter: at most {@code maxRequests} per key per window, the window
 * starting at the key's first request. Held in one JVM, so it is per instance and resets on
 * restart; that is enough to stop a script hammering an unauthenticated endpoint, which is all
 * it is for (T-SEC-05).
 */
public class FixedWindowRateLimiter {

    /** Above this many tracked keys, expired windows are swept before a new key is added. */
    private static final int SWEEP_THRESHOLD = 10_000;

    private record Window(Instant start, int count) {
    }

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxRequests;
    private final Duration window;
    private final Clock clock;

    public FixedWindowRateLimiter(int maxRequests, Duration window, Clock clock) {
        if (maxRequests < 1) {
            throw new IllegalArgumentException("maxRequests must be at least 1, but was " + maxRequests);
        }
        if (window.isZero() || window.isNegative()) {
            throw new IllegalArgumentException("window must be positive, but was " + window);
        }
        this.maxRequests = maxRequests;
        this.window = window;
        this.clock = clock;
    }

    /** Counts one request for {@code key}; false when the key is over its limit for this window. */
    public boolean tryAcquire(String key) {
        Instant now = clock.instant();
        if (windows.size() > SWEEP_THRESHOLD) {
            windows.values().removeIf(w -> expired(w, now));
        }
        Window updated = windows.compute(key, (k, prev) ->
                prev == null || expired(prev, now) ? new Window(now, 1) : new Window(prev.start(), prev.count() + 1));
        return updated.count() <= maxRequests;
    }

    /** Whole seconds until {@code key}'s current window ends (at least 1). */
    public long retryAfterSeconds(String key) {
        Window w = windows.get(key);
        if (w == null) {
            return 1;
        }
        long remainingMs = Duration.between(clock.instant(), w.start().plus(window)).toMillis();
        return Math.max(1, (remainingMs + 999) / 1000);
    }

    private boolean expired(Window w, Instant now) {
        return !now.isBefore(w.start().plus(window));
    }
}
