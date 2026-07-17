package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import com.heartcare.medication.model.DoseLog;
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

    public DoseLogService(DoseLogRepository doseLogRepository, MedicationRepository medicationRepository,
                           IdempotentSaver saver) {
        this.doseLogRepository = doseLogRepository;
        this.medicationRepository = medicationRepository;
        this.saver = saver;
    }

    // Deliberately NOT @Transactional — see IdempotentSaver and design §8.
    public DoseLogResponse log(UUID userId, UUID medicationId, DoseLogRequest request) {
        medicationRepository.findByIdAndUserId(medicationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medication not found"));

        Supplier<Optional<DoseLog>> finder = () -> request.clientRecordId() == null
                ? Optional.empty()
                : doseLogRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());

        var existing = finder.get();
        if (existing.isPresent()) {
            return toResponse(existing.get());
        }

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
