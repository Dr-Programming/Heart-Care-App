package com.heartcare.activity.model;

/**
 * Physical-activity intensity (FR-ACT-003), the standard CHD exercise-guidance scale.
 * Stored as its string value inside the activity_logs.data JSONB.
 */
public enum Intensity {
    LIGHT,
    MODERATE,
    VIGOROUS
}
