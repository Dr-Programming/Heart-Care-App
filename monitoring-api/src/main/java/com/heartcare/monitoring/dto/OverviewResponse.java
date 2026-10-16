package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public record OverviewResponse(
        String systemStatus,
        List<String> statusReasons,
        Integer activeUsers,
        Map<String, Integer> activeUsersByClient,
        Long totalRequests,
        Double requestsPerSecond,
        Double averageLatencyMs,
        Double p95LatencyMs,
        Double errorRatePercent,
        Double cpuUsagePercent,
        /** "windows-host" when windows_exporter answers, "docker-vm" when falling back. */
        String cpuSource,
        Double memoryUsagePercent,
        Map<String, Common.SourceStatus> sources,
        Instant generatedAt) {
}
