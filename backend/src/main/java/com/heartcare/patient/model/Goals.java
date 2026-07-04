package com.heartcare.patient.model;

import jakarta.validation.constraints.PositiveOrZero;

public record Goals(
        @PositiveOrZero(message = "bpSystolic must not be negative")
        Integer bpSystolic,

        @PositiveOrZero(message = "bpDiastolic must not be negative")
        Integer bpDiastolic,

        @PositiveOrZero(message = "totalCholesterol must not be negative")
        Integer totalCholesterol,

        @PositiveOrZero(message = "stepsPerDay must not be negative")
        Integer stepsPerDay,

        @PositiveOrZero(message = "targetWeightKg must not be negative")
        Integer targetWeightKg,

        String dietNote) {
}
