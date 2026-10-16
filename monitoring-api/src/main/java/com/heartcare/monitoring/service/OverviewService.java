package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.dto.OverviewResponse;
import com.heartcare.monitoring.prometheus.PromQueries;
import com.heartcare.monitoring.prometheus.PrometheusException;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class OverviewService {

    private final Metrics metrics;
    private final HostReader host;
    private final HealthService health;
    private final TtlCache cache;

    public OverviewService(Metrics metrics, HostReader host, HealthService health, TtlCache cache) {
        this.metrics = metrics;
        this.host = host;
        this.health = health;
        this.cache = cache;
    }

    public OverviewResponse overview() {
        return cache.get("overview", this::compute);
    }

    private OverviewResponse compute() {
        try {
            Double errorRate = metrics.value(PromQueries.ERROR_RATE_PERCENT);
            Double p95 = metrics.value(PromQueries.P95_LATENCY_MS);
            HealthService.Evaluation evaluation = health.evaluate(errorRate, p95);
            HostReader.Reading reading = host.read();

            Map<String, Integer> byClient = new LinkedHashMap<>();
            metrics.byLabel(PromQueries.ACTIVE_USERS_BY_CLIENT, "client")
                    .forEach((client, v) -> byClient.put(client, (int) Math.round(v)));

            return new OverviewResponse(
                    evaluation.status(),
                    evaluation.reasons(),
                    metrics.integer(PromQueries.ACTIVE_USERS),
                    byClient,
                    metrics.count(PromQueries.TOTAL_REQUESTS),
                    metrics.value(PromQueries.REQUESTS_PER_SECOND),
                    metrics.value(PromQueries.AVG_LATENCY_MS),
                    p95,
                    errorRate,
                    reading.cpuPercent(),
                    reading.cpuSource(),
                    reading.memoryPercent(),
                    evaluation.sources(),
                    Instant.now());
        } catch (PrometheusException ex) {
            HealthService.Evaluation evaluation = health.evaluate(null, null);
            return new OverviewResponse(evaluation.status(), evaluation.reasons(), null, Map.of(),
                    null, null, null, null, null, null, null, null, evaluation.sources(), Instant.now());
        }
    }
}
