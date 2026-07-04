package com.heartcare.patient.model;

public record Goals(
        Integer bpSystolic,
        Integer bpDiastolic,
        Integer totalCholesterol,
        Integer stepsPerDay,
        Integer targetWeightKg,
        String dietNote) {
}
