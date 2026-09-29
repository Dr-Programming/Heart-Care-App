package com.heartcare.research.model;

public enum ResearcherStatus {
    ACTIVE,
    REVOKED,
    /** "Deleted" by an admin: out of the working list, read-only, kept for audit. */
    ARCHIVED
}
