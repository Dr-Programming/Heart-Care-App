package com.heartcare.common.sync;

import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class SyncComparisonsTest {

    private static final OffsetDateTime ADDIS = OffsetDateTime.parse("2026-07-17T08:30:00+03:00");
    private static final OffsetDateTime SAME_MOMENT_UTC = OffsetDateTime.parse("2026-07-17T05:30:00Z");
    private static final OffsetDateTime LATER = OffsetDateTime.parse("2026-07-17T09:30:00+03:00");

    /** The trap: these are the same moment, but OffsetDateTime.equals returns false. */
    @Test
    void sameMomentInDifferentOffsetsIsEqual() {
        assertThat(ADDIS.equals(SAME_MOMENT_UTC)).isFalse();   // documents why this helper exists
        assertThat(SyncComparisons.sameInstant(ADDIS, SAME_MOMENT_UTC)).isTrue();
        assertThat(SyncComparisons.sameInstant(SAME_MOMENT_UTC, ADDIS)).isTrue();
    }

    @Test
    void differentMomentsAreNotEqual() {
        assertThat(SyncComparisons.sameInstant(ADDIS, LATER)).isFalse();
    }

    @Test
    void nullIncomingMeansTheServerDefaultedItAndIsNotADivergence() {
        assertThat(SyncComparisons.sameInstant(ADDIS, null)).isTrue();
    }

    @Test
    void nullStoredWithAnIncomingValueIsADivergence() {
        assertThat(SyncComparisons.sameInstant(null, ADDIS)).isFalse();
    }
}
