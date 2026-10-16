package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

/**
 * A demonstration run. {@code conditions} is what the operator says was configured (e.g. "30 JMeter
 * users for 10 minutes"); {@code baseline} and {@code summary} are what was actually measured.
 * They are kept apart so the report never presents a target as a measurement.
 */
public record DemoSession(
        String id,
        String label,
        String conditions,
        String state,
        Instant startedAt,
        Instant endedAt,
        Baseline baseline,
        Summary summary) {

    public record Baseline(Double cpuUsagePercent, Double memoryUsagePercent, Integer activeUsers,
                           Long totalRequests, Integer databaseConnections) {
    }

    public record Summary(
            long durationSeconds,
            Integer peakActiveUsers,
            Long totalRequests,
            Long successfulRequests,
            Long failedRequests,
            Long clientErrors,
            Double averageLatencyMs,
            Double p95LatencyMs,
            Double peakRequestsPerSecond,
            Double peakCpuPercent,
            String cpuSource,
            Double peakMemoryPercent,
            Integer peakDatabaseConnections,
            String result,
            List<String> notes,
            Instant computedAt) {
    }
}
