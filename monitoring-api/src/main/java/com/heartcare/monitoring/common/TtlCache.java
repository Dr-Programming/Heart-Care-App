// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.common;

import com.heartcare.monitoring.config.SccProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

/**
 * Short-lived response cache. Several open dashboards (or several judges' tabs) polling every five
 * seconds then cost Prometheus one set of queries per TTL, not one per viewer, which keeps the
 * monitoring overhead out of the numbers being monitored.
 */
@Component
public class TtlCache {

    private record Entry(Object value, long expiresAt) {
    }

    private final Map<String, Entry> entries = new ConcurrentHashMap<>();
    private final long ttlMs;
    private final Clock clock;

    @Autowired
    public TtlCache(SccProperties properties) {
        this(properties.cacheTtlMs(), Clock.systemUTC());
    }

    TtlCache(long ttlMs, Clock clock) {
        this.ttlMs = ttlMs;
        this.clock = clock;
    }

    @SuppressWarnings("unchecked")
    public <T> T get(String key, Supplier<T> loader) {
        long now = clock.millis();
        Entry entry = entries.get(key);
        if (entry != null && entry.expiresAt() > now) {
            return (T) entry.value();
        }
        T value = loader.get();
        entries.put(key, new Entry(value, now + ttlMs));
        return value;
    }
}
