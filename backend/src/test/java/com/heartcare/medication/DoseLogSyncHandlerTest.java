package com.heartcare.medication;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.sync.SyncStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DoseLogSyncHandlerTest extends AbstractIntegrationTest {

    @Autowired MedicationSyncHandler medicationHandler;
    @Autowired DoseLogSyncHandler doseHandler;
    @Autowired JdbcTemplate jdbcTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }

    private JsonNode medicationPayload() throws Exception {
        return objectMapper.readTree("""
                {"name":"Atorvastatin","doseMg":20,"frequency":"ONCE_DAILY","scheduleTimes":["08:00"]}""");
    }

    private JsonNode dosePayloadByClientId(UUID medicationClientRecordId) throws Exception {
        return objectMapper.readTree("""
                {"medicationClientRecordId":"%s","status":"TAKEN","scheduledDate":"2026-07-17",
                 "loggedAt":"2026-07-17T08:05:00+03:00"}""".formatted(medicationClientRecordId));
    }

    private JsonNode dosePayloadByServerId(String medicationId) throws Exception {
        return objectMapper.readTree("""
                {"medicationId":"%s","status":"TAKEN","scheduledDate":"2026-07-17",
                 "loggedAt":"2026-07-17T08:05:00+03:00"}""".formatted(medicationId));
    }

    @Test
    void entityTypesAreMedicationAndDoseLog() {
        assertThat(medicationHandler.entityType()).isEqualTo("MEDICATION");
        assertThat(doseHandler.entityType()).isEqualTo("DOSE_LOG");
    }

    /** Decision 8: the whole point — a dose whose medication has never been synced. */
    @Test
    void resolvesMedicationCreatedInTheSameBatchByClientRecordId() throws Exception {
        UUID userId = seedUser();
        UUID medCrid = UUID.randomUUID();
        var med = medicationHandler.handle(userId, medCrid, medicationPayload());

        var dose = doseHandler.handle(userId, UUID.randomUUID(), dosePayloadByClientId(medCrid));

        assertThat(dose.status()).isEqualTo(SyncStatus.SAVED);
        String medicationId = jdbcTemplate.queryForObject(
                "SELECT medication_id::text FROM dose_logs WHERE id = ?::uuid", String.class, dose.serverId());
        assertThat(medicationId).isEqualTo(med.serverId());
    }

    @Test
    void resolvesMedicationByServerId() throws Exception {
        UUID userId = seedUser();
        var med = medicationHandler.handle(userId, UUID.randomUUID(), medicationPayload());

        var dose = doseHandler.handle(userId, UUID.randomUUID(), dosePayloadByServerId(med.serverId()));

        assertThat(dose.status()).isEqualTo(SyncStatus.SAVED);
    }

    @Test
    void unresolvableMedicationClientRecordIdIsNotFound() throws Exception {
        assertThatThrownBy(() -> doseHandler.handle(
                seedUser(), UUID.randomUUID(), dosePayloadByClientId(UUID.randomUUID())))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void payloadWithNeitherReferenceIsBadRequest() throws Exception {
        JsonNode payload = objectMapper.readTree("""
                {"status":"TAKEN","scheduledDate":"2026-07-17"}""");

        assertThatThrownBy(() -> doseHandler.handle(seedUser(), UUID.randomUUID(), payload))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("medicationId");
    }

    @Test
    void identicalMedicationResendIsDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        var first = medicationHandler.handle(userId, crid, medicationPayload());
        var second = medicationHandler.handle(userId, crid, medicationPayload());

        assertThat(second.status()).isEqualTo(SyncStatus.DUPLICATE);
        assertThat(second.serverId()).isEqualTo(first.serverId());
    }

    @Test
    void divergentMedicationIsConflict() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        medicationHandler.handle(userId, crid, medicationPayload());
        JsonNode changed = objectMapper.readTree("""
                {"name":"Atorvastatin","doseMg":40,"frequency":"ONCE_DAILY","scheduleTimes":["08:00"]}""");

        assertThat(medicationHandler.handle(userId, crid, changed).status()).isEqualTo(SyncStatus.CONFLICT);
    }
}
