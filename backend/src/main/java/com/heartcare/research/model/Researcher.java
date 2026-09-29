package com.heartcare.research.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * A researcher account. Identity fields (username, name, organisation) have no setters on
 * purpose: they are fixed by the admin at creation and nothing in the app can change them.
 */
@Entity
@Table(name = "researchers")
public class Researcher {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true, length = 64)
    private String username;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column
    private String organisation;

    @Column(name = "password_hash", nullable = false)
    @JsonIgnore
    private String passwordHash;

    @Column(name = "must_change_password", nullable = false)
    private boolean mustChangePassword = true;

    @Column(name = "self_changes_remaining", nullable = false)
    private int selfChangesRemaining = 1;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ResearcherStatus status = ResearcherStatus.ACTIVE;

    @Column(name = "token_version", nullable = false)
    private int tokenVersion;

    @Column(name = "created_by_admin_id")
    private UUID createdByAdminId;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "revoked_at")
    private OffsetDateTime revokedAt;

    @Column(name = "last_login_at")
    private OffsetDateTime lastLoginAt;

    @Column(name = "password_changed_at")
    private OffsetDateTime passwordChangedAt;

    @Column(name = "archived_at")
    private OffsetDateTime archivedAt;

    @Column(name = "archived_by")
    private UUID archivedBy;

    @Column(name = "archive_reason", length = 500)
    private String archiveReason;

    protected Researcher() {
        // for JPA
    }

    public Researcher(String username, String fullName, String organisation, String passwordHash, UUID createdByAdminId) {
        this.username = username;
        this.fullName = fullName;
        this.organisation = organisation;
        this.passwordHash = passwordHash;
        this.createdByAdminId = createdByAdminId;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }

    /** An admin issued a new password: the researcher must replace it once, and every open session ends. */
    public void issuePassword(String newHash) {
        this.passwordHash = newHash;
        this.mustChangePassword = true;
        this.selfChangesRemaining = 1;
        this.tokenVersion++;
    }

    /** The researcher's single self-service change. Callers check {@link #canSelfChangePassword()} first. */
    public void selfChangePassword(String newHash, OffsetDateTime at) {
        this.passwordHash = newHash;
        this.mustChangePassword = false;
        this.selfChangesRemaining = 0;
        this.passwordChangedAt = at;
    }

    public boolean canSelfChangePassword() {
        return selfChangesRemaining > 0;
    }

    public void revoke(OffsetDateTime at) {
        this.status = ResearcherStatus.REVOKED;
        this.revokedAt = at;
        this.tokenVersion++;
    }

    /** Admin "delete": ends every session and freezes the account for the audit archive. */
    public void archive(String reason, UUID adminId, OffsetDateTime at) {
        this.status = ResearcherStatus.ARCHIVED;
        this.archivedAt = at;
        this.archivedBy = adminId;
        this.archiveReason = reason;
        this.tokenVersion++;
    }

    /**
     * Back from the archive as REVOKED, never straight to ACTIVE: the admin then restores access
     * and issues a new password deliberately, with the usual actions.
     */
    public void unarchive(OffsetDateTime at) {
        this.status = ResearcherStatus.REVOKED;
        this.revokedAt = at;
        this.archivedAt = null;
        this.archivedBy = null;
        this.archiveReason = null;
    }

    public boolean isArchived() {
        return status == ResearcherStatus.ARCHIVED;
    }

    public void restore() {
        this.status = ResearcherStatus.ACTIVE;
        this.revokedAt = null;
        this.tokenVersion++;
    }

    public UUID getId() {
        return id;
    }

    public String getUsername() {
        return username;
    }

    public String getFullName() {
        return fullName;
    }

    public String getOrganisation() {
        return organisation;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public boolean isMustChangePassword() {
        return mustChangePassword;
    }

    public int getSelfChangesRemaining() {
        return selfChangesRemaining;
    }

    public ResearcherStatus getStatus() {
        return status;
    }

    public int getTokenVersion() {
        return tokenVersion;
    }

    public UUID getCreatedByAdminId() {
        return createdByAdminId;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getRevokedAt() {
        return revokedAt;
    }

    public OffsetDateTime getLastLoginAt() {
        return lastLoginAt;
    }

    public void setLastLoginAt(OffsetDateTime lastLoginAt) {
        this.lastLoginAt = lastLoginAt;
    }

    public OffsetDateTime getPasswordChangedAt() {
        return passwordChangedAt;
    }

    public OffsetDateTime getArchivedAt() {
        return archivedAt;
    }

    public UUID getArchivedBy() {
        return archivedBy;
    }

    public String getArchiveReason() {
        return archiveReason;
    }
}
