package com.heartcare.medication;

import tools.jackson.databind.JsonNode;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.sync.SyncComparisons;
import com.heartcare.common.sync.SyncHandler;
import com.heartcare.common.sync.SyncOutcome;
import com.heartcare.common.sync.SyncPayloadMapper;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.DoseStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Objects;
import java.util.UUID;

@Component
public class DoseLogSyncHandler implements SyncHandler {

    /**
     * The sync shape of a dose log. The REST endpoint takes the medication from the path
     * (POST /medications/{id}/doses), so DoseLogRequest has no medication field — but a phone that
     * has never synced has no server id to put in a path. Hence the alternative reference
     * (Decision 8). Exactly one of the two must be present.
     */
    public record DoseLogSyncPayload(
            UUID medicationId,
            UUID medicationClientRecordId,

            @NotNull(message = "status is required")
            DoseStatus status,

            @NotNull(message = "scheduledDate is required")
            LocalDate scheduledDate,

            LocalTime scheduledTime,
            OffsetDateTime loggedAt,

            @Size(max = 500, message = "note must be at most 500 characters")
            String note) {
    }

    private final DoseLogService doseLogService;
    private final DoseLogRepository doseLogRepository;
    private final MedicationRepository medicationRepository;
    private final SyncPayloadMapper payloadMapper;

    public DoseLogSyncHandler(DoseLogService doseLogService,
                              DoseLogRepository doseLogRepository,
                              MedicationRepository medicationRepository,
                              SyncPayloadMapper payloadMapper) {
        this.doseLogService = doseLogService;
        this.doseLogRepository = doseLogRepository;
        this.medicationRepository = medicationRepository;
        this.payloadMapper = payloadMapper;
    }

    @Override
    public String entityType() {
        return "DOSE_LOG";
    }

    @Override
    public SyncOutcome handle(UUID userId, UUID clientRecordId, JsonNode payload) {
        DoseLogSyncPayload incoming = payloadMapper.toRequest(payload, DoseLogSyncPayload.class);
        UUID medicationId = resolveMedicationId(userId, incoming);

        var existing = doseLogRepository.findByUserIdAndClientRecordId(userId, clientRecordId);
        if (existing.isPresent()) {
            DoseLog stored = existing.get();
            String serverId = stored.getId().toString();
            return matches(stored, incoming, medicationId)
                    ? SyncOutcome.duplicate(serverId) : SyncOutcome.conflict(serverId);
        }

        DoseLogRequest request = new DoseLogRequest(
                incoming.status(), incoming.scheduledDate(), incoming.scheduledTime(),
                incoming.loggedAt(), incoming.note(), clientRecordId);
        return SyncOutcome.saved(doseLogService.log(userId, medicationId, request).id());
    }

    /** @throws ResourceNotFoundException if the reference does not resolve (-> REJECTED) */
    private UUID resolveMedicationId(UUID userId, DoseLogSyncPayload incoming) {
        if (incoming.medicationId() != null) {
            return incoming.medicationId();   // DoseLogService verifies ownership
        }
        if (incoming.medicationClientRecordId() == null) {
            throw new BadRequestException("either medicationId or medicationClientRecordId is required");
        }
        return medicationRepository
                .findByUserIdAndClientRecordId(userId, incoming.medicationClientRecordId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Medication not found for clientRecordId " + incoming.medicationClientRecordId()))
                .getId();
    }

    private boolean matches(DoseLog stored, DoseLogSyncPayload incoming, UUID medicationId) {
        return Objects.equals(stored.getMedicationId(), medicationId)
                && stored.getStatus() == incoming.status()
                && Objects.equals(stored.getScheduledDate(), incoming.scheduledDate())
                && Objects.equals(stored.getScheduledTime(), incoming.scheduledTime())
                && SyncComparisons.sameInstant(stored.getLoggedAt(), incoming.loggedAt())
                && Objects.equals(stored.getNote(), incoming.note());
    }
}
