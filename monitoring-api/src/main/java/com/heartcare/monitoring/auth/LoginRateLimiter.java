package com.heartcare.monitoring.auth;

import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fixed-window limit on login attempts per client IP (same approach as the backend's
 * FixedWindowRateLimiter). In memory, per instance, reset on restart: enough to stop a script
 * guessing the SCC password from the LAN.
 */
@Component
public class LoginRateLimiter {

    static final int MAX_ATTEMPTS = 10;
    static final Duration WINDOW = Duration.ofMinutes(15);

    private record Window(Instant start, int count) {
    }

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final Clock clock;

    public LoginRateLimiter() {
        this(Clock.systemUTC());
    }

    LoginRateLimiter(Clock clock) {
        this.clock = clock;
    }

    public boolean tryAcquire(String key) {
        Instant now = clock.instant();
        if (windows.size() > 10_000) {
            windows.values().removeIf(w -> expired(w, now));
        }
        Window updated = windows.compute(key, (k, prev) ->
                prev == null || expired(prev, now) ? new Window(now, 1) : new Window(prev.start(), prev.count() + 1));
        return updated.count() <= MAX_ATTEMPTS;
    }

    public void reset(String key) {
        windows.remove(key);
    }

    private boolean expired(Window w, Instant now) {
        return !now.isBefore(w.start().plus(WINDOW));
    }
}
