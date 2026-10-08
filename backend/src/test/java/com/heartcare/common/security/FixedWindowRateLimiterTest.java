package com.heartcare.common.security;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class FixedWindowRateLimiterTest {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-10-01T08:00:00Z"));
    private final Clock clock = new Clock() {
        @Override
        public ZoneOffset getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now.get();
        }
    };

    private final FixedWindowRateLimiter limiter = new FixedWindowRateLimiter(3, Duration.ofMinutes(1), clock);

    @Test
    void allowsUpToTheLimitThenRefuses() {
        assertThat(limiter.tryAcquire("1.2.3.4")).isTrue();
        assertThat(limiter.tryAcquire("1.2.3.4")).isTrue();
        assertThat(limiter.tryAcquire("1.2.3.4")).isTrue();
        assertThat(limiter.tryAcquire("1.2.3.4")).isFalse();
    }

    @Test
    void keysAreCountedIndependently() {
        for (int i = 0; i < 3; i++) {
            limiter.tryAcquire("1.2.3.4");
        }
        assertThat(limiter.tryAcquire("1.2.3.4")).isFalse();
        assertThat(limiter.tryAcquire("5.6.7.8")).isTrue();
    }

    @Test
    void aNewWindowResetsTheCount() {
        for (int i = 0; i < 3; i++) {
            limiter.tryAcquire("1.2.3.4");
        }
        assertThat(limiter.tryAcquire("1.2.3.4")).isFalse();

        now.set(now.get().plus(Duration.ofMinutes(1)));
        assertThat(limiter.tryAcquire("1.2.3.4")).isTrue();
    }

    @Test
    void retryAfterIsTheTimeLeftInTheWindow() {
        limiter.tryAcquire("1.2.3.4");
        now.set(now.get().plusSeconds(20));
        assertThat(limiter.retryAfterSeconds("1.2.3.4")).isEqualTo(40);
    }
}
