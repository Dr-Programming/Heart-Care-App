package com.heartcare.common.sync;

import tools.jackson.databind.JsonNode;

import java.util.UUID;

/**
 * One feature's adapter for the sync endpoint. Each implementation lives in its own feature
 * package and is collected by Spring into SyncService's registry, so that SyncService itself
 * imports no feature package (architectural rule 1).
 */
public interface SyncHandler {

    /** The wire discriminator, e.g. "VITAL". Must be unique across all handlers. */
    String entityType();

    /**
     * @param clientRecordId the envelope's key — authoritative; overrides any value in the payload
     * @throws com.heartcare.common.exception.BadRequestException if the payload is invalid (-> REJECTED)
     * @throws com.heartcare.common.exception.ResourceNotFoundException if a referenced entity is missing (-> REJECTED)
     */
    SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload);
}
