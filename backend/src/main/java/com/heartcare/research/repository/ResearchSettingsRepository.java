package com.heartcare.research.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** The single-row research_settings table (seeded by V10). */
@Repository
public class ResearchSettingsRepository {

    private final JdbcTemplate jdbc;

    public ResearchSettingsRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public int minGroupSize() {
        Integer k = jdbc.queryForObject("SELECT min_group_size FROM research_settings WHERE id = 1", Integer.class);
        return k == null ? 5 : k;
    }

    public void setMinGroupSize(int k) {
        jdbc.update("UPDATE research_settings SET min_group_size = ?, updated_at = now() WHERE id = 1", k);
    }
}
