// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.monitoring;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ActivityRecorderTest {

    private static final class MutableClock extends Clock {
        Instant now = Instant.parse("2026-10-15T12:00:00Z");

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
            return now;
        }
    }

    private final SimpleMeterRegistry registry = new SimpleMeterRegistry();
    private final MutableClock clock = new MutableClock();
    private final ActivityRecorder recorder = new ActivityRecorder(registry, clock);

    @Test
    void keepsNewestEventsUpToCapacity() {
        for (int i = 0; i < ActivityRecorder.CAPACITY + 25; i++) {
            recorder.record(ClientType.MOBILE, ActivityCategory.classify("POST", "/api/v1/sync"), 200, i);
        }

        assertThat(recorder.recent(1000)).hasSize(ActivityRecorder.CAPACITY);
        assertThat(recorder.recent(1).getFirst().durationMs()).isEqualTo(ActivityRecorder.CAPACITY + 24);
    }

    @Test
    void labelsComeFromTheRouteTemplateNotTheRawPath() {
        ActivityCategory category = ActivityCategory.classify("GET", "/api/v1/admin/users/{id}");
        recorder.record(ClientType.ADMIN, category, 404, 3);

        ActivityEvent event = recorder.recent(1).getFirst();
        assertThat(event.label()).isEqualTo("Admin accessed user management");
        assertThat(event.category()).isEqualTo("admin_users");
        assertThat(event.outcome()).isEqualTo("client_error");
        assertThat(event.label()).doesNotContain("{id}");
    }

    @Test
    void countsActivitiesWithLowCardinalityTags() {
        recorder.record(ClientType.RESEARCHER, ActivityCategory.classify("POST", "/api/v1/research/analytics/trend"), 200, 5);
        recorder.record(ClientType.RESEARCHER, ActivityCategory.classify("POST", "/api/v1/research/analytics/describe"), 200, 5);

        double count = registry.get("heartcare.user.activities")
                .tag("client", "researcher").tag("category", "research_analysis").tag("outcome", "success")
                .counter().count();
        assertThat(count).isEqualTo(2.0);
    }

    @Test
    void activeUsersExpireAfterTheWindow() {
        recorder.seen("PATIENT", UUID.randomUUID().toString());
        recorder.seen("PATIENT", UUID.randomUUID().toString());
        recorder.seen("ADMIN", UUID.randomUUID().toString());

        assertThat(gauge("mobile")).isEqualTo(2.0);
        assertThat(gauge("admin")).isEqualTo(1.0);

        clock.now = clock.now.plus(ActivityRecorder.ACTIVE_WINDOW).plus(Duration.ofSeconds(1));
        assertThat(gauge("mobile")).isZero();
    }

    private double gauge(String client) {
        return registry.get("heartcare.active.users").tag("client", client).gauge().value();
    }
}
