package com.heartcare.activity;

import com.heartcare.activity.model.ActivityLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ActivityRepository extends JpaRepository<ActivityLog, UUID> {

    Optional<ActivityLog> findByUserIdAndClientRecordId(UUID userId, UUID clientRecordId);

    @Query("""
            SELECT a FROM ActivityLog a
            WHERE a.userId = :userId
              AND a.measuredAt >= :from
              AND a.measuredAt < :to
            ORDER BY a.measuredAt DESC
            """)
    List<ActivityLog> findHistory(@Param("userId") UUID userId,
                                  @Param("from") OffsetDateTime from,
                                  @Param("to") OffsetDateTime to);
}
