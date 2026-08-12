package com.heartcare.medication;

import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.persistence.IdempotentSaver;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import com.heartcare.medication.model.Medication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

@Service
public class MedicationService {

    private final MedicationRepository repository;
    private final IdempotentSaver saver;

    public MedicationService(MedicationRepository repository, IdempotentSaver saver) {
        this.repository = repository;
        this.saver = saver;
    }

    // Deliberately NOT @Transactional — see IdempotentSaver and design §8.
    public MedicationResponse create(UUID userId, MedicationRequest request) {
        Supplier<Optional<Medication>> finder = () -> request.clientRecordId() == null
                ? Optional.empty()
                : repository.findByUserIdAndClientRecordId(userId, request.clientRecordId());

        var existing = finder.get();
        if (existing.isPresent()) {
            return toResponse(existing.get());
        }

        Medication medication = new Medication();
        medication.setUserId(userId);
        medication.setClientRecordId(request.clientRecordId());
        applyEditableFields(medication, request);
        medication.setActive(request.active() == null || request.active());

        return toResponse(saver.saveOrGetExisting(repository, finder, medication));
    }

    @Transactional(readOnly = true)
    public List<MedicationResponse> list(UUID userId, boolean includeInactive) {
        List<Medication> medications = includeInactive
                ? repository.findByUserIdOrderByCreatedAtDesc(userId)
                : repository.findByUserIdAndActiveTrueOrderByCreatedAtDesc(userId);
        return medications.stream().map(this::toResponse).toList();
    }

    @Transactional
    public MedicationResponse update(UUID userId, UUID id, MedicationRequest request) {
        Medication medication = getOwned(userId, id);
        applyEditableFields(medication, request);
        if (request.active() != null) {
            medication.setActive(request.active());
        }
        return toResponse(repository.save(medication));
    }

    @Transactional
    public MedicationResponse deactivate(UUID userId, UUID id) {
        Medication medication = getOwned(userId, id);
        medication.setActive(false);
        return toResponse(repository.save(medication));
    }

    private Medication getOwned(UUID userId, UUID id) {
        return repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medication not found"));
    }

    private void applyEditableFields(Medication medication, MedicationRequest request) {
        medication.setName(request.name());
        medication.setDoseMg(request.doseMg());
        medication.setFrequency(request.frequency());
        medication.setScheduleTimes(request.scheduleTimes() == null
                ? new ArrayList<>() : new ArrayList<>(request.scheduleTimes()));
    }

    private MedicationResponse toResponse(Medication m) {
        return new MedicationResponse(
                m.getId() == null ? null : m.getId().toString(),
                m.getName(),
                m.getDoseMg(),
                m.getFrequency(),
                m.getScheduleTimes(),
                m.isActive(),
                m.getClientRecordId() == null ? null : m.getClientRecordId().toString(),
                m.getCreatedAt(),
                m.getUpdatedAt());
    }
}
