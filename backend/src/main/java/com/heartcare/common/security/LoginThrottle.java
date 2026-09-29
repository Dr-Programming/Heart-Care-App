package com.heartcare.common.security;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Per-username lockout for the admin and researcher sign-ins, held in memory. One instance per
 * realm (see LoginThrottleConfig) so an admin and a researcher sharing a username never share a
 * counter.
 *
 * <p>Same policy as patient login (app.auth.lockout.*), but not stored in the database: these are
 * small operator populations, and a restart clearing the counters is acceptable. Keys are tracked
 * for any submitted username, including ones that do not exist, so a locked response never
 * reveals whether an account is real.
 */
public class LoginThrottle {

    private record State(int failures, Instant lockedUntil) {
    }

    private final ConcurrentHashMap<String, State> states = new ConcurrentHashMap<>();
    private final int maxAttempts;
    private final Duration lockout;
    private final Clock clock;

    public LoginThrottle(int maxAttempts, Duration lockout, Clock clock) {
        this.maxAttempts = maxAttempts;
        this.lockout = lockout;
        this.clock = clock;
    }

    /** When the username is currently locked, the instant the lock ends. */
    public Optional<Instant> lockedUntil(String username) {
        String key = key(username);
        State state = states.get(key);
        if (state == null || state.lockedUntil() == null) {
            return Optional.empty();
        }
        if (state.lockedUntil().isAfter(clock.instant())) {
            return Optional.of(state.lockedUntil());
        }
        // Lock elapsed: start a fresh streak rather than re-locking on the next single mistake.
        states.remove(key, state);
        return Optional.empty();
    }

    /** Records a failure; returns the lock end if this failure tripped the lock. */
    public Optional<Instant> recordFailure(String username) {
        Instant now = clock.instant();
        State updated = states.compute(key(username), (k, prev) -> {
            int failures = (prev == null ? 0 : prev.failures()) + 1;
            Instant until = failures >= maxAttempts ? now.plus(lockout) : null;
            return new State(failures, until);
        });
        return Optional.ofNullable(updated.lockedUntil());
    }

    public void recordSuccess(String username) {
        states.remove(key(username));
    }

    private static String key(String username) {
        return username.trim().toLowerCase(Locale.ROOT);
    }
}
