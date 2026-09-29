package com.heartcare.research.analytics;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.research.analytics.AnalyticsModels.AdherenceRequest;
import com.heartcare.research.analytics.AnalyticsModels.AdherenceResult;
import com.heartcare.research.analytics.AnalyticsModels.CohortPreview;
import com.heartcare.research.analytics.AnalyticsModels.CohortPreviewRequest;
import com.heartcare.research.analytics.AnalyticsModels.CorrelationRequest;
import com.heartcare.research.analytics.AnalyticsModels.CorrelationResult;
import com.heartcare.research.analytics.AnalyticsModels.DescribeRequest;
import com.heartcare.research.analytics.AnalyticsModels.DescribeResult;
import com.heartcare.research.analytics.AnalyticsModels.MetricView;
import com.heartcare.research.analytics.AnalyticsModels.RecordsPage;
import com.heartcare.research.analytics.AnalyticsModels.RecordsRequest;
import com.heartcare.research.analytics.AnalyticsModels.SaveCohortRequest;
import com.heartcare.research.analytics.AnalyticsModels.SavedCohort;
import com.heartcare.research.analytics.AnalyticsModels.SeverityRequest;
import com.heartcare.research.analytics.AnalyticsModels.SeverityResult;
import com.heartcare.research.analytics.AnalyticsModels.TrendRequest;
import com.heartcare.research.analytics.AnalyticsModels.TrendResult;
import com.heartcare.research.anon.ResearchScope;
import com.heartcare.research.audit.ResearchAudit;
import com.heartcare.research.auth.ResearchContext;
import com.heartcare.research.model.Dataset;
import com.heartcare.research.repository.ResearchCohortRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * The researcher-facing API. Every handler builds a {@link ResearchScope} from the context the
 * access guard resolved, so grant limits are applied by the services, never by the client.
 * Analyses and records accept {@code ?format=csv} when the grant allows export.
 */
@RestController
@RequestMapping("/api/v1/research")
public class ResearchController {

    private static final TypeReference<Map<String, Object>> MAP = new TypeReference<>() {
    };

    private final AnalyticsService analytics;
    private final RecordsService records;
    private final ResearchCohortRepository cohorts;
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public ResearchController(AnalyticsService analytics, RecordsService records, ResearchCohortRepository cohorts,
                              JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.analytics = analytics;
        this.records = records;
        this.cohorts = cohorts;
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    // ---- catalog ---------------------------------------------------------------------------

    public record CohortFields(List<String> ageBands, List<String> chdStages, List<String> comorbidities,
                               List<String> languages, List<String> medications) {
    }

    public record Catalog(String accessLevel, List<Dataset> datasets, boolean exportAllowed, LocalDate dataFrom,
                          LocalDate dataTo, OffsetDateTime expiresAt, int minGroupSize, List<MetricView> metrics,
                          CohortFields cohortFields) {
    }

    /** What this researcher can analyse, and the category values available for cohort filters. */
    @GetMapping("/catalog")
    public ApiResponse<Catalog> catalog(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx) {
        ResearchScope scope = ResearchScope.of(ctx);
        List<MetricView> metrics = MetricCatalog.all().stream()
                .filter(m -> scope.has(m.dataset())).map(MetricView::of).toList();
        boolean demo = scope.has(Dataset.DEMOGRAPHICS);
        CohortFields fields = new CohortFields(
                demo ? AgeBands.LABELS : List.of(),
                // Only values shared by at least k patients: a rare value in a pick-list would itself
                // tell the researcher that one identifiable patient has it.
                demo ? jdbc.queryForList("SELECT chd_stage FROM patient_profiles WHERE chd_stage IS NOT NULL "
                        + "GROUP BY chd_stage HAVING COUNT(*) >= ? ORDER BY 1", String.class, scope.k()) : List.of(),
                demo ? jdbc.queryForList("SELECT lower(c) FROM patient_profiles p, jsonb_array_elements_text(p.comorbidities) c "
                        + "GROUP BY lower(c) HAVING COUNT(DISTINCT p.user_id) >= ? ORDER BY 1", String.class, scope.k()) : List.of(),
                demo ? jdbc.queryForList("SELECT DISTINCT preferred_language FROM users WHERE role = 'PATIENT' ORDER BY 1", String.class) : List.of(),
                scope.has(Dataset.MEDICATIONS)
                        ? jdbc.queryForList("SELECT name FROM medications GROUP BY name HAVING COUNT(DISTINCT user_id) >= ? "
                                + "ORDER BY COUNT(*) DESC, name LIMIT 50", String.class, scope.k())
                        : List.of());
        return ApiResponse.ok(new Catalog(scope.level().name(), List.copyOf(scope.datasets()), scope.exportAllowed(),
                scope.grantFrom(), scope.grantTo(), ctx.grant().getExpiresAt(), scope.k(), metrics, fields));
    }

    // ---- cohorts ---------------------------------------------------------------------------

    @PostMapping("/cohorts/preview")
    public ApiResponse<CohortPreview> preview(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                              @Valid @RequestBody CohortPreviewRequest req) {
        ResearchAudit.params(req);
        return ApiResponse.ok(analytics.previewCohort(ResearchScope.of(ctx), req.definition(), req.from(), req.to()));
    }

    @GetMapping("/cohorts")
    public ApiResponse<List<SavedCohort>> listCohorts(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx) {
        return ApiResponse.ok(cohorts.forResearcher(ctx.researcher().getId()).stream().map(this::toSaved).toList());
    }

    @PostMapping("/cohorts")
    public ApiResponse<SavedCohort> saveCohort(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                               @Valid @RequestBody SaveCohortRequest req) {
        ResearchAudit.params(req);
        // Compiling it once refuses filters on datasets outside the grant before anything is stored.
        analytics.previewCohort(ResearchScope.of(ctx), req.definition(), null, null);
        UUID id = cohorts.insert(ctx.researcher().getId(), req.name().trim(), objectMapper.writeValueAsString(req.definition()));
        return ApiResponse.ok(cohorts.find(id, ctx.researcher().getId()).map(this::toSaved).orElseThrow(), "Cohort saved");
    }

    @DeleteMapping("/cohorts/{id}")
    public ApiResponse<Void> deleteCohort(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx, @PathVariable UUID id) {
        if (!cohorts.delete(id, ctx.researcher().getId())) {
            throw new ResourceNotFoundException("Cohort not found");
        }
        return ApiResponse.ok(null, "Cohort deleted");
    }

    private SavedCohort toSaved(ResearchCohortRepository.Row r) {
        return new SavedCohort(r.id().toString(), r.name(),
                objectMapper.readValue(r.definitionJson(), CohortDefinition.class), r.createdAt().toString());
    }

    // ---- analyses --------------------------------------------------------------------------

    @PostMapping("/analytics/describe")
    public ResponseEntity<?> describe(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                      @Valid @RequestBody DescribeRequest req,
                                      @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        ResearchScope scope = checkedScope(ctx, format);
        DescribeResult result = analytics.describe(scope, req);
        ResearchAudit.rows(result.groups().size() + result.histogram().size() + 1L);
        return respond(scope, format, "describe-" + req.metric(), result, () -> {
            List<Map<String, Object>> rows = new ArrayList<>();
            rows.add(section("statistics", "All", result.overall()));
            result.groups().forEach(g -> rows.add(section("statistics", g.group(), g.stats())));
            result.histogram().forEach(b -> rows.add(section("histogram", null, b)));
            return rows;
        });
    }

    @PostMapping("/analytics/trend")
    public ResponseEntity<?> trend(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                   @Valid @RequestBody TrendRequest req,
                                   @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        ResearchScope scope = checkedScope(ctx, format);
        TrendResult result = analytics.trend(scope, req);
        ResearchAudit.rows(result.series().stream().mapToLong(s -> s.points().size()).sum());
        return respond(scope, format, "trend-" + req.metric(), result, () -> {
            List<Map<String, Object>> rows = new ArrayList<>();
            result.series().forEach(s -> s.points().forEach(pt -> rows.add(section("cohort", s.label(), pt))));
            return rows;
        });
    }

    @PostMapping("/analytics/adherence-outcomes")
    public ResponseEntity<?> adherence(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                       @Valid @RequestBody AdherenceRequest req,
                                       @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        ResearchScope scope = checkedScope(ctx, format);
        AdherenceResult result = analytics.adherenceOutcomes(scope, req);
        ResearchAudit.rows(result.bands().size());
        return respond(scope, format, "adherence-outcomes", result,
                () -> result.bands().stream().map(this::toMap).toList());
    }

    @PostMapping("/analytics/correlation")
    public ResponseEntity<?> correlation(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                         @Valid @RequestBody CorrelationRequest req,
                                         @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        ResearchScope scope = checkedScope(ctx, format);
        CorrelationResult result = analytics.correlation(scope, req);
        ResearchAudit.rows(result.points() != null ? result.points().size() : 1);
        return respond(scope, format, "correlation", result, () -> {
            List<Map<String, Object>> rows = new ArrayList<>();
            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("section", "summary");
            summary.put("x", result.x().id());
            summary.put("y", result.y().id());
            summary.put("suppressed", result.suppressed());
            summary.put("patients", result.patients());
            summary.put("r", result.r());
            summary.put("ciLow", result.ciLow());
            summary.put("ciHigh", result.ciHigh());
            rows.add(summary);
            if (result.points() != null) {
                result.points().forEach(pt -> rows.add(section("point", null, pt)));
            }
            if (result.grid() != null) {
                for (int yi = 0; yi < result.grid().counts().size(); yi++) {
                    for (int xi = 0; xi < result.grid().counts().get(yi).size(); xi++) {
                        Map<String, Object> cell = new LinkedHashMap<>();
                        cell.put("section", "grid");
                        cell.put("xFrom", result.grid().xEdges().get(xi));
                        cell.put("xTo", result.grid().xEdges().get(xi + 1));
                        cell.put("yFrom", result.grid().yEdges().get(yi));
                        cell.put("yTo", result.grid().yEdges().get(yi + 1));
                        Long c = result.grid().counts().get(yi).get(xi);
                        cell.put("patients", c);
                        cell.put("suppressed", c == null);
                        rows.add(cell);
                    }
                }
            }
            return rows;
        });
    }

    @PostMapping("/analytics/severity")
    public ResponseEntity<?> severity(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                      @Valid @RequestBody SeverityRequest req,
                                      @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        ResearchScope scope = checkedScope(ctx, format);
        SeverityResult result = analytics.severity(scope, req);
        ResearchAudit.rows(result.buckets().size());
        return respond(scope, format, "symptom-severity", result,
                () -> result.buckets().stream().map(this::toMap).toList());
    }

    // ---- records ---------------------------------------------------------------------------

    @PostMapping("/records/{dataset}")
    public ResponseEntity<?> records(@RequestAttribute(ResearchContext.ATTR) ResearchContext ctx,
                                     @PathVariable String dataset,
                                     @Valid @RequestBody RecordsRequest req,
                                     @RequestParam(required = false) String format) {
        ResearchAudit.params(req);
        Dataset ds = parseDataset(dataset);
        ResearchScope scope = checkedScope(ctx, format);
        if (isCsv(format)) {
            RecordsPage all = records.all(scope, ds, req);
            ResearchAudit.rows(all.rows().size());
            return csv("records-" + ds.name().toLowerCase(Locale.ROOT), all.rows());
        }
        RecordsPage page = records.page(scope, ds, req);
        ResearchAudit.rows(page.rows().size());
        return ResponseEntity.ok(ApiResponse.ok(page));
    }

    // ---- helpers ---------------------------------------------------------------------------

    private ResponseEntity<?> respond(ResearchScope scope, String format, String name, Object result,
                                      java.util.function.Supplier<List<Map<String, Object>>> rows) {
        if (!isCsv(format)) {
            return ResponseEntity.ok(ApiResponse.ok(result));
        }
        return csv(name, rows.get());
    }

    /** The scope, with the export permission checked up front so a refused download runs no query. */
    private static ResearchScope checkedScope(ResearchContext ctx, String format) {
        ResearchScope scope = ResearchScope.of(ctx);
        if (isCsv(format)) {
            scope.requireExport();
        }
        return scope;
    }

    private static boolean isCsv(String format) {
        if (format == null || format.isBlank() || format.equalsIgnoreCase("json")) {
            return false;
        }
        if (format.equalsIgnoreCase("csv")) {
            return true;
        }
        throw new BadRequestException("format must be json or csv");
    }

    private ResponseEntity<byte[]> csv(String name, List<Map<String, Object>> rows) {
        StringWriter buffer = new StringWriter();
        try (PrintWriter out = new PrintWriter(buffer)) {
            Csv.writeRows(out, rows);
        }
        String filename = "libu-research-" + name.replaceAll("[^a-zA-Z0-9_-]", "_") + "-" + LocalDate.now() + ".csv";
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(buffer.toString().getBytes(StandardCharsets.UTF_8));
    }

    private Map<String, Object> section(String section, String label, Object value) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("section", section);
        if (label != null) {
            row.put("label", label);
        }
        row.putAll(toMap(value));
        return row;
    }

    private Map<String, Object> toMap(Object value) {
        return objectMapper.convertValue(value, MAP);
    }

    private static Dataset parseDataset(String s) {
        try {
            return Dataset.valueOf(s.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("dataset must be one of vitals, symptoms, activity, medications, demographics");
        }
    }
}
