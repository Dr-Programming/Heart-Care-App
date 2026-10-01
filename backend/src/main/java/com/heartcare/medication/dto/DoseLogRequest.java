package com.heartcare.medication.dto;

import com.heartcare.medication.model.DoseStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

public record DoseLogRequest(
        @NotNull(message = "status is required")
        DoseStatus status,

        @NotNull(message = "scheduledDate is required")
        LocalDate scheduledDate,

        LocalTime scheduledTime,

        OffsetDateTime loggedAt,

        @Size(max = 500, message = "note must be at most 500 characters")
        String note,

        // Required: the idempotency key is the only thing that stops a retried request (or a
        // replayed sync) from logging the same dose twice and inflating adherence (Issue 4).
        @NotNull(message = "clientRecordId is required")
        UUID clientRecordId) {
}
