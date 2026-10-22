// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.prometheus;

import com.heartcare.monitoring.config.SccProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.databind.JsonNode;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Thin client for the Prometheus HTTP API ({@code /api/v1/query}, {@code /api/v1/query_range}).
 * Turns Prometheus's JSON into typed samples so nothing above this class deals with PromQL
 * response formats, and nothing in the dashboard deals with PromQL at all.
 */
@Component
public class PrometheusClient {

    public record Sample(Map<String, String> labels, double value) {
        public String label(String name) {
            return labels.getOrDefault(name, "");
        }
    }

    public record Point(long timestamp, Double value) {
    }

    public record Series(Map<String, String> labels, List<Point> points) {
    }

    private final RestClient http;
    private final String baseUrl;

    @Autowired
    public PrometheusClient(RestClient.Builder builder, SccProperties properties) {
        this(builder.build(), properties.prometheusUrl());
    }

    PrometheusClient(RestClient http, String baseUrl) {
        this.http = http;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    }

    /** Instant query evaluated now. */
    public List<Sample> query(String promql) {
        return parseVector(get("/api/v1/query", "query", promql));
    }

    /** Instant query evaluated at {@code time}. */
    public List<Sample> query(String promql, Instant time) {
        return parseVector(get("/api/v1/query", "query", promql, "time", seconds(time)));
    }

    public List<Series> queryRange(String promql, Instant start, Instant end, Duration step) {
        JsonNode data = get("/api/v1/query_range", "query", promql, "start", seconds(start),
                "end", seconds(end), "step", Math.max(1, step.toSeconds()) + "s");
        List<Series> out = new ArrayList<>();
        for (JsonNode series : data.path("result")) {
            List<Point> points = new ArrayList<>();
            for (JsonNode pair : series.path("values")) {
                points.add(new Point(Math.round(pair.get(0).asDouble() * 1000), finite(parseValue(pair.get(1)))));
            }
            out.add(new Series(labels(series.path("metric")), points));
        }
        return out;
    }

    /** First sample's value, or null when there is no data or the value is NaN or infinite. */
    public Double scalar(String promql) {
        List<Sample> samples = query(promql);
        return samples.isEmpty() ? null : finite(samples.getFirst().value());
    }

    public Double scalar(String promql, Instant time) {
        List<Sample> samples = query(promql, time);
        return samples.isEmpty() ? null : finite(samples.getFirst().value());
    }

    /** Liveness of Prometheus itself, for the health page. */
    public boolean reachable() {
        try {
            query("vector(1)");
            return true;
        } catch (PrometheusException ex) {
            return false;
        }
    }

    /**
     * PromQL is full of characters URI builders mishandle: {@code {...}} looks like a template
     * variable and a bare {@code +} decodes as a space. So every parameter is form-encoded here.
     */
    private JsonNode get(String path, String... params) {
        StringBuilder query = new StringBuilder();
        for (int i = 0; i < params.length; i += 2) {
            query.append(i == 0 ? '?' : '&')
                    .append(params[i]).append('=')
                    .append(URLEncoder.encode(params[i + 1], StandardCharsets.UTF_8));
        }
        URI target = URI.create(baseUrl + path + query);
        JsonNode body;
        try {
            body = http.get().uri(target).retrieve().body(JsonNode.class);
        } catch (RestClientException ex) {
            throw new PrometheusException("Prometheus request failed: " + ex.getMessage(), ex);
        }
        if (body == null || !"success".equals(body.path("status").asString())) {
            String error = body == null ? "empty response" : body.path("error").asString();
            throw new PrometheusException("Prometheus query failed: " + error, null);
        }
        return body.path("data");
    }

    private static List<Sample> parseVector(JsonNode data) {
        String type = data.path("resultType").asString();
        List<Sample> out = new ArrayList<>();
        if ("scalar".equals(type)) {
            out.add(new Sample(Map.of(), parseValue(data.path("result").get(1))));
            return out;
        }
        for (JsonNode sample : data.path("result")) {
            out.add(new Sample(labels(sample.path("metric")), parseValue(sample.path("value").get(1))));
        }
        return out;
    }

    private static Map<String, String> labels(JsonNode metric) {
        Map<String, String> labels = new LinkedHashMap<>();
        for (Map.Entry<String, JsonNode> e : metric.properties()) {
            labels.put(e.getKey(), e.getValue().asString());
        }
        return labels;
    }

    /** Prometheus encodes values as strings, including "NaN", "+Inf" and "-Inf". */
    static double parseValue(JsonNode node) {
        if (node == null) {
            return Double.NaN;
        }
        return switch (node.asString()) {
            case "+Inf", "Inf" -> Double.POSITIVE_INFINITY;
            case "-Inf" -> Double.NEGATIVE_INFINITY;
            case "NaN" -> Double.NaN;
            default -> {
                try {
                    yield Double.parseDouble(node.asString());
                } catch (NumberFormatException ex) {
                    yield Double.NaN;
                }
            }
        };
    }

    static Double finite(double value) {
        return Double.isFinite(value) ? value : null;
    }

    private static String seconds(Instant time) {
        return String.format(java.util.Locale.ROOT, "%.3f", time.toEpochMilli() / 1000.0);
    }
}
