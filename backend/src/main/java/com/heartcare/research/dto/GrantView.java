package com.heartcare.research.dto;

import com.heartcare.research.model.AccessLevel;
import com.heartcare.research.model.Dataset;
import com.heartcare.research.model.ResearcherGrant;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Set;

/** A researcher's grant as both apps display it. */
public record GrantView(
        AccessLevel accessLevel,
        Set<Dataset> datasets,
        boolean exportAllowed,
        LocalDate dataFrom,
        LocalDate dataTo,
        OffsetDateTime expiresAt,
        OffsetDateTime updatedAt) {

    public static GrantView of(ResearcherGrant g) {
        return new GrantView(g.getAccessLevel(), g.datasets(), g.isExportAllowed(), g.getDataFrom(),
                g.getDataTo(), g.getExpiresAt(), g.getUpdatedAt());
    }
}
