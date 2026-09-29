package com.heartcare.research.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Append-only access log for researchers. There is intentionally no update or delete here: the
 * log is the record of who looked at what, and nothing in the application may rewrite it.
 */
@Repository
public class ResearchAuditRepository {

    public record Entry(UUID researcherId, String usernameAttempted, String method, String path,
                        String paramsJson, int status, Integer rowsReturned, int durationMs,
                        String ip, String userAgent) {
    }

    public record Row(long id, UUID researcherId, String researcherUsername, String researcherStatus, String usernameAttempted,
                      OffsetDateTime occurredAt, String method, String path, String paramsJson,
                      int status, Integer rowsReturned, int durationMs, String ip, String userAgent) {
    }

    public record Filter(UUID researcherId, String pathContains, LocalDate from, LocalDate to, Boolean failuresOnly) {
    }

    private final NamedParameterJdbcTemplate jdbc;

    public ResearchAuditRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(Entry e) {
        jdbc.update("""
                INSERT INTO research_audit_log
                    (researcher_id, username_attempted, method, path, params, status, rows_returned, duration_ms, ip, user_agent)
                VALUES (:rid, :user, :method, :path, CAST(:params AS jsonb), :status, :rows, :duration, :ip, :ua)
                """, new MapSqlParameterSource()
                .addValue("rid", e.researcherId())
                .addValue("user", truncate(e.usernameAttempted(), 64))
                .addValue("method", e.method())
                .addValue("path", truncate(e.path(), 255))
                .addValue("params", e.paramsJson())
                .addValue("status", e.status())
                .addValue("rows", e.rowsReturned())
                .addValue("duration", e.durationMs())
                .addValue("ip", truncate(e.ip(), 64))
                .addValue("ua", truncate(e.userAgent(), 255)));
    }

    public List<Row> page(Filter f, int page, int size) {
        MapSqlParameterSource p = params(f).addValue("limit", size).addValue("offset", (long) page * size);
        return jdbc.query("""
                SELECT a.id, a.researcher_id, r.username, r.status AS researcher_status, a.username_attempted, a.occurred_at, a.method, a.path,
                       a.params::text AS params, a.status, a.rows_returned, a.duration_ms, a.ip, a.user_agent
                  FROM research_audit_log a
                  LEFT JOIN researchers r ON r.id = a.researcher_id
                """ + where(f) + " ORDER BY a.occurred_at DESC, a.id DESC LIMIT :limit OFFSET :offset", p,
                (rs, i) -> new Row(
                        rs.getLong("id"),
                        rs.getObject("researcher_id", UUID.class),
                        rs.getString("username"),
                        rs.getString("researcher_status"),
                        rs.getString("username_attempted"),
                        rs.getObject("occurred_at", OffsetDateTime.class),
                        rs.getString("method"),
                        rs.getString("path"),
                        rs.getString("params"),
                        rs.getInt("status"),
                        (Integer) rs.getObject("rows_returned"),
                        rs.getInt("duration_ms"),
                        rs.getString("ip"),
                        rs.getString("user_agent")));
    }

    public long count(Filter f) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM research_audit_log a" + where(f), params(f), Long.class);
        return n == null ? 0 : n;
    }

    private static String where(Filter f) {
        List<String> clauses = new ArrayList<>();
        if (f.researcherId() != null) clauses.add("a.researcher_id = :rid");
        if (f.pathContains() != null && !f.pathContains().isBlank()) clauses.add("a.path ILIKE :path");
        if (f.from() != null) clauses.add("a.occurred_at >= :from");
        if (f.to() != null) clauses.add("a.occurred_at < :to");
        if (Boolean.TRUE.equals(f.failuresOnly())) clauses.add("a.status >= 400");
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses);
    }

    private static MapSqlParameterSource params(Filter f) {
        return new MapSqlParameterSource()
                .addValue("rid", f.researcherId())
                .addValue("path", f.pathContains() == null ? null : "%" + f.pathContains().trim() + "%")
                .addValue("from", f.from() == null ? null : Timestamp.from(f.from().atStartOfDay().toInstant(ZoneOffset.UTC)))
                .addValue("to", f.to() == null ? null : Timestamp.from(f.to().plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC)));
    }

    private static String truncate(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }
}
