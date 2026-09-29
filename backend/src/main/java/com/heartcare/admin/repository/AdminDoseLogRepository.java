package com.heartcare.admin.repository;

import com.heartcare.medication.model.DoseLog;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/** Read-only view of {@code DoseLog} for the admin panel. Extends {@link Repository} rather than JpaRepository so it exposes no save methods. */
public interface AdminDoseLogRepository extends Repository<DoseLog, UUID>, JpaSpecificationExecutor<DoseLog> {

    long count();

    /** Rows per user, for the given users only: each element is {@code [UUID userId, Long count]}. */
    @Query("SELECT e.userId, COUNT(e) FROM DoseLog e WHERE e.userId IN :userIds GROUP BY e.userId")
    List<Object[]> countByUserIds(@Param("userIds") Collection<UUID> userIds);

    /** Status tally per medication: each element is {@code [UUID medicationId, DoseStatus status, Long count]}. */
    @Query("SELECT d.medicationId, d.status, COUNT(d) FROM DoseLog d WHERE d.userId = :userId GROUP BY d.medicationId, d.status")
    List<Object[]> statusCountsByMedication(@Param("userId") UUID userId);
}
