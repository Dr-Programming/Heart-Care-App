package com.heartcare.admin.repository;

import com.heartcare.activity.model.ActivityLog;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/** Read-only view of {@code ActivityLog} for the admin panel. Extends {@link Repository} rather than JpaRepository so it exposes no save methods. */
public interface AdminActivityRepository extends Repository<ActivityLog, UUID>, JpaSpecificationExecutor<ActivityLog> {

    long count();

    /** Rows per user, for the given users only: each element is {@code [UUID userId, Long count]}. */
    @Query("SELECT e.userId, COUNT(e) FROM ActivityLog e WHERE e.userId IN :userIds GROUP BY e.userId")
    List<Object[]> countByUserIds(@Param("userIds") Collection<UUID> userIds);
}
