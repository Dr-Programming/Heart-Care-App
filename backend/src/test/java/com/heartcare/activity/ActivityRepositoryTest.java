package com.heartcare.activity;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.activity.model.ActivityLog;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ActivityRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    ActivityRepository activityRepository;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }

    @Test
    void savesAndReloadsActivityWithJsonb() {
        UUID userId = seedUser();
        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(Map.of(
                "type", "WALKING",
                "durationMinutes", 30,
                "intensity", "MODERATE",
                "steps", 3200,
                "distanceMeters", 2400));
        log.setMeasuredAt(OffsetDateTime.now());
        log.setNote("morning walk");

        ActivityLog saved = activityRepository.saveAndFlush(log);

        ActivityLog reloaded = activityRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getData().get("type")).isEqualTo("WALKING");
        assertThat(reloaded.getData().get("durationMinutes")).isEqualTo(30);
        assertThat(reloaded.getData().get("intensity")).isEqualTo("MODERATE");
        assertThat(reloaded.getData().get("steps")).isEqualTo(3200);
        assertThat(reloaded.getNote()).isEqualTo("morning walk");
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(Map.of("type", "WALKING", "durationMinutes", 20, "intensity", "LIGHT"));
        log.setMeasuredAt(OffsetDateTime.now());
        log.setClientRecordId(crid);
        activityRepository.saveAndFlush(log);

        assertThat(activityRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(activityRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
