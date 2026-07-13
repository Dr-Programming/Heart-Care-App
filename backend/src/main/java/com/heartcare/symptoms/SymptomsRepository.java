package com.heartcare.symptoms;

import com.heartcare.symptoms.model.SymptomLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SymptomsRepository extends JpaRepository<SymptomLog, UUID> {

    Optional<SymptomLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT s FROM SymptomLog s
            WHERE s.userId = :userId
              AND s.measuredAt >= :from
              AND s.measuredAt < :to
            ORDER BY s.measuredAt DESC
            """)
    List<SymptomLog> findHistory(@Param("userId") UUID userId,
                                 @Param("from") OffsetDateTime from,
                                 @Param("to") OffsetDateTime to);
}
