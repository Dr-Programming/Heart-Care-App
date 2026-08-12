package com.heartcare.vitals;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class VitalsRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    VitalsRepository vitalsRepository;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }

    @Test
    void savesAndReloadsVitalWithJsonbValues() {
        UUID userId = seedUser();
        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(VitalType.BLOOD_PRESSURE);
        vital.setValues(Map.of("systolic", new BigDecimal("120"), "diastolic", new BigDecimal("80")));
        vital.setFlagged(false);
        vital.setMeasuredAt(OffsetDateTime.now());

        VitalLog saved = vitalsRepository.saveAndFlush(vital);

        VitalLog reloaded = vitalsRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getType()).isEqualTo(VitalType.BLOOD_PRESSURE);
        assertThat(reloaded.getValues().get("systolic")).isEqualByComparingTo("120");
        assertThat(reloaded.getValues().get("diastolic")).isEqualByComparingTo("80");
        assertThat(reloaded.isFlagged()).isFalse();
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(VitalType.WEIGHT);
        vital.setValues(Map.of("weight", new BigDecimal("72.0")));
        vital.setMeasuredAt(OffsetDateTime.now());
        vital.setClientRecordId(crid);
        vitalsRepository.saveAndFlush(vital);

        assertThat(vitalsRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(vitalsRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
