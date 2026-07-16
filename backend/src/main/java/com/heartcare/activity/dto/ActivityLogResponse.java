package com.heartcare.activity.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record ActivityLogResponse(
        String id,
        Map<String, Object> data,
        OffsetDateTime measuredAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
