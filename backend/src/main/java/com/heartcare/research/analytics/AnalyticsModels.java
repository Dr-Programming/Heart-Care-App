package com.heartcare.research.analytics;

import com.heartcare.research.model.Dataset;
import com.heartcare.symptoms.model.Severity;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * Request and response shapes for the research analytics API. Any figure describing fewer than
 * k patients is returned as {@code suppressed: true} with its values null.
 */
public final class AnalyticsModels {

    private AnalyticsModels() {
    }

    public enum Unit { READING, PATIENT }

    public enum GroupBy { NONE, AGE_BAND, CHD_STAGE, LANGUAGE }

    public enum Period { WEEK, MONTH }

    // ---- shared ----------------------------------------------------------------------------

    public record MetricView(String id, String label, String unit, Dataset dataset, String kind, String group) {
        static MetricView of(MetricCatalog.Metric m) {
            return new MetricView(m.id(), m.label(), m.unit(), m.dataset(), m.kind().name(), m.group());
        }
    }

    public record WindowView(LocalDate from, LocalDate to) {
    }

    public record NamedCohort(@Size(max = 60) String label, @Valid CohortDefinition definition) {
    }

    public record Stats(boolean suppressed, Long readings, Long patients, Double mean, Double sd,
                        Double p5, Double p25, Double median, Double p75, Double p95) {
        static Stats hidden() {
            return new Stats(true, null, null, null, null, null, null, null, null, null);
        }

        static Stats empty() {
            return new Stats(false, 0L, 0L, null, null, null, null, null, null, null);
        }
    }

    // ---- cohort ----------------------------------------------------------------------------

    public record CohortPreviewRequest(@Valid CohortDefinition definition, LocalDate from, LocalDate to) {
    }

    /** {@code size} is null when suppressed (between 1 and k-1 patients). */
    public record CohortPreview(Long size, boolean suppressed, int k) {
    }

    public record SaveCohortRequest(@NotBlank @Size(max = 120) String name, @NotNull @Valid CohortDefinition definition) {
    }

    public record SavedCohort(String id, String name, CohortDefinition definition, String createdAt) {
    }

    // ---- describe --------------------------------------------------------------------------

    public record DescribeRequest(
            @NotBlank String metric,
            @Valid CohortDefinition cohort,
            LocalDate from,
            LocalDate to,
            Unit unit,
            GroupBy groupBy,
            @Min(4) @Max(30) Integer bins) {
    }

    /**
     * Histogram bins span p5..p95; the first bin also holds everything below p5 and the last
     * everything above p95, so extreme individual values never get a bin of their own.
     */
    public record Bin(double lo, double hi, Long count, boolean suppressed) {
    }

    public record GroupStats(String group, Stats stats) {
    }

    public record DescribeResult(MetricView metric, Unit unit, WindowView window, Stats overall,
                                 List<Bin> histogram, GroupBy groupBy, List<GroupStats> groups, int k) {
    }

    // ---- trend -----------------------------------------------------------------------------

    public record TrendRequest(
            @NotBlank String metric,
            @NotNull Period period,
            LocalDate from,
            LocalDate to,
            @Size(max = 3) @Valid List<NamedCohort> cohorts) {
    }

    public record TrendPoint(LocalDate period, boolean suppressed, Double mean, Long readings, Long patients) {
    }

    public record TrendSeries(String label, List<TrendPoint> points) {
    }

    public record TrendResult(MetricView metric, Period period, WindowView window, List<TrendSeries> series, int k) {
    }

    // ---- outcomes --------------------------------------------------------------------------

    public record AdherenceRequest(@Valid CohortDefinition cohort, LocalDate from, LocalDate to) {
    }

    public record AdherenceBand(String band, boolean suppressed, Long patients, Double meanAdherence,
                                Long patientsWithBp, Double meanSystolic, Double meanDiastolic,
                                Double pctBpOutOfRange, Double pctUrgentCheckins) {
    }

    public record AdherenceResult(WindowView window, List<AdherenceBand> bands, boolean symptomsIncluded, int k) {
    }

    public record CorrelationRequest(@NotBlank String metricX, @NotBlank String metricY,
                                     @Valid CohortDefinition cohort, LocalDate from, LocalDate to) {
    }

    public record ScatterPoint(String patient, double x, double y) {
    }

    /** {@code counts[yi][xi]}; null entries are suppressed cells. */
    public record Grid(List<Double> xEdges, List<Double> yEdges, List<List<Long>> counts) {
    }

    public record CorrelationResult(MetricView x, MetricView y, WindowView window, boolean suppressed,
                                    Long patients, Double r, Double ciLow, Double ciHigh,
                                    List<ScatterPoint> points, Grid grid, int k) {
    }

    public record SeverityRequest(@NotNull Period period, @Valid CohortDefinition cohort, LocalDate from, LocalDate to) {
    }

    public record SeverityBucket(LocalDate period, boolean suppressed, Long patients, Long checkins,
                                 Map<Severity, Long> counts) {
    }

    public record SeverityResult(Period period, WindowView window, List<SeverityBucket> buckets, int k) {
    }

    // ---- records ---------------------------------------------------------------------------

    public record RecordsRequest(@Valid CohortDefinition cohort, LocalDate from, LocalDate to,
                                 @Min(0) Integer page, @Min(1) @Max(100) Integer size) {
    }

    public record RecordsPage(Dataset dataset, List<String> columns, List<Map<String, Object>> rows,
                              int page, int size, long totalElements, int totalPages) {
    }
}
