// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

public record ApiPerformanceResponse(
        Long totalRequests,
        Double requestsPerSecond,
        Double averageLatencyMs,
        Double p95LatencyMs,
        /** 5xx responses since the backend started. */
        Long failedRequests,
        /** 4xx responses since the backend started (bad input, expired sessions, wrong passwords). */
        Long clientErrors,
        Double successRatePercent,
        Double errorRatePercent,
        List<EndpointStat> endpoints,
        List<Common.Breakdown> statusCodes,
        List<Common.Breakdown> requestsByClient,
        List<Common.ChartSeries> requestsOverTime,
        List<Common.ChartSeries> latencyOverTime,
        Instant generatedAt) {

    public record EndpointStat(String method, String uri, String client, long requests,
                               Double averageLatencyMs, Double errorRatePercent) {
    }
}
