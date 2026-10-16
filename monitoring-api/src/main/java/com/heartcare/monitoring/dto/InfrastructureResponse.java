package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

public record InfrastructureResponse(
        Host host,
        Common.SourceStatus containerMetricsSource,
        List<Container> containers,
        List<Common.ChartSeries> cpuOverTime,
        List<Common.ChartSeries> memoryOverTime,
        List<Common.ChartSeries> networkOverTime,
        Instant generatedAt) {

    public record Host(Common.SourceStatus source, String cpuSource, Double cpuUsagePercent,
                       Double memoryUsagePercent, Double memoryUsedBytes, Double memoryTotalBytes,
                       Double diskUsagePercent, Double diskFreeBytes, Double diskTotalBytes,
                       Double networkReceiveBytesPerSec, Double networkTransmitBytesPerSec) {
    }

    /**
     * @param status       RUNNING, DOWN or UNKNOWN
     * @param statusSource how the status was determined: prometheus, probe, cadvisor or self
     */
    public record Container(String name, String displayName, String status, String statusSource,
                            Double cpuPercent, Double memoryBytes) {
    }
}
