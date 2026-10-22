// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public record ActivityResponse(
        Common.SourceStatus source,
        List<Event> events,
        Map<String, Long> lastFiveMinutesByClient,
        Instant generatedAt) {

    /** Anonymised by the backend: no user id, raw path or payload ever reaches this API. */
    public record Event(Instant at, String client, String category, String label,
                       String outcome, long durationMs) {
    }
}
