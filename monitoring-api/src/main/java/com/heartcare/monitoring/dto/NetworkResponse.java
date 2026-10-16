package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

public record NetworkResponse(
        Ngrok ngrok,
        /** Admin + researcher web apps, served on the local network. */
        Double webRequestsPerSecond,
        /** The mobile app; arrives through ngrok when used off the LAN. */
        Double mobileRequestsPerSecond,
        Long mobileRequestsTotal,
        Long mobileFailedRequests,
        Long mobileClientErrors,
        Long webFailedRequests,
        Common.SourceStatus hostSource,
        Double hostReceiveBytesPerSec,
        Double hostTransmitBytesPerSec,
        List<Common.Breakdown> requestsByClient,
        List<Common.ChartSeries> requestsPerSecondByClient,
        List<Common.ChartSeries> hostTrafficOverTime,
        Instant generatedAt) {

    /**
     * @param status ONLINE (tunnel up), OFFLINE (agent running, no tunnel) or UNREACHABLE (no agent)
     */
    public record Ngrok(String status, String publicUrl, Long requestsThroughTunnel, String detail) {
    }
}
