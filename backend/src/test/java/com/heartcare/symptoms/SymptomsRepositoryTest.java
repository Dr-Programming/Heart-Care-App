package com.heartcare.symptoms;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.symptoms.model.SymptomLog;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SymptomsRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    SymptomsRepository symptomsRepository;

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
    void savesAndReloadsCheckInWithNestedJsonb() {
        UUID userId = seedUser();
        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(Map.of(
                "chestPain", Map.of("present", true, "severity", 8),
                "shortnessOfBreath", "MILD",
                "heartRate", 82,
                "bloodPressure", Map.of("systolic", 165, "diastolic", 92),
                "swelling", true,
                "energyLevel", 4));
        log.setAssessment(Map.of(
                "overall", "EMERGENCY",
                "symptoms", Map.of("chestPain", "EMERGENCY", "heartRate", "NONE")));
        log.setOverallSeverity(Severity.EMERGENCY);
        log.setMeasuredAt(OffsetDateTime.now());

        SymptomLog saved = symptomsRepository.saveAndFlush(log);

        SymptomLog reloaded = symptomsRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getOverallSeverity()).isEqualTo(Severity.EMERGENCY);
        assertThat(reloaded.getData().get("shortnessOfBreath")).isEqualTo("MILD");
        assertThat(reloaded.getData().get("heartRate")).isEqualTo(82);
        @SuppressWarnings("unchecked")
        Map<String, Object> chestPain = (Map<String, Object>) reloaded.getData().get("chestPain");
        assertThat(chestPain.get("present")).isEqualTo(true);
        assertThat(chestPain.get("severity")).isEqualTo(8);
        @SuppressWarnings("unchecked")
        Map<String, Object> assessment = (Map<String, Object>) reloaded.getAssessment().get("symptoms");
        assertThat(assessment.get("chestPain")).isEqualTo("EMERGENCY");
    }

    @Test
    void findByUserIdAndClientRecordIdReturnsMatch() {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(Map.of("swelling", false));
        log.setAssessment(Map.of("overall", "NONE"));
        log.setOverallSeverity(Severity.NONE);
        log.setMeasuredAt(OffsetDateTime.now());
        log.setClientRecordId(crid);
        symptomsRepository.saveAndFlush(log);

        assertThat(symptomsRepository.findByUserIdAndClientRecordId(userId, crid)).isPresent();
        assertThat(symptomsRepository.findByUserIdAndClientRecordId(userId, UUID.randomUUID())).isEmpty();
    }
}
