package com.heartcare.activity.model;

/**
 * Curated set of loggable activity types (FR-ACT-003). Stored as its string value inside
 * the activity_logs.data JSONB; the client maps each constant to a localized EN/AM label.
 * OTHER plus the free-text note covers the long tail. Extending this list needs no migration.
 */
public enum ActivityType {
    WALKING,
    JOGGING,
    CYCLING,
    HOUSEHOLD,
    FARMING,
    STRETCHING,
    OTHER
}
