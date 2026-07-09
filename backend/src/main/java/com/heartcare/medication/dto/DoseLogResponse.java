package com.heartcare.medication.dto;

import com.heartcare.medication.model.DoseStatus;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

public record DoseLogResponse(
        String id,
        String medicationId,
        LocalDate scheduledDate,
        LocalTime scheduledTime,
        DoseStatus status,
        OffsetDateTime loggedAt,
        String note,
        String clientRecordId,
        OffsetDateTime createdAt) {
}
