package com.heartcare.sync.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncStatus;

import java.util.UUID;

/** The per-record verdict. {@code serverId} is set unless REJECTED; {@code reason} only when REJECTED. */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record SyncResult(UUID clientRecordId, SyncStatus status, String serverId, String reason) {

    public static SyncResult of(UUID clientRecordId, SyncOutcome outcome) {
        return new SyncResult(clientRecordId, outcome.status(), outcome.serverId(), null);
    }

    public static SyncResult rejected(UUID clientRecordId, String reason) {
        return new SyncResult(clientRecordId, SyncStatus.REJECTED, null, reason);
    }
}
