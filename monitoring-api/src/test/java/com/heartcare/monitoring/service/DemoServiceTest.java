// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.DemoSession;
import com.heartcare.monitoring.prometheus.PrometheusClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class DemoServiceTest {

    private static final class MutableClock extends Clock {
        Instant now = Instant.parse("2026-10-15T10:00:00Z");

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private final PrometheusClient prometheus = mock(PrometheusClient.class);
    private final MutableClock clock = new MutableClock();
    private DemoService demo;

    @BeforeEach
    void setUp() {
        SccProperties properties = new SccProperties("http://p", "http://b", "http://n", "heartcare",
                500, 0, new SccProperties.Admin("u", "p"), new SccProperties.Jwt("s", 1), Map.of());
        Metrics metrics = new Metrics(prometheus);
        HostReader host = new HostReader(metrics);
        demo = new DemoService(metrics, host, new TtlCache(properties), properties, clock);
        // Windows exporter down, everything else answers.
        when(prometheus.scalar(anyString())).thenAnswer(inv ->
                inv.getArgument(0).equals("up{job=\"windows\"}") ? 0.0 : 1.0);
    }

    @Test
    void stopComputesTheSummaryOverExactlyTheSessionWindow() {
        when(prometheus.scalar(argThat(q -> q != null && q.startsWith("sum(increase(") && !q.contains("status")), eq(Instant.parse("2026-10-15T10:10:00Z"))))
                .thenReturn(8450.4);
        when(prometheus.scalar(argThat(q -> q != null && q.contains("status=~\"5..\"")), any())).thenReturn(30.0);
        when(prometheus.scalar(argThat(q -> q != null && q.contains("status=~\"4..\"")), any())).thenReturn(20.0);
        when(prometheus.scalar(argThat(q -> q != null && q.contains("histogram_quantile")), any())).thenReturn(310.0);

        DemoSession started = demo.start("Judging", "30 JMeter users for 10 minutes");
        assertThat(started.state()).isEqualTo("RUNNING");

        clock.now = clock.now.plusSeconds(600);
        DemoSession done = demo.stop();

        assertThat(done.state()).isEqualTo("COMPLETED");
        assertThat(done.conditions()).isEqualTo("30 JMeter users for 10 minutes");
        DemoSession.Summary s = done.summary();
        assertThat(s.durationSeconds()).isEqualTo(600);
        assertThat(s.totalRequests()).isEqualTo(8450);
        assertThat(s.failedRequests()).isEqualTo(30);
        assertThat(s.clientErrors()).isEqualTo(20);
        assertThat(s.successfulRequests()).isEqualTo(8400);
        assertThat(s.p95LatencyMs()).isEqualTo(310.0);
        assertThat(s.result()).isEqualTo("COMPLETED_WITH_ERRORS");
        assertThat(s.cpuSource()).isEqualTo(HostReader.DOCKER_VM);
        assertThat(s.peakMemoryPercent()).isNull();
        assertThat(s.notes()).anyMatch(n -> n.contains("windows_exporter was not available"));
        assertThat(demo.sessions()).containsExactly(done);
        assertThat(demo.current()).isNull();
    }

    @Test
    void onlyOneSessionRunsAtATime() {
        demo.start(null, null);
        assertThatThrownBy(() -> demo.start("again", null))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("already running");
    }

    @Test
    void stopWithoutStartIsAConflict() {
        assertThatThrownBy(() -> demo.stop()).isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void prometheusOutageStillEndsTheSessionWithNoData() {
        demo.start("Outage", null);
        when(prometheus.scalar(anyString(), any())).thenThrow(new com.heartcare.monitoring.prometheus.PrometheusException("down", null));
        clock.now = clock.now.plusSeconds(60);

        DemoSession done = demo.stop();

        assertThat(done.state()).isEqualTo("COMPLETED");
        assertThat(done.summary().result()).isEqualTo("NO_DATA");
        assertThat(done.summary().totalRequests()).isNull();
    }

    @Test
    void runningSessionCarriesALiveSummary() {
        demo.start("Live", null);
        clock.now = clock.now.plusSeconds(30);

        DemoSession current = demo.current();

        assertThat(current.state()).isEqualTo("RUNNING");
        assertThat(current.summary().result()).isEqualTo("RUNNING");
        assertThat(current.summary().durationSeconds()).isEqualTo(30);
    }
}
