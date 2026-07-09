package com.heartcare.medication;

import com.heartcare.medication.model.DoseLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DoseLogRepository extends JpaRepository<DoseLog, UUID> {

    Optional<DoseLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT d FROM DoseLog d
            WHERE d.userId = :userId
              AND (CAST(:from AS LocalDate) IS NULL OR d.scheduledDate >= :from)
              AND (CAST(:to AS LocalDate) IS NULL OR d.scheduledDate <= :to)
              AND (:medicationId IS NULL OR d.medicationId = :medicationId)
            ORDER BY d.scheduledDate DESC, d.loggedAt DESC
            """)
    List<DoseLog> findHistory(@Param("userId") UUID userId,
                              @Param("from") LocalDate from,
                              @Param("to") LocalDate to,
                              @Param("medicationId") UUID medicationId);
}
