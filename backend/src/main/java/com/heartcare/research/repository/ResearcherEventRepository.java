package com.heartcare.research.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** History of what admins did to each researcher account. Append-only. */
@Repository
public class ResearcherEventRepository {

    public enum Action { CREATED, GRANT_UPDATED, REVOKED, RESTORED, PASSWORD_RESET, ARCHIVED, UNARCHIVED }

    public record Row(long id, UUID researcherId, UUID adminId, String adminUsername, String action,
                      String detailsJson, OffsetDateTime occurredAt) {
    }

    private final NamedParameterJdbcTemplate jdbc;

    public ResearcherEventRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(UUID researcherId, UUID adminId, Action action, String detailsJson) {
        jdbc.update("""
                INSERT INTO researcher_admin_events (researcher_id, admin_id, action, details)
                VALUES (:rid, :aid, :action, CAST(:details AS jsonb))
                """, new MapSqlParameterSource()
                .addValue("rid", researcherId)
                .addValue("aid", adminId)
                .addValue("action", action.name())
                .addValue("details", detailsJson));
    }

    public List<Row> forResearcher(UUID researcherId) {
        return jdbc.query("""
                SELECT e.id, e.researcher_id, e.admin_id, a.username, e.action, e.details::text AS details, e.occurred_at
                  FROM researcher_admin_events e
                  LEFT JOIN admin_users a ON a.id = e.admin_id
                 WHERE e.researcher_id = :rid
                 ORDER BY e.occurred_at DESC, e.id DESC
                """, new MapSqlParameterSource("rid", researcherId),
                (rs, i) -> new Row(
                        rs.getLong("id"),
                        rs.getObject("researcher_id", UUID.class),
                        rs.getObject("admin_id", UUID.class),
                        rs.getString("username"),
                        rs.getString("action"),
                        rs.getString("details"),
                        rs.getObject("occurred_at", OffsetDateTime.class)));
    }
}
