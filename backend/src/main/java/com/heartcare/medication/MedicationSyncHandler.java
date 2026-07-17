package com.heartcare.medication;

import tools.jackson.databind.JsonNode;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncPayloadMapper;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.model.Medication;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * Syncs medication CREATES only. Offline edits (update/deactivate) are out of scope: they key off
 * a server id the device may not have and they mutate, which reopens last-write-wins (Decision 7).
 */
@Component
public class MedicationSyncHandler implements SyncHandler {

    private final MedicationService medicationService;
    private final MedicationRepository medicationRepository;
    private final SyncPayloadMapper payloadMapper;

    public MedicationSyncHandler(MedicationService medicationService,
                                 MedicationRepository medicationRepository,
                                 SyncPayloadMapper payloadMapper) {
        this.medicationService = medicationService;
        this.medicationRepository = medicationRepository;
        this.payloadMapper = payloadMapper;
    }

    @Override
    public String entityType() {
        return "MEDICATION";
    }

    @Override
    public SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload) {
        MedicationRequest incoming =
                withKey(payloadMapper.toRequest(payload, MedicationRequest.class), clientRecordId);

        var existing = medicationRepository.findByUserIdAndClientRecordId(userId, clientRecordId);
        if (existing.isPresent()) {
            Medication stored = existing.get();
            String serverId = stored.getId().toString();
            return matches(stored, incoming) ? SyncOutcome.duplicate(serverId) : SyncOutcome.conflict(serverId);
        }
        return SyncOutcome.saved(medicationService.create(userId, incoming).id());
    }

    private MedicationRequest withKey(MedicationRequest r, UUID clientRecordId) {
        return new MedicationRequest(r.name(), r.doseMg(), r.frequency(), r.scheduleTimes(),
                r.active(), clientRecordId);
    }

    private boolean matches(Medication stored, MedicationRequest incoming) {
        return Objects.equals(stored.getName(), incoming.name())
                // compareTo, not equals: BigDecimal.equals is scale-sensitive (20 != 20.0).
                && stored.getDoseMg().compareTo(incoming.doseMg()) == 0
                && stored.getFrequency() == incoming.frequency()
                && Objects.equals(stored.getScheduleTimes(), scheduleTimesOrEmpty(incoming))
                // active defaults to true on create when the client omits it.
                && stored.isActive() == (incoming.active() == null || incoming.active());
    }

    private List<String> scheduleTimesOrEmpty(MedicationRequest incoming) {
        return incoming.scheduleTimes() == null ? List.of() : incoming.scheduleTimes();
    }
}
