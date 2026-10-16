package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.DemoSession;
import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;

/**
 * Demonstration Mode. A session records a baseline at START; at STOP (and live while it runs) the
 * summary is computed by Prometheus over exactly the session's time window, so the report is
 * reproducible from stored metrics rather than from whatever the screen showed at the time.
 *
 * <p>Sessions are kept in memory only (exported as JSON by the dashboard). Prometheus remains
 * the store of the underlying measurements; the application database is never touched.
 */
@Service
public class DemoService {

    static final int MAX_SESSIONS = 20;
    static final String RUNNING = "RUNNING";
    static final String COMPLETED = "COMPLETED";

    private final Metrics metrics;
    private final HostReader host;
    private final TtlCache cache;
    private final Clock clock;
    private final String db;

    private DemoSession active;
    private final Deque<DemoSession> finished = new ArrayDeque<>();

    @Autowired
    public DemoService(Metrics metrics, HostReader host, TtlCache cache, SccProperties properties) {
        this(metrics, host, cache, properties, Clock.systemUTC());
    }

    DemoService(Metrics metrics, HostReader host, TtlCache cache, SccProperties properties, Clock clock) {
        this.metrics = metrics;
        this.host = host;
        this.cache = cache;
        this.clock = clock;
        this.db = properties.databaseName();
    }

    public synchronized DemoSession start(String label, String conditions) {
        if (active != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "A demonstration is already running");
        }
        HostReader.Reading reading = safe(host::read);
        DemoSession.Baseline baseline = new DemoSession.Baseline(
                reading == null ? null : reading.cpuPercent(),
                reading == null ? null : reading.memoryPercent(),
                safe(() -> metrics.integer(PromQueries.ACTIVE_USERS)),
                safe(() -> metrics.count(PromQueries.TOTAL_REQUESTS)),
                safe(() -> metrics.integer(PromQueries.pgTotalConnections(db))));
        active = new DemoSession(UUID.randomUUID().toString(), blankToDefault(label, "Demonstration"),
                conditions == null ? "" : conditions.trim(), RUNNING, clock.instant(), null, baseline, null);
        return active;
    }

    public synchronized DemoSession stop() {
        if (active == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "No demonstration is running");
        }
        Instant end = clock.instant();
        DemoSession done = new DemoSession(active.id(), active.label(), active.conditions(), COMPLETED,
                active.startedAt(), end, active.baseline(), summarise(active.startedAt(), end, true));
        active = null;
        finished.addFirst(done);
        while (finished.size() > MAX_SESSIONS) {
            finished.removeLast();
        }
        return done;
    }

    /** The running session with a live summary up to now, or null when none is running. */
    public DemoSession current() {
        DemoSession running;
        synchronized (this) {
            running = active;
        }
        if (running == null) {
            return null;
        }
        DemoSession.Summary live = cache.get("demo-live:" + running.id(),
                () -> summarise(running.startedAt(), clock.instant(), false));
        return new DemoSession(running.id(), running.label(), running.conditions(), RUNNING,
                running.startedAt(), null, running.baseline(), live);
    }

    public synchronized List<DemoSession> sessions() {
        return new ArrayList<>(finished);
    }

    public synchronized DemoSession get(String id) {
        if (active != null && active.id().equals(id)) {
            return current();
        }
        return finished.stream().filter(s -> s.id().equals(id)).findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such demonstration"));
    }

    DemoSession.Summary summarise(Instant start, Instant end, boolean finalResult) {
        Duration window = Duration.between(start, end);
        boolean hostUp = Boolean.TRUE.equals(safe(host::hostAvailable));

        Long total = safe(() -> round(metrics.client().scalar(PromQueries.windowRequests(window, null), end)));
        Long failed = zeroIfTraffic(safe(() -> round(metrics.client().scalar(PromQueries.windowRequests(window, "5.."), end))), total);
        Long clientErrors = zeroIfTraffic(safe(() -> round(metrics.client().scalar(PromQueries.windowRequests(window, "4.."), end))), total);
        Long successful = total == null ? null : Math.max(0, total - nz(failed) - nz(clientErrors));

        Double avg = safe(() -> metrics.client().scalar(PromQueries.windowAvgLatencyMs(window), end));
        Double p95 = safe(() -> metrics.client().scalar(PromQueries.windowP95LatencyMs(window), end));
        Double peakRps = safe(() -> metrics.client().scalar(PromQueries.windowPeak(PromQueries.RPS_30S, window, "5s"), end));
        Double peakCpu = safe(() -> metrics.client().scalar(
                PromQueries.windowPeak(host.cpuExpression(hostUp), window, "10s"), end));
        Double peakMemory = hostUp ? safe(() -> metrics.client().scalar(
                PromQueries.windowPeak(PromQueries.HOST_MEMORY_PERCENT, window, "10s"), end)) : null;
        Double peakUsers = safe(() -> metrics.client().scalar(
                PromQueries.windowPeak(PromQueries.ACTIVE_USERS, window, "5s"), end));
        Double peakDb = safe(() -> metrics.client().scalar(
                PromQueries.windowPeak(PromQueries.pgTotalConnections(db), window, "5s"), end));

        List<String> notes = new ArrayList<>();
        notes.add("Conditions are as entered by the operator; every other figure is measured.");
        notes.add("Request counts are computed by Prometheus from 5-second samples and can differ "
                + "slightly from a load tool's own totals.");
        notes.add("Peak active users counts distinct signed-in users seen within a rolling 5-minute "
                + "window, so it can exceed the number active at any single instant.");
        notes.add("Failed requests are server errors (5xx). Client errors (4xx: invalid input, wrong "
                + "password, expired session) are reported separately.");
        if (!hostUp) {
            notes.add("windows_exporter was not available: CPU is for the Docker VM, host memory is not reported.");
        }
        if (total == null) {
            notes.add("Prometheus returned no request data for this window.");
        }

        String result = !finalResult ? RUNNING
                : total == null ? "NO_DATA"
                : nz(failed) > 0 ? "COMPLETED_WITH_ERRORS" : COMPLETED;

        return new DemoSession.Summary(window.toSeconds(), peakUsers == null ? null : (int) Math.round(peakUsers),
                total, successful, failed, clientErrors, avg, p95, peakRps, peakCpu,
                hostUp ? HostReader.WINDOWS_HOST : HostReader.DOCKER_VM, peakMemory,
                peakDb == null ? null : (int) Math.round(peakDb), result, notes, clock.instant());
    }

    private static <T> T safe(Supplier<T> read) {
        return HealthService.safe(read);
    }

    private static Long round(Double v) {
        return v == null ? null : Math.round(v);
    }

    private static long nz(Long v) {
        return v == null ? 0 : v;
    }

    private static Long zeroIfTraffic(Long v, Long total) {
        return v != null ? v : (total != null ? 0L : null);
    }

    private static String blankToDefault(String v, String fallback) {
        return v == null || v.isBlank() ? fallback : v.trim();
    }
}
