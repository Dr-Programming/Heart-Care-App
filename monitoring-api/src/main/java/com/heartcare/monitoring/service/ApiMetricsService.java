package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.dto.ApiPerformanceResponse;
import com.heartcare.monitoring.dto.ApiPerformanceResponse.EndpointStat;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.prometheus.PromQueries;
import com.heartcare.monitoring.prometheus.PrometheusClient;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ApiMetricsService {

    static final Duration CHART_RANGE = Duration.ofMinutes(15);
    static final int MAX_ENDPOINTS = 25;

    private final Metrics metrics;
    private final TtlCache cache;

    public ApiMetricsService(Metrics metrics, TtlCache cache) {
        this.metrics = metrics;
        this.cache = cache;
    }

    public ApiPerformanceResponse apiPerformance() {
        return cache.get("api-performance", this::compute);
    }

    private ApiPerformanceResponse compute() {
        Long total = metrics.count(PromQueries.TOTAL_REQUESTS);
        Long failed = orZero(metrics.count(PromQueries.SERVER_ERRORS_TOTAL), total);
        Long clientErrors = orZero(metrics.count(PromQueries.CLIENT_ERRORS_TOTAL), total);
        Double errorRate = metrics.value(PromQueries.ERROR_RATE_PERCENT);

        List<ChartSeries> requests = new ArrayList<>();
        requests.add(metrics.series("total", PromQueries.REQUESTS_PER_SECOND, CHART_RANGE));
        requests.addAll(metrics.seriesByLabel(PromQueries.RPS_BY_CLIENT, "client", CHART_RANGE));

        List<ChartSeries> latency = List.of(
                metrics.series("average", PromQueries.AVG_LATENCY_MS, CHART_RANGE),
                metrics.series("p95", PromQueries.P95_LATENCY_MS, CHART_RANGE));

        return new ApiPerformanceResponse(
                total,
                metrics.value(PromQueries.REQUESTS_PER_SECOND),
                metrics.value(PromQueries.AVG_LATENCY_MS),
                metrics.value(PromQueries.P95_LATENCY_MS),
                failed,
                clientErrors,
                total == null || total == 0 ? null : 100.0 * (total - failed) / total,
                errorRate,
                endpoints(),
                metrics.breakdown(PromQueries.REQUESTS_BY_STATUS, "status"),
                metrics.breakdown(PromQueries.REQUESTS_BY_CLIENT, "client"),
                requests,
                latency,
                Instant.now());
    }

    /** Per-route totals since the backend started. Routes are templates, so ids never appear. */
    private List<EndpointStat> endpoints() {
        Map<String, Double> latencySums = new HashMap<>();
        for (PrometheusClient.Sample s : metrics.client().query(PromQueries.LATENCY_SUM_BY_ENDPOINT)) {
            latencySums.put(key(s), s.value());
        }
        Map<String, Double> errors = new HashMap<>();
        for (PrometheusClient.Sample s : metrics.client().query(PromQueries.ERRORS_BY_ENDPOINT)) {
            errors.put(key(s), s.value());
        }

        // The `client` label can split one route into several series; merge them per route.
        Map<String, double[]> counts = new HashMap<>();
        Map<String, PrometheusClient.Sample> firstSample = new HashMap<>();
        for (PrometheusClient.Sample s : metrics.client().query(PromQueries.REQUESTS_BY_ENDPOINT)) {
            counts.computeIfAbsent(key(s), k -> new double[1])[0] += s.value();
            firstSample.putIfAbsent(key(s), s);
        }

        List<EndpointStat> out = new ArrayList<>();
        counts.forEach((key, count) -> {
            PrometheusClient.Sample s = firstSample.get(key);
            double requests = count[0];
            Double sum = latencySums.get(key);
            out.add(new EndpointStat(
                    s.label("method"),
                    s.label("uri"),
                    s.label("client"),
                    Math.round(requests),
                    requests > 0 && sum != null ? sum / requests * 1000 : null,
                    requests > 0 ? 100.0 * errors.getOrDefault(key, 0.0) / requests : null));
        });
        out.sort(Comparator.comparingLong(EndpointStat::requests).reversed());
        return out.size() > MAX_ENDPOINTS ? out.subList(0, MAX_ENDPOINTS) : out;
    }

    private static String key(PrometheusClient.Sample s) {
        return s.label("method") + " " + s.label("uri");
    }

    /** An absent error series means no errors, but only once there is traffic at all. */
    private static Long orZero(Long value, Long total) {
        return value != null ? value : (total != null ? 0L : null);
    }
}
