package com.heartcare.sync.dto;

import tools.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * One record in a sync batch. {@code clientRecordId} is the idempotency key and is authoritative —
 * any clientRecordId inside {@code payload} is overwritten with it (design §4).
 */
public record SyncRecord(
        @NotNull(message = "clientRecordId is required")
        UUID clientRecordId,

        @NotBlank(message = "entityType is required")
        String entityType,

        @NotNull(message = "payload is required")
        JsonNode payload) {
}
