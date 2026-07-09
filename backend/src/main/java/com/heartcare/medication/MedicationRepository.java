package com.heartcare.medication;

import com.heartcare.medication.model.Medication;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MedicationRepository extends JpaRepository<Medication, UUID> {

    Optional<Medication> findByIdAndUserId(UUID id, UUID userId);

    Optional<Medication> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    List<Medication> findByUserIdOrderByCreatedAtDesc(UUID userId);

    List<Medication> findByUserIdAndActiveTrueOrderByCreatedAtDesc(UUID userId);
}
