package com.heartcare.common.sync;

import java.time.OffsetDateTime;

/** Comparison helpers shared by SyncHandler implementations when deciding DUPLICATE vs CONFLICT. */
public final class SyncComparisons {

    private SyncComparisons() {
    }

    /**
     * True when {@code incoming} denotes the same moment as {@code stored}.
     *
     * <p>Two traps this closes:
     * <ul>
     *   <li>A null incoming value means the client never sent one and the server defaulted it on
     *       write — that is not a divergence, so it must not read as a conflict.
     *   <li>Comparison is by instant, never {@code OffsetDateTime.equals}, which is
     *       offset-sensitive: 2026-07-17T08:30+03:00 and 2026-07-17T05:30Z are the same moment and
     *       {@code equals} says otherwise. Getting this wrong reports CONFLICT for every record an
     *       Ethiopian (+03:00) phone sends. See docs/design/2026-07-17-sync-design.md §8.
     * </ul>
     */
    public static boolean sameInstant(OffsetDateTime stored, OffsetDateTime incoming) {
        if (incoming == null) {
            return true;
        }
        return stored != null && stored.toInstant().equals(incoming.toInstant());
    }
}
