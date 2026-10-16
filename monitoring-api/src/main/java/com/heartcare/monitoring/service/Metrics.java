package com.heartcare.monitoring.service;

import com.heartcare.monitoring.dto.Common.Breakdown;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.dto.Common.TimePoint;
import com.heartcare.monitoring.prometheus.PrometheusClient;
import com.heartcare.monitoring.prometheus.PrometheusException;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Convenience reads on top of {@link PrometheusClient}, shared by the section services. */
@Component
public class Metrics {

    /** Chart resolution: roughly this many points per series whatever the range. */
    private static final int POINTS_PER_CHART = 90;

    private final PrometheusClient prometheus;

    public Metrics(PrometheusClient prometheus) {
        this.prometheus = prometheus;
    }

    public PrometheusClient client() {
        return prometheus;
    }

    public Double value(String promql) {
        return prometheus.scalar(promql);
    }

    public Long count(String promql) {
        Double v = prometheus.scalar(promql);
        return v == null ? null : Math.round(v);
    }

    public Integer integer(String promql) {
        Double v = prometheus.scalar(promql);
        return v == null ? null : (int) Math.round(v);
    }

    /** Value of a gauge like {@code up}: true only when it reads exactly 1. */
    public boolean isUp(String promql) {
        try {
            Double v = prometheus.scalar(promql);
            return v != null && v == 1.0;
        } catch (PrometheusException ex) {
            return false;
        }
    }

    /** Value of each series keyed by one label, e.g. requests by {@code status}. */
    public Map<String, Double> byLabel(String promql, String label) {
        Map<String, Double> out = new LinkedHashMap<>();
        for (PrometheusClient.Sample s : prometheus.query(promql)) {
            if (Double.isFinite(s.value())) {
                out.merge(s.label(label), s.value(), Double::sum);
            }
        }
        return out;
    }

    public List<Breakdown> breakdown(String promql, String label) {
        List<Breakdown> out = new ArrayList<>();
        byLabel(promql, label).forEach((k, v) -> out.add(new Breakdown(k.isEmpty() ? "unknown" : k, v)));
        out.sort(Comparator.comparingDouble(Breakdown::value).reversed());
        return out;
    }

    /** A single-line chart over the last {@code range}. */
    public ChartSeries series(String name, String promql, Duration range) {
        List<PrometheusClient.Series> result = range(promql, range);
        return new ChartSeries(name, result.isEmpty() ? List.of() : points(result.getFirst()));
    }

    /** One chart line per value of {@code label}. */
    public List<ChartSeries> seriesByLabel(String promql, String label, Duration range) {
        List<ChartSeries> out = new ArrayList<>();
        for (PrometheusClient.Series s : range(promql, range)) {
            String name = s.labels().getOrDefault(label, "");
            out.add(new ChartSeries(name.isEmpty() ? "unknown" : name, points(s)));
        }
        return out;
    }

    public static Duration step(Duration range) {
        return Duration.ofSeconds(Math.max(5, range.toSeconds() / POINTS_PER_CHART));
    }

    private List<PrometheusClient.Series> range(String promql, Duration range) {
        Instant end = Instant.now();
        return prometheus.queryRange(promql, end.minus(range), end, step(range));
    }

    private static List<TimePoint> points(PrometheusClient.Series series) {
        return series.points().stream().map(p -> new TimePoint(p.timestamp(), p.value())).toList();
    }

    /** Percentage helper that tolerates missing inputs. */
    public static Double percent(Number part, Number whole) {
        if (part == null || whole == null || whole.doubleValue() <= 0) {
            return null;
        }
        return 100.0 * part.doubleValue() / whole.doubleValue();
    }
}
