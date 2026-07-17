package com.heartcare.vitals;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.common.sync.SyncStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class VitalsSyncHandlerTest extends AbstractIntegrationTest {

    @Autowired VitalsSyncHandler handler;
    @Autowired JdbcTemplate jdbcTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, id + "@example.com", "x", "Test User");
        return id;
    }

    private JsonNode payload(String measuredAt, int systolic) throws Exception {
        return objectMapper.readTree("""
                {"type":"BLOOD_PRESSURE","values":{"systolic":%d,"diastolic":82},"measuredAt":"%s"}"""
                .formatted(systolic, measuredAt));
    }

    @Test
    void entityTypeIsVital() {
        assertThat(handler.entityType()).isEqualTo("VITAL");
    }

    @Test
    void newRecordIsSaved() throws Exception {
        UUID userId = seedUser();
        var outcome = handler.handle(userId, UUID.randomUUID(), payload("2026-07-17T08:30:00+03:00", 128));

        assertThat(outcome.status()).isEqualTo(SyncStatus.SAVED);
        assertThat(outcome.serverId()).isNotNull();
    }

    @Test
    void identicalResendIsDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        var first = handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));
        var second = handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));

        assertThat(second.status()).isEqualTo(SyncStatus.DUPLICATE);
        assertThat(second.serverId()).isEqualTo(first.serverId());
    }

    /**
     * The offset trap: +03:00 (Ethiopia) and Z are the same instant. OffsetDateTime.equals would
     * call this a conflict and every record from an Ethiopian phone would be flagged.
     */
    @Test
    void sameInstantInADifferentOffsetIsStillDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));
        var second = handler.handle(userId, crid, payload("2026-07-17T05:30:00Z", 128));

        assertThat(second.status()).isEqualTo(SyncStatus.DUPLICATE);
    }

    @Test
    void divergentPayloadUnderSameKeyIsConflict() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        var first = handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));
        var second = handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 155));

        assertThat(second.status()).isEqualTo(SyncStatus.CONFLICT);
        assertThat(second.serverId()).isEqualTo(first.serverId());
    }

    /** The stored record wins: a conflicting resend must not overwrite it (design Decision 3). */
    @Test
    void conflictDoesNotOverwriteTheStoredRecord() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));
        handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 155));

        Integer systolic = jdbcTemplate.queryForObject(
                "SELECT (vital_values->>'systolic')::int FROM vitals_logs WHERE user_id = ? AND client_record_id = ?",
                Integer.class, userId, crid);
        assertThat(systolic).isEqualTo(128);
    }

    /** BigDecimal.equals is scale-sensitive: 128 vs 128.0 must not read as a conflict. */
    @Test
    void differentScaleSameValueIsDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        handler.handle(userId, crid, payload("2026-07-17T08:30:00+03:00", 128));
        JsonNode scaled = objectMapper.readTree("""
                {"type":"BLOOD_PRESSURE","values":{"systolic":128.0,"diastolic":82.00},
                 "measuredAt":"2026-07-17T08:30:00+03:00"}""");
        var second = handler.handle(userId, crid, scaled);

        assertThat(second.status()).isEqualTo(SyncStatus.DUPLICATE);
    }
}
