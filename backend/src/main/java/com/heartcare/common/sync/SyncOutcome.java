package com.heartcare.common.sync;

/**
 * A handler's verdict for one record. Handlers never produce {@link SyncStatus#REJECTED} —
 * they throw BadRequestException/ResourceNotFoundException and SyncService maps it (design §7).
 */
public record SyncOutcome(SyncStatus status, String serverId) {

    public static SyncOutcome saved(String serverId) {
        return new SyncOutcome(SyncStatus.SAVED, serverId);
    }

    public static SyncOutcome duplicate(String serverId) {
        return new SyncOutcome(SyncStatus.DUPLICATE, serverId);
    }

    public static SyncOutcome conflict(String serverId) {
        return new SyncOutcome(SyncStatus.CONFLICT, serverId);
    }
}
