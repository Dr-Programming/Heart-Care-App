package com.heartcare.medication;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.common.time.ClientZone;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import com.heartcare.medication.model.DoseLog;
import com.heartcare.medication.model.Medication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

@Service
public class DoseLogService {

    private final DoseLogRepository doseLogRepository;
    private final MedicationRepository medicationRepository;
    private final IdempotentSaver saver;
    private final ClientZone clientZone;

    public DoseLogService(DoseLogRepository doseLogRepository, MedicationRepository medicationRepository,
                           IdempotentSaver saver, ClientZone clientZone) {
        this.doseLogRepository = doseLogRepository;
        this.medicationRepository = medicationRepository;
        this.saver = saver;
        this.clientZone = clientZone;
    }

    // Deliberately NOT @Transactional — see IdempotentSaver and design §8.
    public DoseLogResponse log(UUID userId, UUID medicationId, DoseLogRequest request) {
        Medication medication = medicationRepository.findByIdAndUserId(medicationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medication not found"));

        // DoseLogRequest declares clientRecordId @NotNull; the sync path always supplies one.
        Supplier<Optional<DoseLog>> finder =
                () -> doseLogRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());

        var existing = finder.get();
        if (existing.isPresent()) {
            return toResponse(existing.get());
        }

        clientZone.assertNotFutureDate(request.scheduledDate(), "scheduledDate");
        clientZone.assertNotFuture(request.loggedAt(), "loggedAt");
        requireActiveOn(medication, request.scheduledDate());

        DoseLog dose = new DoseLog();
        dose.setMedicationId(medicationId);
        dose.setUserId(userId);
        dose.setScheduledDate(request.scheduledDate());
        dose.setScheduledTime(request.scheduledTime());
        dose.setStatus(request.status());
        dose.setLoggedAt(request.loggedAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.loggedAt());
        dose.setNote(request.note());
        dose.setClientRecordId(request.clientRecordId());

        return toResponse(saver.saveOrGetExisting(doseLogRepository, finder, dose));
    }

    /**
     * Date-aware rather than a plain {@code active} check (Issue 2). The app works offline, so a
     * dose taken while the medication was active can reach the server after it was switched off;
     * that is real history. Only doses scheduled after the deactivation day are refused. BadRequest
     * makes the sync path report REJECTED, so the client stops retrying the record.
     */
    private void requireActiveOn(Medication medication, LocalDate scheduledDate) {
        if (medication.isActive() || medication.getDeactivatedAt() == null) {
            return;
        }
        LocalDate deactivatedOn = clientZone.localDateOf(medication.getDeactivatedAt());
        if (scheduledDate.isAfter(deactivatedOn)) {
            throw new BadRequestException(
                    "Medication is inactive: it was deactivated before " + scheduledDate);
        }
    }

    @Transactional(readOnly = true)
    public List<DoseLogResponse> history(UUID userId, LocalDate from, LocalDate to, UUID medicationId) {
        return doseLogRepository.findHistory(userId, from, to, medicationId)
                .stream().map(this::toResponse).toList();
    }

    private DoseLogResponse toResponse(DoseLog d) {
        return new DoseLogResponse(
                d.getId() == null ? null : d.getId().toString(),
                d.getMedicationId().toString(),
                d.getScheduledDate(),
                d.getScheduledTime(),
                d.getStatus(),
                d.getLoggedAt(),
                d.getNote(),
                d.getClientRecordId() == null ? null : d.getClientRecordId().toString(),
                d.getCreatedAt());
    }
}
