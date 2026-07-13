package com.heartcare.symptoms.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record SymptomLogResponse(
        String id,
        Map<String, Object> data,
        Map<String, Object> assessment,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
