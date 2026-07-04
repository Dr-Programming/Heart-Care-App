package com.heartcare.patient.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "patient_profiles")
public class PatientProfile {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "birth_year")
    private Integer birthYear;

    @Column(name = "preferred_language", length = 5)
    private String preferredLanguage;

    @Column(name = "height_cm")
    private Integer heightCm;

    @Column(name = "chd_stage", length = 50)
    private String chdStage;

    @Column(name = "disease_history")
    private String diseaseHistory;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "comorbidities", nullable = false)
    private List<String> comorbidities = new ArrayList<>();

    @Column(name = "management_plan")
    private String managementPlan;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "goals")
    private Goals goals;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected PatientProfile() {
        // for JPA
    }

    public PatientProfile(UUID userId) {
        this.userId = userId;
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

    public UUID getUserId() {
        return userId;
    }

    public Integer getBirthYear() {
        return birthYear;
    }

    public void setBirthYear(Integer birthYear) {
        this.birthYear = birthYear;
    }

    public String getPreferredLanguage() {
        return preferredLanguage;
    }

    public void setPreferredLanguage(String preferredLanguage) {
        this.preferredLanguage = preferredLanguage;
    }

    public Integer getHeightCm() {
        return heightCm;
    }

    public void setHeightCm(Integer heightCm) {
        this.heightCm = heightCm;
    }

    public String getChdStage() {
        return chdStage;
    }

    public void setChdStage(String chdStage) {
        this.chdStage = chdStage;
    }

    public String getDiseaseHistory() {
        return diseaseHistory;
    }

    public void setDiseaseHistory(String diseaseHistory) {
        this.diseaseHistory = diseaseHistory;
    }

    public List<String> getComorbidities() {
        return comorbidities;
    }

    public void setComorbidities(List<String> comorbidities) {
        this.comorbidities = (comorbidities == null) ? new ArrayList<>() : comorbidities;
    }

    public String getManagementPlan() {
        return managementPlan;
    }

    public void setManagementPlan(String managementPlan) {
        this.managementPlan = managementPlan;
    }

    public Goals getGoals() {
        return goals;
    }

    public void setGoals(Goals goals) {
        this.goals = goals;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
