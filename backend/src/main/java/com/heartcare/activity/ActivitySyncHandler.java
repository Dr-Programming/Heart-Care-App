package com.heartcare.activity;

import tools.jackson.databind.JsonNode;
import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.model.ActivityLog;
import com.heartcare.common.sync.SyncComparisons;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncPayloadMapper;
import org.springframework.stereotype.Component;

import java.util.Objects;
import java.util.UUID;

@Component
public class ActivitySyncHandler implements SyncHandler {

    private final ActivityService activityService;
    private final ActivityRepository activityRepository;
    private final SyncPayloadMapper payloadMapper;

    public ActivitySyncHandler(ActivityService activityService,
                               ActivityRepository activityRepository,
                               SyncPayloadMapper payloadMapper) {
        this.activityService = activityService;
        this.activityRepository = activityRepository;
        this.payloadMapper = payloadMapper;
    }

    @Override
    public String entityType() {
        return "ACTIVITY";
    }

    @Override
    public SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload) {
        ActivityLogRequest incoming =
                withKey(payloadMapper.toRequest(payload, ActivityLogRequest.class), clientRecordId);

        var existing = activityRepository.findByUserIdAndClientRecordId(userId, clientRecordId);
        if (existing.isPresent()) {
            ActivityLog stored = existing.get();
            String serverId = stored.getId().toString();
            return matches(stored, incoming) ? SyncOutcome.duplicate(serverId) : SyncOutcome.conflict(serverId);
        }
        return SyncOutcome.saved(activityService.log(userId, incoming).id());
    }

    private ActivityLogRequest withKey(ActivityLogRequest r, UUID clientRecordId) {
        return new ActivityLogRequest(r.data(), r.measuredAt(), r.note(), clientRecordId);
    }

    /**
     * Activity data is a plain JSONB map with no server-computed keys, so a direct comparison is
     * right. Known limitation: a JSON number that round-trips through JSONB as Integer will not
     * equal an incoming Double of the same value (30 vs 30.0), which would read as a CONFLICT.
     * Accepted — clients send whole numbers for these fields.
     */
    private boolean matches(ActivityLog stored, ActivityLogRequest incoming) {
        return Objects.equals(stored.getData(), incoming.data())
                && SyncComparisons.sameInstant(stored.getMeasuredAt(), incoming.measuredAt())
                && Objects.equals(stored.getNote(), incoming.note());
    }
}
