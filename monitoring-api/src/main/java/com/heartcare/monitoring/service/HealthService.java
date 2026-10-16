package com.heartcare.monitoring.service;

import com.heartcare.monitoring.dto.Common.SourceStatus;
import com.heartcare.monitoring.dto.HealthResponse;
import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Decides OPERATIONAL / DEGRADED / OFFLINE. Only the application itself counts: a missing
 * windows_exporter or cAdvisor hides some cards but does not make the Heart Care system degraded.
 */
@Service
public class HealthService {

    public static final String OPERATIONAL = "OPERATIONAL";
    public static final String DEGRADED = "DEGRADED";
    public static final String OFFLINE = "OFFLINE";

    static final double ERROR_RATE_DEGRADED_PERCENT = 5.0;
    static final double P95_DEGRADED_MS = 2000.0;

    public record Evaluation(String status, List<String> reasons, Map<String, SourceStatus> sources) {
    }

    private final Metrics metrics;
    private final HostReader host;
    private final NetworkService network;

    public HealthService(Metrics metrics, HostReader host, NetworkService network) {
        this.metrics = metrics;
        this.host = host;
        this.network = network;
    }

    public Evaluation evaluate(Double errorRatePercent, Double p95LatencyMs) {
        Map<String, SourceStatus> sources = new LinkedHashMap<>();
        List<String> reasons = new ArrayList<>();

        boolean prometheus = metrics.client().reachable();
        sources.put("prometheus", status(prometheus));
        if (!prometheus) {
            reasons.add("Metrics store (Prometheus) is unreachable");
            return new Evaluation(OFFLINE, reasons, sources);
        }

        boolean backend = metrics.isUp(PromQueries.BACKEND_UP);
        boolean database = metrics.isUp(PromQueries.PG_UP);
        sources.put("backend", status(backend));
        sources.put("database", status(database));
        sources.put("host", status(host.hostAvailable()));
        Integer containers = safe(() -> metrics.integer(PromQueries.CONTAINERS_REPORTING));
        sources.put("containers", status(containers != null && containers > 0));

        if (!backend) {
            reasons.add("Backend API is not responding");
            return new Evaluation(OFFLINE, reasons, sources);
        }
        if (!database) {
            reasons.add("Database is unreachable");
        }
        if (errorRatePercent != null && errorRatePercent > ERROR_RATE_DEGRADED_PERCENT) {
            reasons.add(String.format("Server error rate %.1f%% (above %.0f%%)", errorRatePercent, ERROR_RATE_DEGRADED_PERCENT));
        }
        if (p95LatencyMs != null && p95LatencyMs > P95_DEGRADED_MS) {
            reasons.add(String.format("P95 latency %.0f ms (above %.0f ms)", p95LatencyMs, P95_DEGRADED_MS));
        }
        return new Evaluation(reasons.isEmpty() ? OPERATIONAL : DEGRADED, reasons, sources);
    }

    public HealthResponse health() {
        Double errorRate = safe(() -> metrics.value(PromQueries.ERROR_RATE_PERCENT));
        Double p95 = safe(() -> metrics.value(PromQueries.P95_LATENCY_MS));
        Evaluation e = evaluate(errorRate, p95);

        List<HealthResponse.Source> sources = new ArrayList<>();
        e.sources().forEach((name, s) -> sources.add(new HealthResponse.Source(name, s,
                name.equals("prometheus") || name.equals("backend") || name.equals("database"),
                detail(name, s))));
        var ngrok = network.ngrok();
        sources.add(new HealthResponse.Source("ngrok",
                "ONLINE".equals(ngrok.status()) ? SourceStatus.OK : SourceStatus.UNAVAILABLE, false, ngrok.detail()));
        return new HealthResponse(e.status(), e.reasons(), sources, Instant.now());
    }

    private static String detail(String name, SourceStatus status) {
        if (status == SourceStatus.OK) {
            return "Reporting";
        }
        return switch (name) {
            case "host" -> "windows_exporter not reachable; install it on the host (monitoring/windows-exporter)";
            case "containers" -> "No per-container metrics (cAdvisor is opt-in); status comes from health checks";
            case "database" -> "postgres_exporter cannot reach PostgreSQL";
            default -> "Not reporting";
        };
    }

    static SourceStatus status(boolean ok) {
        return ok ? SourceStatus.OK : SourceStatus.UNAVAILABLE;
    }

    static <T> T safe(java.util.function.Supplier<T> read) {
        try {
            return read.get();
        } catch (RuntimeException ex) {
            return null;
        }
    }
}
