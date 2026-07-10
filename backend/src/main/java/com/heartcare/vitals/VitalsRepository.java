package com.heartcare.vitals;

import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface VitalsRepository extends JpaRepository<VitalLog, UUID> {

    Optional<VitalLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT v FROM VitalLog v
            WHERE v.userId = :userId
              AND (CAST(:from AS LocalDate) IS NULL OR CAST(v.measuredAt AS LocalDate) >= :from)
              AND (CAST(:to AS LocalDate) IS NULL OR CAST(v.measuredAt AS LocalDate) <= :to)
              AND (:type IS NULL OR v.type = :type)
            ORDER BY v.measuredAt DESC
            """)
    List<VitalLog> findHistory(@Param("userId") UUID userId,
                               @Param("from") LocalDate from,
                               @Param("to") LocalDate to,
                               @Param("type") VitalType type);
}
