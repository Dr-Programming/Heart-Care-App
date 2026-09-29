package com.heartcare.research.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

/** What one researcher may see. Everything defaults to "nothing": an admin must opt each piece in. */
@Entity
@Table(name = "researcher_grants")
public class ResearcherGrant {

    @Id
    @Column(name = "researcher_id")
    private UUID researcherId;

    @Enumerated(EnumType.STRING)
    @Column(name = "access_level", nullable = false, length = 15)
    private AccessLevel accessLevel = AccessLevel.AGGREGATE;

    @Column(name = "ds_vitals", nullable = false)
    private boolean vitals;

    @Column(name = "ds_symptoms", nullable = false)
    private boolean symptoms;

    @Column(name = "ds_activity", nullable = false)
    private boolean activity;

    @Column(name = "ds_medications", nullable = false)
    private boolean medications;

    @Column(name = "ds_demographics", nullable = false)
    private boolean demographics;

    @Column(name = "export_allowed", nullable = false)
    private boolean exportAllowed;

    @Column(name = "data_from")
    private LocalDate dataFrom;

    @Column(name = "data_to")
    private LocalDate dataTo;

    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @Column(name = "updated_by")
    private UUID updatedBy;

    protected ResearcherGrant() {
        // for JPA
    }

    public ResearcherGrant(UUID researcherId) {
        this.researcherId = researcherId;
    }

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = OffsetDateTime.now();
    }

    public void update(AccessLevel accessLevel, Set<Dataset> datasets, boolean exportAllowed,
                       LocalDate dataFrom, LocalDate dataTo, OffsetDateTime expiresAt, UUID adminId) {
        this.accessLevel = accessLevel;
        this.vitals = datasets.contains(Dataset.VITALS);
        this.symptoms = datasets.contains(Dataset.SYMPTOMS);
        this.activity = datasets.contains(Dataset.ACTIVITY);
        this.medications = datasets.contains(Dataset.MEDICATIONS);
        this.demographics = datasets.contains(Dataset.DEMOGRAPHICS);
        this.exportAllowed = exportAllowed;
        this.dataFrom = dataFrom;
        this.dataTo = dataTo;
        this.expiresAt = expiresAt;
        this.updatedBy = adminId;
    }

    public Set<Dataset> datasets() {
        EnumSet<Dataset> set = EnumSet.noneOf(Dataset.class);
        if (vitals) set.add(Dataset.VITALS);
        if (symptoms) set.add(Dataset.SYMPTOMS);
        if (activity) set.add(Dataset.ACTIVITY);
        if (medications) set.add(Dataset.MEDICATIONS);
        if (demographics) set.add(Dataset.DEMOGRAPHICS);
        return set;
    }

    public boolean isExpired(OffsetDateTime now) {
        return expiresAt != null && !expiresAt.isAfter(now);
    }

    public UUID getResearcherId() {
        return researcherId;
    }

    public AccessLevel getAccessLevel() {
        return accessLevel;
    }

    public boolean isExportAllowed() {
        return exportAllowed;
    }

    public LocalDate getDataFrom() {
        return dataFrom;
    }

    public LocalDate getDataTo() {
        return dataTo;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
