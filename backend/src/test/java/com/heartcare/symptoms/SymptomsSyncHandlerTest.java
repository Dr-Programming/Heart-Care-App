package com.heartcare.symptoms;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.sync.SyncStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * NOTE: the check-in `data` fields are nested maps, not scalars — SymptomsService.validate calls
 * asMap(...) on chestPain and bloodPressure and throws BadRequestException otherwise. A payload
 * using e.g. "chestPain": 0 or "bloodPressure": "NORMAL" fails validation before ever reaching
 * the comparison logic under test here.
 */
class SymptomsSyncHandlerTest extends AbstractIntegrationTest {

    @Autowired SymptomsSyncHandler handler;
    @Autowired JdbcTemplate jdbcTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }

    private JsonNode payload(int heartRate) throws Exception {
        return objectMapper.readTree("""
                {"data":{"chestPain":{"present":false},
                         "shortnessOfBreath":"NONE",
                         "heartRate":%d,
                         "bloodPressure":{"systolic":120,"diastolic":80},
                         "swelling":false,
                         "energyLevel":5},
                 "measuredAt":"2026-07-17T08:30:00+03:00"}""".formatted(heartRate));
    }

    @Test
    void entityTypeIsSymptom() {
        assertThat(handler.entityType()).isEqualTo("SYMPTOM");
    }

    @Test
    void newRecordIsSaved() throws Exception {
        var outcome = handler.handle(seedUser(), UUID.randomUUID(), payload(70));
        assertThat(outcome.status()).isEqualTo(SyncStatus.SAVED);
        assertThat(outcome.serverId()).isNotNull();
    }

    @Test
    void identicalResendIsDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        var first = handler.handle(userId, crid, payload(70));
        var second = handler.handle(userId, crid, payload(70));

        assertThat(second.status()).isEqualTo(SyncStatus.DUPLICATE);
        assertThat(second.serverId()).isEqualTo(first.serverId());
    }

    @Test
    void divergentPayloadUnderSameKeyIsConflict() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        var first = handler.handle(userId, crid, payload(70));
        var second = handler.handle(userId, crid, payload(95));

        assertThat(second.status()).isEqualTo(SyncStatus.CONFLICT);
        assertThat(second.serverId()).isEqualTo(first.serverId());
    }

    /** Feature validation still applies through the handler: energyLevel 11 is out of range (0-10). */
    @Test
    void invalidPayloadThrowsBadRequest() throws Exception {
        JsonNode invalid = objectMapper.readTree("""
                {"data":{"chestPain":{"present":false},
                         "shortnessOfBreath":"NONE",
                         "heartRate":70,
                         "bloodPressure":{"systolic":120,"diastolic":80},
                         "swelling":false,
                         "energyLevel":11},
                 "measuredAt":"2026-07-17T08:30:00+03:00"}""");

        assertThatThrownBy(() -> handler.handle(seedUser(), UUID.randomUUID(), invalid))
                .isInstanceOf(BadRequestException.class);
    }
}
