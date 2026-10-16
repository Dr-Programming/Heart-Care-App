package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

public record HealthResponse(String systemStatus, List<String> statusReasons, List<Source> sources,
                             Instant generatedAt) {

    /** @param required whether the source being down makes the system OFFLINE or DEGRADED */
    public record Source(String name, Common.SourceStatus status, boolean required, String detail) {
    }
}
