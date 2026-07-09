package com.heartcare.medication.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "dose_logs")
public class DoseLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "medication_id", nullable = false)
    private UUID medicationId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "scheduled_time")
    private LocalTime scheduledTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private DoseStatus status;

    @Column(name = "logged_at", nullable = false)
    private OffsetDateTime loggedAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public DoseLog() {
        // for JPA and service construction
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public UUID getMedicationId() {
        return medicationId;
    }

    public void setMedicationId(UUID medicationId) {
        this.medicationId = medicationId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public LocalDate getScheduledDate() {
        return scheduledDate;
    }

    public void setScheduledDate(LocalDate scheduledDate) {
        this.scheduledDate = scheduledDate;
    }

    public LocalTime getScheduledTime() {
        return scheduledTime;
    }

    public void setScheduledTime(LocalTime scheduledTime) {
        this.scheduledTime = scheduledTime;
    }

    public DoseStatus getStatus() {
        return status;
    }

    public void setStatus(DoseStatus status) {
        this.status = status;
    }

    public OffsetDateTime getLoggedAt() {
        return loggedAt;
    }

    public void setLoggedAt(OffsetDateTime loggedAt) {
        this.loggedAt = loggedAt;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public UUID getClientRecordId() {
        return clientRecordId;
    }

    public void setClientRecordId(UUID clientRecordId) {
        this.clientRecordId = clientRecordId;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
