package com.heartcare.research.anon;

import com.heartcare.common.exception.ForbiddenException;
import com.heartcare.research.auth.ResearchContext;
import com.heartcare.research.model.AccessLevel;
import com.heartcare.research.model.Dataset;
import com.heartcare.research.model.ResearcherGrant;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Set;
import java.util.UUID;

/**
 * What the current researcher may see, derived from their grant on every request. All research
 * queries take a scope; nothing reads the grant directly, so every limit is applied in one place.
 */
public record ResearchScope(
        UUID researcherId,
        AccessLevel level,
        Set<Dataset> datasets,
        boolean exportAllowed,
        LocalDate grantFrom,
        LocalDate grantTo,
        int k) {

    /** Stand-ins for "unbounded" so window parameters are always bound with a concrete type. */
    static final LocalDate MIN_DATE = LocalDate.of(1900, 1, 1);
    static final LocalDate MAX_DATE = LocalDate.of(2999, 12, 31);

    public static ResearchScope of(ResearchContext ctx) {
        ResearcherGrant g = ctx.grant();
        return new ResearchScope(ctx.researcher().getId(), g.getAccessLevel(), g.datasets(), g.isExportAllowed(),
                g.getDataFrom(), g.getDataTo(), ctx.minGroupSize());
    }

    public boolean has(Dataset d) {
        return datasets.contains(d);
    }

    public void require(Dataset d) {
        if (!has(d)) {
            throw new ForbiddenException("DATASET_NOT_GRANTED",
                    "Your access doesn't include " + d.name().toLowerCase() + " data. Ask your administrator to add it.");
        }
    }

    public void requirePseudonymous() {
        if (level != AccessLevel.PSEUDONYMOUS) {
            throw new ForbiddenException("RECORDS_NOT_GRANTED",
                    "Your access is limited to aggregate results. Ask your administrator for record-level access.");
        }
    }

    public void requireExport() {
        if (!exportAllowed) {
            throw new ForbiddenException("EXPORT_NOT_GRANTED",
                    "Your access doesn't include downloading data. Ask your administrator to allow exports.");
        }
    }

    /** The requested window narrowed to the granted one. A request can never widen access. */
    public Window window(LocalDate from, LocalDate to) {
        LocalDate lo = max(grantFrom, from);
        LocalDate hi = min(grantTo, to);
        LocalDate effectiveFrom = lo == null ? MIN_DATE : lo;
        LocalDate effectiveTo = hi == null ? MAX_DATE : hi;
        return new Window(effectiveFrom, effectiveTo, lo, hi);
    }

    /**
     * Inclusive calendar days in UTC. {@code shownFrom}/{@code shownTo} are what to report back
     * (null when unbounded); {@code from}/{@code to} are always concrete for SQL binding.
     */
    public record Window(LocalDate from, LocalDate to, LocalDate shownFrom, LocalDate shownTo) {

        public OffsetDateTime startInstant() {
            return from.atStartOfDay().atOffset(ZoneOffset.UTC);
        }

        /** Exclusive upper bound. */
        public OffsetDateTime endInstant() {
            return to.plusDays(1).atStartOfDay().atOffset(ZoneOffset.UTC);
        }
    }

    private static LocalDate max(LocalDate a, LocalDate b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isAfter(b) ? a : b;
    }

    private static LocalDate min(LocalDate a, LocalDate b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isBefore(b) ? a : b;
    }
}
