package com.heartcare.admin.dto;

import java.time.OffsetDateTime;

/** One row of the user list. The phone is masked here; only the detail view shows it in full. */
public record AdminUserSummary(
        String id,
        String name,
        String phoneMasked,
        String preferredLanguage,
        OffsetDateTime createdAt,
        boolean locked,
        RecordCounts counts) {

    public record RecordCounts(long medications, long doseLogs, long vitals, long symptoms, long activities) {
    }
}
