package com.heartcare.admin.dto;

import java.time.LocalDate;
import java.util.List;

public record AdminStatsResponse(
        Totals totals,
        long newUsersLast7Days,
        long newUsersLast30Days,
        long flaggedVitals,
        long urgentSymptoms,
        long lockedAccounts,
        List<DayCount> signupsPerDay,
        List<DayCount> recordsPerDay) {

    public record Totals(long users, long patientProfiles, long medications, long doseLogs,
                         long vitals, long symptoms, long activities) {
    }

    public record DayCount(LocalDate day, long count) {
    }
}
