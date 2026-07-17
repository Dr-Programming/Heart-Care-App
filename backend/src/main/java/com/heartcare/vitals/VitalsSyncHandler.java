package com.heartcare.vitals;

import tools.jackson.databind.JsonNode;
import com.heartcare.common.sync.SyncComparisons;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncPayloadMapper;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.model.VitalLog;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

@Component
public class VitalsSyncHandler implements SyncHandler {

    private final VitalsService vitalsService;
    private final VitalsRepository vitalsRepository;
    private final SyncPayloadMapper payloadMapper;

    public VitalsSyncHandler(VitalsService vitalsService,
                             VitalsRepository vitalsRepository,
                             SyncPayloadMapper payloadMapper) {
        this.vitalsService = vitalsService;
        this.vitalsRepository = vitalsRepository;
        this.payloadMapper = payloadMapper;
    }

    @Override
    public String entityType() {
        return "VITAL";
    }

    @Override
    public SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload) {
        VitalLogRequest incoming = withKey(payloadMapper.toRequest(payload, VitalLogRequest.class), clientRecordId);

        var existing = vitalsRepository.findByUserIdAndClientRecordId(userId, clientRecordId);
        if (existing.isPresent()) {
            VitalLog stored = existing.get();
            String serverId = stored.getId().toString();
            return matches(stored, incoming) ? SyncOutcome.duplicate(serverId) : SyncOutcome.conflict(serverId);
        }
        return SyncOutcome.saved(vitalsService.log(userId, incoming).id());
    }

    /** The envelope's key is authoritative; whatever the payload carried is discarded (design §4). */
    private VitalLogRequest withKey(VitalLogRequest r, UUID clientRecordId) {
        return new VitalLogRequest(r.type(), r.values(), r.measuredAt(), r.note(), clientRecordId);
    }

    private boolean matches(VitalLog stored, VitalLogRequest incoming) {
        return stored.getType() == incoming.type()
                && sameValues(stored.getValues(), incoming.values())
                && SyncComparisons.sameInstant(stored.getMeasuredAt(), incoming.measuredAt())
                && Objects.equals(stored.getNote(), incoming.note());
    }

    private boolean sameValues(Map<String, BigDecimal> stored, Map<String, BigDecimal> incoming) {
        Map<String, BigDecimal> a = new HashMap<>(stored);
        Map<String, BigDecimal> b = new HashMap<>(incoming == null ? Map.of() : incoming);
        // bmi is server-computed for WEIGHT and stripped from input by VitalsService, so the stored
        // map has a key the client never sends. Comparing it would flag every weight log.
        a.remove("bmi");
        b.remove("bmi");
        if (!a.keySet().equals(b.keySet())) {
            return false;
        }
        // compareTo, not equals: BigDecimal.equals is scale-sensitive, so 128 != 128.0.
        return a.keySet().stream().allMatch(k -> a.get(k).compareTo(b.get(k)) == 0);
    }
}
