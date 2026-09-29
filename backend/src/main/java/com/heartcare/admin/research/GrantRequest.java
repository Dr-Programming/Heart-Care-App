package com.heartcare.admin.research;

import com.heartcare.research.model.AccessLevel;
import com.heartcare.research.model.Dataset;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Set;

public record GrantRequest(
        @NotNull(message = "accessLevel is required")
        AccessLevel accessLevel,

        @NotNull(message = "datasets is required")
        Set<Dataset> datasets,

        boolean exportAllowed,

        /** Inclusive; null means no lower bound. */
        LocalDate dataFrom,

        /** Inclusive; null means no upper bound. */
        LocalDate dataTo,

        /** Access ends at this instant; null means no expiry. */
        OffsetDateTime expiresAt) {
}
