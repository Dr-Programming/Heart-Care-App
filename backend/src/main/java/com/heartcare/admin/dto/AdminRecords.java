package com.heartcare.admin.dto;

import com.heartcare.medication.model.DoseStatus;
import com.heartcare.medication.model.Frequency;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.vitals.model.VitalType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * Row shapes for the admin record tables. {@code userId}/{@code userName} are always present so
 * the same shape serves both the per-patient tabs and the cross-patient triage lists.
 */
public final class AdminRecords {

    private AdminRecords() {
    }

    public record Vital(String id, String userId, String userName, VitalType type,
                        Map<String, BigDecimal> values, boolean flagged,
                        OffsetDateTime measuredAt, String note, OffsetDateTime createdAt) {
    }

    public record Symptom(String id, String userId, String userName, Severity overallSeverity,
                          Map<String, Object> data, Map<String, Object> assessment,
                          OffsetDateTime measuredAt, String note, OffsetDateTime createdAt) {
    }

    public record Activity(String id, String userId, String userName, Map<String, Object> data,
                           OffsetDateTime measuredAt, String note, OffsetDateTime createdAt) {
    }

    public record Dose(String id, String userId, String userName, String medicationId,
                       String medicationName, LocalDate scheduledDate, LocalTime scheduledTime,
                       DoseStatus status, OffsetDateTime loggedAt, String note) {
    }

    public record Medication(String id, String name, BigDecimal doseMg, Frequency frequency,
                             List<String> scheduleTimes, boolean active,
                             OffsetDateTime createdAt, OffsetDateTime updatedAt,
                             long taken, long missed, long skipped) {
    }
}
