package com.heartcare.patient.dto;

import com.heartcare.patient.model.Goals;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public record PatientProfileRequest(
        @Min(value = 1900, message = "birthYear must be 1900 or later")
        @Max(value = 2100, message = "birthYear is out of range")
        Integer birthYear,

        @Pattern(regexp = "en|am", message = "preferredLanguage must be 'en' or 'am'")
        String preferredLanguage,

        @Min(value = 50, message = "heightCm must be at least 50")
        @Max(value = 250, message = "heightCm must be at most 250")
        Integer heightCm,

        @Size(max = 50, message = "chdStage must be at most 50 characters")
        String chdStage,

        String diseaseHistory,

        List<String> comorbidities,

        String managementPlan,

        @Valid
        Goals goals) {
}
