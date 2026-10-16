package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * Longer-range charts. Only named metrics and ranges are accepted, so a caller can never send
 * PromQL through this API.
 */
@Service
public class HistoryService {

    public static final Map<String, Duration> RANGES = Map.of(
            "15m", Duration.ofMinutes(15),
            "1h", Duration.ofHours(1),
            "6h", Duration.ofHours(6),
            "24h", Duration.ofHours(24),
            "7d", Duration.ofDays(7));

    private final Metrics metrics;
    private final HostReader host;
    private final TtlCache cache;
    private final Map<String, String> queries;

    public HistoryService(Metrics metrics, HostReader host, TtlCache cache, SccProperties properties) {
        this.metrics = metrics;
        this.host = host;
        this.cache = cache;
        String db = properties.databaseName();
        this.queries = Map.of(
                "rps", PromQueries.REQUESTS_PER_SECOND,
                "latency", PromQueries.AVG_LATENCY_MS,
                "p95", PromQueries.P95_LATENCY_MS,
                "errors", PromQueries.ERROR_RATE_PERCENT,
                "memory", PromQueries.HOST_MEMORY_PERCENT,
                "active_users", PromQueries.ACTIVE_USERS,
                "db_tps", PromQueries.pgTransactionsPerSecond(db),
                "db_connections", PromQueries.pgTotalConnections(db));
    }

    public List<ChartSeries> history(String metric, String range) {
        Duration duration = RANGES.get(range);
        if (duration == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown range: use one of " + RANGES.keySet());
        }
        String query = metric.equals("cpu") ? host.cpuExpression(host.hostAvailable()) : queries.get(metric);
        if (query == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown metric");
        }
        return cache.get("history:" + metric + ":" + range, () -> List.of(metrics.series(metric, query, duration)));
    }
}
