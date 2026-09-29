package com.heartcare.research.dto;

import java.time.OffsetDateTime;

/** Read-only: researchers can see their account but no endpoint lets them edit it. */
public record ResearcherMe(
        String id,
        String username,
        String fullName,
        String organisation,
        boolean mustChangePassword,
        boolean canChangePassword,
        OffsetDateTime passwordChangedAt,
        OffsetDateTime lastLoginAt,
        GrantView grant,
        int minGroupSize) {
}
