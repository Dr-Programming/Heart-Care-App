package com.heartcare.admin.repository;

import com.heartcare.auth.model.User;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Read-only view of patient {@code users} for the admin panel. */
public interface AdminPatientUserRepository extends Repository<User, UUID>, JpaSpecificationExecutor<User> {

    Optional<User> findById(UUID id);

    List<User> findByIdIn(Collection<UUID> ids);

    long count();

    long countByCreatedAtAfter(OffsetDateTime since);

    /** Sign-ups per UTC day since {@code since}: each element is {@code [java.sql.Date day, Long count]}. */
    @Query(value = """
            SELECT CAST(date_trunc('day', created_at AT TIME ZONE 'UTC') AS date) AS day, COUNT(*)
              FROM users
             WHERE created_at >= :since
             GROUP BY day
             ORDER BY day
            """, nativeQuery = true)
    List<Object[]> signupsPerDay(@Param("since") OffsetDateTime since);

    /**
     * Health records logged per UTC day since {@code since}, across every log table — the
     * dashboard's "is the app actually being used" line.
     */
    @Query(value = """
            SELECT CAST(date_trunc('day', ts AT TIME ZONE 'UTC') AS date) AS day, COUNT(*)
              FROM (SELECT created_at AS ts FROM vitals_logs   WHERE created_at >= :since
                    UNION ALL
                    SELECT created_at FROM symptom_logs        WHERE created_at >= :since
                    UNION ALL
                    SELECT created_at FROM activity_logs       WHERE created_at >= :since
                    UNION ALL
                    SELECT created_at FROM dose_logs           WHERE created_at >= :since) t
             GROUP BY day
             ORDER BY day
            """, nativeQuery = true)
    List<Object[]> recordsPerDay(@Param("since") OffsetDateTime since);
}
