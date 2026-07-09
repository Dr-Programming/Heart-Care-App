package com.heartcare.medication.dto;

import com.heartcare.medication.model.Frequency;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record MedicationResponse(
        String id,
        String name,
        BigDecimal doseMg,
        Frequency frequency,
        List<String> scheduleTimes,
        boolean active,
        String clientRecordId,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {
}
