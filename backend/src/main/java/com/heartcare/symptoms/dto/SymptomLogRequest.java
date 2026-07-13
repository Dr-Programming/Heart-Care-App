package com.heartcare.symptoms.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record SymptomLogRequest(
        @NotNull(message = "data is required")
        Map<String, Object> data,

        OffsetDateTime measuredAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        UUID clientRecordId) {
}
