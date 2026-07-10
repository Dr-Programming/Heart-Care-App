package com.heartcare.vitals.dto;

import com.heartcare.vitals.model.VitalType;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Map;

public record VitalLogResponse(
        String id,
        VitalType type,
        Map<String, BigDecimal> values,
        boolean flagged,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
