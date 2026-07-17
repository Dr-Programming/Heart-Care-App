package com.heartcare.symptoms;

import tools.jackson.databind.JsonNode;
import com.heartcare.common.sync.SyncComparisons;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncPayloadMapper;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.model.SymptomLog;
import org.springframework.stereotype.Component;

import java.util.Objects;
import java.util.UUID;

@Component
public class SymptomsSyncHandler implements SyncHandler {

    private final SymptomsService symptomsService;
    private final SymptomsRepository symptomsRepository;
    private final SyncPayloadMapper payloadMapper;

    public SymptomsSyncHandler(SymptomsService symptomsService,
                               SymptomsRepository symptomsRepository,
                               SyncPayloadMapper payloadMapper) {
        this.symptomsService = symptomsService;
        this.symptomsRepository = symptomsRepository;
        this.payloadMapper = payloadMapper;
    }

    @Override
    public String entityType() {
        return "SYMPTOM";
    }

    @Override
    public SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload) {
        SymptomLogRequest incoming =
                withKey(payloadMapper.toRequest(payload, SymptomLogRequest.class), clientRecordId);

        var existing = symptomsRepository.findByUserIdAndClientRecordId(userId, clientRecordId);
        if (existing.isPresent()) {
            SymptomLog stored = existing.get();
            String serverId = stored.getId().toString();
            return matches(stored, incoming) ? SyncOutcome.duplicate(serverId) : SyncOutcome.conflict(serverId);
        }
        return SyncOutcome.saved(symptomsService.log(userId, incoming).id());
    }

    private SymptomLogRequest withKey(SymptomLogRequest r, UUID clientRecordId) {
        return new SymptomLogRequest(r.data(), r.measuredAt(), r.note(), clientRecordId);
    }

    /**
     * Compares the check-in data only. assessment and overallSeverity are server-computed from
     * that data, so they cannot diverge independently and comparing them would be redundant.
     */
    private boolean matches(SymptomLog stored, SymptomLogRequest incoming) {
        return Objects.equals(stored.getData(), incoming.data())
                && SyncComparisons.sameInstant(stored.getMeasuredAt(), incoming.measuredAt())
                && Objects.equals(stored.getNote(), incoming.note());
    }
}
