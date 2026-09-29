package com.heartcare.admin.dto;

import com.heartcare.patient.model.Goals;

import java.time.OffsetDateTime;
import java.util.List;

public record AdminUserDetail(
        String id,
        String name,
        String phone,
        String preferredLanguage,
        String role,
        OffsetDateTime createdAt,
        int failedLoginAttempts,
        OffsetDateTime lockedUntil,
        AdminUserSummary.RecordCounts counts,
        Profile profile) {

    /** Null on the parent when the patient never filled in a profile. */
    public record Profile(
            Integer birthYear,
            String preferredLanguage,
            Integer heightCm,
            String chdStage,
            String diseaseHistory,
            List<String> comorbidities,
            String managementPlan,
            Goals goals,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt) {
    }
}
