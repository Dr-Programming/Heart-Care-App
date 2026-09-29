package com.heartcare.research.model;

/** How much a researcher may see. Declaration order is the ranking: do not reorder. */
public enum AccessLevel {
    /** Suppressed aggregates only: counts, averages, distributions, trends. */
    AGGREGATE,
    /** Aggregates plus row-level records under per-researcher pseudonyms. */
    PSEUDONYMOUS
}
