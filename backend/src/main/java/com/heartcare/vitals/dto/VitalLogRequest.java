package com.heartcare.vitals.dto;

import com.heartcare.vitals.model.VitalType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record VitalLogRequest(
        @NotNull(message = "type is required")
        VitalType type,

        @NotNull(message = "values is required")
        Map<String, BigDecimal> values,

        OffsetDateTime measuredAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
