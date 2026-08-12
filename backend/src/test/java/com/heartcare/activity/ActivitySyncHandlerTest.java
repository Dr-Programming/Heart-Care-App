package com.heartcare.activity;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.sync.SyncStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ActivitySyncHandlerTest extends AbstractIntegrationTest {

    @Autowired ActivitySyncHandler handler;
    @Autowired JdbcTemplate jdbcTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private UUID seedUser() {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO users (id, phone, pin_hash, full_name, role) VALUES (?, ?, ?, ?, 'PATIENT')",
                id, TestUsers.nextPhone(), "x", "Test User");
        return id;
    }

    private JsonNode payload(int durationMinutes) throws Exception {
        return objectMapper.readTree("""
                {"data":{"type":"WALKING","durationMinutes":%d,"intensity":"MODERATE"},
                 "measuredAt":"2026-07-17T08:30:00+03:00"}""".formatted(durationMinutes));
    }

    @Test
    void entityTypeIsActivity() {
        assertThat(handler.entityType()).isEqualTo("ACTIVITY");
    }

    @Test
    void newRecordIsSaved() throws Exception {
        var outcome = handler.handle(seedUser(), UUID.randomUUID(), payload(30));
        assertThat(outcome.status()).isEqualTo(SyncStatus.SAVED);
    }

    @Test
    void identicalResendIsDuplicate() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        handler.handle(userId, crid, payload(30));
        assertThat(handler.handle(userId, crid, payload(30)).status()).isEqualTo(SyncStatus.DUPLICATE);
    }

    @Test
    void divergentPayloadIsConflict() throws Exception {
        UUID userId = seedUser();
        UUID crid = UUID.randomUUID();
        handler.handle(userId, crid, payload(30));
        assertThat(handler.handle(userId, crid, payload(45)).status()).isEqualTo(SyncStatus.CONFLICT);
    }

    /** Feature validation still applies through the handler: 0 minutes is out of range. */
    @Test
    void invalidPayloadThrowsBadRequest() throws Exception {
        assertThatThrownBy(() -> handler.handle(seedUser(), UUID.randomUUID(), payload(0)))
                .isInstanceOf(BadRequestException.class);
    }
}
