package com.heartcare.patient.dto;

import com.heartcare.patient.model.Goals;

import java.util.List;

public record PatientProfileResponse(
        String userId,
        Integer birthYear,
        String preferredLanguage,
        Integer heightCm,
        String chdStage,
        String diseaseHistory,
        List<String> comorbidities,
        String managementPlan,
        Goals goals) {
}
