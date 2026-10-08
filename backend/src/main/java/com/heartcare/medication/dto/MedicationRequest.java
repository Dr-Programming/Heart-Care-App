package com.heartcare.medication.dto;

import com.heartcare.medication.model.Frequency;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@ScheduleMatchesFrequency
public record MedicationRequest(
        @NotBlank(message = "name is required")
        @Size(max = 255, message = "name must be at most 255 characters")
        String name,

        @NotNull(message = "doseMg is required")
        @Positive(message = "doseMg must be greater than 0")
        // Generous ceiling: no oral cardiac drug comes near 10 g per dose, but a slipped zero
        // (500 typed as 5000, or 50000) is a realistic typo that must not reach a schedule.
        @DecimalMax(value = "10000", message = "doseMg must be at most 10000")
        BigDecimal doseMg,

        @NotNull(message = "frequency is required")
        Frequency frequency,

        List<@Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$",
                message = "scheduleTimes entries must be HH:mm (24-hour)") String> scheduleTimes,

        Boolean active,

        UUID clientRecordId) {
}
