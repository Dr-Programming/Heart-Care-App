package com.heartcare.common.monitoring;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory monitoring state for the System Control Centre: a bounded timeline of anonymised
 * activity events, per-category activity counters, and an "active users" gauge. Kept separate
 * from the business audit tables on purpose: this measures system behaviour rather than
 * recording who did what, and it is lost on restart.
 */
@Component
public class ActivityRecorder {

    static final int CAPACITY = 200;
    static final Duration ACTIVE_WINDOW = Duration.ofMinutes(5);

    private final MeterRegistry registry;
    private final Clock clock;
    private final Deque<ActivityEvent> events = new ArrayDeque<>(CAPACITY);
    /** Key is role + user id; held only in memory and never exported. */
    private final Map<String, Seen> lastSeen = new ConcurrentHashMap<>();
    private final Map<String, Counter> counters = new ConcurrentHashMap<>();

    private record Seen(ClientType client, Instant at) {
    }

    @Autowired
    public ActivityRecorder(MeterRegistry registry) {
        this(registry, Clock.systemUTC());
    }

    ActivityRecorder(MeterRegistry registry, Clock clock) {
        this.registry = registry;
        this.clock = clock;
        for (ClientType client : List.of(ClientType.ADMIN, ClientType.RESEARCHER, ClientType.MOBILE)) {
            Gauge.builder("heartcare.active.users", this, r -> r.activeUsers(client))
                    .description("Distinct signed-in users seen in the last 5 minutes")
                    .tag("client", client.tag())
                    .register(registry);
        }
    }

    public void record(ClientType client, ActivityCategory category, int status, long durationMs) {
        ActivityEvent event = new ActivityEvent(clock.instant(), client.tag(), category.key(),
                category.label(), ActivityEvent.outcomeOf(status), durationMs);
        synchronized (events) {
            if (events.size() == CAPACITY) {
                events.removeLast();
            }
            events.addFirst(event);
        }
        counters.computeIfAbsent(client.tag() + "|" + category.key() + "|" + event.outcome(),
                k -> Counter.builder("heartcare.user.activities")
                        .description("Completed user activities by app and category")
                        .tag("client", client.tag())
                        .tag("category", category.key())
                        .tag("outcome", event.outcome())
                        .register(registry))
                .increment();
    }

    public void seen(String role, String userId) {
        lastSeen.put(role + ":" + userId, new Seen(ClientType.fromRole(role), clock.instant()));
    }

    /** Newest first. */
    public List<ActivityEvent> recent(int limit) {
        synchronized (events) {
            List<ActivityEvent> copy = new ArrayList<>(events);
            return copy.subList(0, Math.min(Math.max(limit, 0), copy.size()));
        }
    }

    int activeUsers(ClientType client) {
        Instant cutoff = clock.instant().minus(ACTIVE_WINDOW);
        lastSeen.values().removeIf(s -> s.at().isBefore(cutoff));
        return (int) lastSeen.values().stream().filter(s -> s.client() == client).count();
    }
}
