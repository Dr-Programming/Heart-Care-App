package com.heartcare.auth.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;

    @Column(name = "pin_hash", nullable = false)
    @JsonIgnore
    private String pinHash;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "preferred_language", nullable = false, length = 2)
    private String preferredLanguage = "en";

    @Column(nullable = false, length = 20)
    private String role = "PATIENT";

    /** Consecutive failed login attempts; reset to 0 by any successful login. */
    @Column(name = "failed_login_attempts", nullable = false)
    private int failedLoginAttempts;

    /** When non-null and in the future, login is refused with 423 without checking the PIN. */
    @Column(name = "locked_until")
    private OffsetDateTime lockedUntil;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected User() {
        // for JPA
    }

    public User(String phone, String pinHash, String fullName, String preferredLanguage) {
        this.phone = phone;
        this.pinHash = pinHash;
        this.fullName = fullName;
        this.preferredLanguage = preferredLanguage;
        this.role = "PATIENT";
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

    public String getPhone() {
        return phone;
    }

    public String getPinHash() {
        return pinHash;
    }

    public String getFullName() {
        return fullName;
    }

    public String getPreferredLanguage() {
        return preferredLanguage;
    }

    public String getRole() {
        return role;
    }

    public int getFailedLoginAttempts() {
        return failedLoginAttempts;
    }

    public OffsetDateTime getLockedUntil() {
        return lockedUntil;
    }
}
