package com.heartcare.common.time;

import com.heartcare.common.exception.BadRequestException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ClientZoneTest {

    // 2026-09-28T22:30Z is already 01:30 on Sep 29 in Addis Ababa (UTC+3).
    private static final Instant NOW = Instant.parse("2026-09-28T22:30:00Z");
    private final ClientZone clientZone =
            new ClientZone("Africa/Addis_Ababa", 300, Clock.fixed(NOW, ZoneOffset.UTC));

    @AfterEach
    void clearRequest() {
        RequestContextHolder.resetRequestAttributes();
    }

    private void withHeader(String value) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        if (value != null) {
            request.addHeader(ClientZone.HEADER, value);
        }
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }

    @Test
    void fallsBackToDefaultZoneOutsideARequest() {
        assertThat(clientZone.zone()).isEqualTo(ZoneId.of("Africa/Addis_Ababa"));
    }

    @Test
    void usesTheHeaderZoneWhenValid() {
        withHeader("Europe/London");
        assertThat(clientZone.zone()).isEqualTo(ZoneId.of("Europe/London"));
    }

    @Test
    void ignoresAnInvalidHeaderZone() {
        withHeader("Not/AZone");
        assertThat(clientZone.zone()).isEqualTo(ZoneId.of("Africa/Addis_Ababa"));
    }

    @Test
    void todayIsTheLocalDateInTheClientZone() {
        assertThat(clientZone.today()).isEqualTo(LocalDate.of(2026, 9, 29));
        withHeader("UTC");
        assertThat(clientZone.today()).isEqualTo(LocalDate.of(2026, 9, 28));
    }

    @Test
    void startOfDayIsLocalMidnight() {
        assertThat(clientZone.startOfDay(LocalDate.of(2026, 9, 29)).toInstant())
                .isEqualTo(Instant.parse("2026-09-28T21:00:00Z"));
    }

    @Test
    void localDateOfConvertsAnInstantIntoTheClientZone() {
        assertThat(clientZone.localDateOf(OffsetDateTime.parse("2026-09-28T22:00:00Z")))
                .isEqualTo(LocalDate.of(2026, 9, 29));
    }

    @Test
    void assertNotFutureAllowsSmallClockDrift() {
        assertThatCode(() -> clientZone.assertNotFuture(
                OffsetDateTime.ofInstant(NOW.plusSeconds(299), ZoneOffset.UTC), "measuredAt"))
                .doesNotThrowAnyException();
    }

    @Test
    void assertNotFutureRejectsFutureTimestamps() {
        assertThatThrownBy(() -> clientZone.assertNotFuture(
                OffsetDateTime.parse("2099-12-31T09:00:00Z"), "measuredAt"))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("measuredAt");
    }

    @Test
    void assertNotFutureIgnoresNull() {
        assertThatCode(() -> clientZone.assertNotFuture(null, "measuredAt")).doesNotThrowAnyException();
    }
}
