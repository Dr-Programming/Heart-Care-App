package com.heartcare.symptoms.model;

/**
 * Clinical urgency of a symptom or check-in (FR-SYM-010). Declaration order IS the
 * ranking: NONE &lt; MONITOR &lt; URGENT &lt; EMERGENCY. "Overall" severity is the max
 * (via Comparator.naturalOrder() over ordinals). Do not reorder these constants.
 */
public enum Severity {
    NONE,
    MONITOR,
    URGENT,
    EMERGENCY
}
