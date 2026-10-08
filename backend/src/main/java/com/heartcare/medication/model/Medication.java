package com.heartcare.medication.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "medications")
public class Medication {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String name;

    @Column(name = "dose_mg", nullable = false, precision = 8, scale = 2)
    private BigDecimal doseMg;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Frequency frequency;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "schedule_times", nullable = false)
    private List<String> scheduleTimes = new ArrayList<>();

    @Column(nullable = false)
    private boolean active = true;

    /** When the medication was last switched off; null while active. See V12 migration. */
    @Column(name = "deactivated_at")
    private OffsetDateTime deactivatedAt;

    @Column(name = "client_record_id")
    private UUID clientRecordId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public Medication() {
        // for JPA and service construction
    }

    @PrePersist
    void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
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

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public BigDecimal getDoseMg() {
        return doseMg;
    }

    public void setDoseMg(BigDecimal doseMg) {
        this.doseMg = doseMg;
    }

    public Frequency getFrequency() {
        return frequency;
    }

    public void setFrequency(Frequency frequency) {
        this.frequency = frequency;
    }

    public List<String> getScheduleTimes() {
        return scheduleTimes;
    }

    public void setScheduleTimes(List<String> scheduleTimes) {
        this.scheduleTimes = (scheduleTimes == null) ? new ArrayList<>() : scheduleTimes;
    }

    public boolean isActive() {
        return active;
    }

    /**
     * Also maintains {@link #deactivatedAt}: stamped on an active-to-inactive transition, cleared
     * on reactivation, and left alone when the state does not change (re-saving an inactive
     * medication must not move its deactivation date forward).
     */
    public void setActive(boolean active) {
        if (this.active && !active) {
            deactivatedAt = OffsetDateTime.now();
        } else if (active) {
            deactivatedAt = null;
        }
        this.active = active;
    }

    public OffsetDateTime getDeactivatedAt() {
        return deactivatedAt;
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

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
