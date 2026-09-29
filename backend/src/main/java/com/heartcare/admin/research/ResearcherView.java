package com.heartcare.admin.research;

import com.heartcare.research.dto.GrantView;
import com.heartcare.research.model.ResearcherStatus;

import java.time.OffsetDateTime;

/** A researcher account as the admin sees it. Never includes the password hash. */
public record ResearcherView(
        String id,
        String username,
        String fullName,
        String organisation,
        ResearcherStatus status,
        boolean expired,
        boolean mustChangePassword,
        boolean canChangePassword,
        OffsetDateTime passwordChangedAt,
        OffsetDateTime createdAt,
        String createdBy,
        OffsetDateTime revokedAt,
        OffsetDateTime lastLoginAt,
        GrantView grant,
        OffsetDateTime archivedAt,
        String archivedBy,
        String archiveReason) {
}
