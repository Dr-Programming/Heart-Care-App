package com.heartcare.research.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Saved cohort definitions. Every query is scoped to the owning researcher. */
@Repository
public class ResearchCohortRepository {

    public record Row(UUID id, UUID researcherId, String name, String definitionJson, OffsetDateTime createdAt) {
    }

    private final NamedParameterJdbcTemplate jdbc;

    public ResearchCohortRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public UUID insert(UUID researcherId, String name, String definitionJson) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO research_cohorts (id, researcher_id, name, definition)
                VALUES (:id, :rid, :name, CAST(:def AS jsonb))
                """, new MapSqlParameterSource()
                .addValue("id", id).addValue("rid", researcherId).addValue("name", name).addValue("def", definitionJson));
        return id;
    }

    public List<Row> forResearcher(UUID researcherId) {
        return jdbc.query("""
                SELECT id, researcher_id, name, definition::text AS definition, created_at
                  FROM research_cohorts WHERE researcher_id = :rid ORDER BY created_at DESC
                """, new MapSqlParameterSource("rid", researcherId), (rs, i) -> map(rs));
    }

    public Optional<Row> find(UUID id, UUID researcherId) {
        return jdbc.query("""
                SELECT id, researcher_id, name, definition::text AS definition, created_at
                  FROM research_cohorts WHERE id = :id AND researcher_id = :rid
                """, new MapSqlParameterSource().addValue("id", id).addValue("rid", researcherId),
                (rs, i) -> map(rs)).stream().findFirst();
    }

    public boolean delete(UUID id, UUID researcherId) {
        return jdbc.update("DELETE FROM research_cohorts WHERE id = :id AND researcher_id = :rid",
                new MapSqlParameterSource().addValue("id", id).addValue("rid", researcherId)) > 0;
    }

    private static Row map(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new Row(rs.getObject("id", UUID.class), rs.getObject("researcher_id", UUID.class),
                rs.getString("name"), rs.getString("definition"), rs.getObject("created_at", OffsetDateTime.class));
    }
}
