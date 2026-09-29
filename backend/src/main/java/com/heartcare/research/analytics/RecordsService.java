package com.heartcare.research.analytics;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ForbiddenException;
import com.heartcare.research.analytics.AnalyticsModels.RecordsPage;
import com.heartcare.research.analytics.AnalyticsModels.RecordsRequest;
import com.heartcare.research.anon.Pseudonymizer;
import com.heartcare.research.anon.ResearchScope;
import com.heartcare.research.anon.ResearchScope.Window;
import com.heartcare.research.model.Dataset;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Row-level browsing for PSEUDONYMOUS grants. Each dataset has a hand-written projection that
 * lists exactly which columns leave the database: no names, phones, record ids, free-text notes
 * or times of day (dates only). Patient ids are replaced by researcher-specific pseudonyms here.
 */
@Service
@Transactional(readOnly = true)
public class RecordsService {

    public static final int EXPORT_LIMIT = 100_000;

    private record Projection(List<String> columns, String uid, String select, String from, String window, String order,
                              RowMapper mapper) {
    }

    @FunctionalInterface
    private interface RowMapper {
        void map(ResultSet rs, Map<String, Object> row) throws SQLException;
    }

    private static final TypeReference<Map<String, Object>> MAP = new TypeReference<>() {
    };

    private final NamedParameterJdbcTemplate jdbc;
    private final Pseudonymizer pseudonymizer;
    private final ObjectMapper objectMapper;
    private final AnalyticsService analytics;

    public RecordsService(NamedParameterJdbcTemplate jdbc, Pseudonymizer pseudonymizer, ObjectMapper objectMapper,
                          AnalyticsService analytics) {
        this.jdbc = jdbc;
        this.pseudonymizer = pseudonymizer;
        this.objectMapper = objectMapper;
        this.analytics = analytics;
    }

    public RecordsPage page(ResearchScope scope, Dataset dataset, RecordsRequest req) {
        int page = req.page() == null ? 0 : req.page();
        int size = req.size() == null ? 25 : req.size();
        return fetch(scope, dataset, req, page, size);
    }

    /** Everything matching, for CSV export, capped at {@link #EXPORT_LIMIT} rows. */
    public RecordsPage all(ResearchScope scope, Dataset dataset, RecordsRequest req) {
        return fetch(scope, dataset, req, 0, EXPORT_LIMIT);
    }

    private RecordsPage fetch(ResearchScope scope, Dataset dataset, RecordsRequest req, int page, int size) {
        scope.requirePseudonymous();
        scope.require(dataset);
        Window w = scope.window(req.from(), req.to());

        // Row-level data for a group smaller than k would let a researcher single people out.
        long cohortSize = analytics.cohortSize(scope, req.cohort(), w);
        if (cohortSize > 0 && cohortSize < scope.k()) {
            throw new ForbiddenException("COHORT_TOO_SMALL",
                    "This cohort has fewer than " + scope.k() + " patients, so its records can't be shown.");
        }

        Projection proj = projection(dataset);
        MapSqlParameterSource p = AnalyticsService.windowParams(w);
        String with = "WITH " + CohortSql.cte(req.cohort(), scope, p) + "\n";
        String where = proj.window() == null ? "" : " WHERE " + proj.window();

        Long total = jdbc.queryForObject(with + "SELECT COUNT(*) " + proj.from() + where, p, Long.class);
        p.addValue("limit", size).addValue("offset", (long) page * size);
        List<Map<String, Object>> rows = jdbc.query(
                with + "SELECT " + proj.uid() + " AS __uid, " + proj.select() + " " + proj.from() + where
                        + " ORDER BY " + proj.order() + " LIMIT :limit OFFSET :offset", p,
                (rs, i) -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("patient", pseudonymizer.of(scope.researcherId(), rs.getObject("__uid", UUID.class)));
                    proj.mapper().map(rs, row);
                    return row;
                });
        long totalElements = total == null ? 0 : total;
        return new RecordsPage(dataset, proj.columns(), rows, page, size, totalElements,
                (int) Math.ceil(totalElements / (double) size));
    }

    private Projection projection(Dataset dataset) {
        String tsWindow = "t.measured_at >= :wFrom AND t.measured_at < :wTo";
        String day = "CAST(t.measured_at AT TIME ZONE 'UTC' AS date) AS day";
        return switch (dataset) {
            case VITALS -> new Projection(
                    List.of("patient", "date", "type", "values", "outOfRange"), "t.user_id",
                    day + ", t.type, t.vital_values::text AS vals, t.flagged",
                    "FROM vitals_logs t JOIN cohort c ON c.user_id = t.user_id", tsWindow, "day DESC, t.id",
                    (rs, row) -> {
                        row.put("date", rs.getObject("day", LocalDate.class));
                        row.put("type", rs.getString("type"));
                        row.put("values", json(rs.getString("vals")));
                        row.put("outOfRange", rs.getBoolean("flagged"));
                    });
            case SYMPTOMS -> new Projection(
                    List.of("patient", "date", "severity", "reported", "assessment"), "t.user_id",
                    day + ", t.overall_severity, t.data::text AS data, t.assessment::text AS assessment",
                    "FROM symptom_logs t JOIN cohort c ON c.user_id = t.user_id", tsWindow, "day DESC, t.id",
                    (rs, row) -> {
                        row.put("date", rs.getObject("day", LocalDate.class));
                        row.put("severity", rs.getString("overall_severity"));
                        row.put("reported", json(rs.getString("data")));
                        row.put("assessment", json(rs.getString("assessment")));
                    });
            case ACTIVITY -> new Projection(
                    List.of("patient", "date", "activity"), "t.user_id",
                    day + ", t.data::text AS data",
                    "FROM activity_logs t JOIN cohort c ON c.user_id = t.user_id", tsWindow, "day DESC, t.id",
                    (rs, row) -> {
                        row.put("date", rs.getObject("day", LocalDate.class));
                        row.put("activity", json(rs.getString("data")));
                    });
            case MEDICATIONS -> new Projection(
                    List.of("patient", "date", "medication", "doseMg", "status"), "t.user_id",
                    "t.scheduled_date AS day, m.name, m.dose_mg, t.status",
                    "FROM dose_logs t JOIN cohort c ON c.user_id = t.user_id JOIN medications m ON m.id = t.medication_id",
                    "t.scheduled_date BETWEEN :dFrom AND :dTo", "day DESC, t.id",
                    (rs, row) -> {
                        row.put("date", rs.getObject("day", LocalDate.class));
                        row.put("medication", rs.getString("name"));
                        row.put("doseMg", rs.getBigDecimal("dose_mg"));
                        row.put("status", rs.getString("status"));
                    });
            case DEMOGRAPHICS -> new Projection(
                    List.of("patient", "ageBand", "chdStage", "comorbidities", "language", "heightCm"), "t.id",
                    "(" + AgeBands.SQL + ") AS age_band, p.chd_stage, p.comorbidities::text AS comorbidities, "
                            + "t.preferred_language, (ROUND(p.height_cm / 5.0) * 5)::int AS height",
                    "FROM users t JOIN cohort c ON c.user_id = t.id LEFT JOIN patient_profiles p ON p.user_id = t.id",
                    null, "age_band NULLS LAST, t.id",
                    (rs, row) -> {
                        row.put("ageBand", rs.getString("age_band"));
                        row.put("chdStage", rs.getString("chd_stage"));
                        String comorb = rs.getString("comorbidities");
                        row.put("comorbidities", comorb == null ? List.of() : objectMapper.readValue(comorb, List.class));
                        row.put("language", rs.getString("preferred_language"));
                        row.put("heightCm", rs.getObject("height"));
                    });
        };
    }

    private Map<String, Object> json(String s) {
        if (s == null) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(s, MAP);
        } catch (RuntimeException e) {
            throw new BadRequestException("Unreadable record");
        }
    }
}
