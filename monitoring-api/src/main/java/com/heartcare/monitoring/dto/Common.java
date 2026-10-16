package com.heartcare.monitoring.dto;

import java.util.List;

/** Building blocks shared by the section DTOs. */
public final class Common {

    private Common() {
    }

    /** Whether the metrics source behind a section answered. UI shows "Not available" otherwise. */
    public enum SourceStatus { OK, UNAVAILABLE }

    /** One point of a time series; {@code value} is null where Prometheus had no sample. */
    public record TimePoint(long t, Double v) {
    }

    public record ChartSeries(String name, List<TimePoint> points) {
    }

    public record Breakdown(String name, double value) {
    }
}
