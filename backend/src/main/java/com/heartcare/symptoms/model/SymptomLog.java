package com.heartcare.symptoms.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "symptom_logs")
public class SymptomLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "data", nullable = false)
    private Map<String, Object> data = new HashMap<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "assessment", nullable = false)
    private Map<String, Object> assessment = new HashMap<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "overall_severity", nullable = false, length = 20)
    private Severity overallSeverity;

    @Column(name = "measured_at", nullable = false)
    private OffsetDateTime measuredAt;

    @Column(name = "note")
    private String note;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public SymptomLog() {
        // for JPA and service construction
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now(ZoneOffset.UTC);
        }
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public Map<String, Object> getData() {
        return data;
    }

    public void setData(Map<String, Object> data) {
        this.data = (data == null) ? new HashMap<>() : data;
    }

    public Map<String, Object> getAssessment() {
        return assessment;
    }

    public void setAssessment(Map<String, Object> assessment) {
        this.assessment = (assessment == null) ? new HashMap<>() : assessment;
    }

    public Severity getOverallSeverity() {
        return overallSeverity;
    }

    public void setOverallSeverity(Severity overallSeverity) {
        this.overallSeverity = overallSeverity;
    }

    public OffsetDateTime getMeasuredAt() {
        return measuredAt;
    }

    public void setMeasuredAt(OffsetDateTime measuredAt) {
        this.measuredAt = measuredAt;
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
