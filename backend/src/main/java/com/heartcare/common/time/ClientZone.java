package com.heartcare.common.time;

import com.heartcare.common.exception.BadRequestException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;

/**
 * The calendar the patient lives in. Timestamps are stored as instants, but "today", "Sep 29" and
 * "one check-in per day" are local-calendar ideas: bucketing them by UTC puts an Ethiopian
 * (UTC+3) reading taken at 01:00 on the previous day.
 *
 * <p>The zone comes from the {@value #HEADER} request header (an IANA id such as
 * {@code Africa/Addis_Ababa}), read from the current request so services and sync handlers need
 * no extra parameter. A missing or unparseable header falls back to {@code app.time.default-zone}
 * rather than failing: an old app build that never sends it must keep working.
 */
@Component
public class ClientZone {

    public static final String HEADER = "X-Timezone";

    private final ZoneId defaultZone;
    private final Duration maxFutureSkew;
    private final Clock clock;

    @Autowired
    public ClientZone(@Value("${app.time.default-zone}") String defaultZone,
                      @Value("${app.time.max-future-skew-seconds}") long maxFutureSkewSeconds) {
        this(defaultZone, maxFutureSkewSeconds, Clock.systemUTC());
    }

    public ClientZone(String defaultZone, long maxFutureSkewSeconds, Clock clock) {
        this.defaultZone = ZoneId.of(defaultZone);
        this.maxFutureSkew = Duration.ofSeconds(maxFutureSkewSeconds);
        this.clock = clock;
    }

    public ZoneId zone() {
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes instanceof ServletRequestAttributes servlet) {
            String header = servlet.getRequest().getHeader(HEADER);
            if (header != null && !header.isBlank()) {
                try {
                    return ZoneId.of(header.trim());
                } catch (DateTimeException ex) {
                    // Fall through to the default; see class comment.
                }
            }
        }
        return defaultZone;
    }

    public LocalDate today() {
        return LocalDate.now(clock.withZone(zone()));
    }

    /** Local midnight of {@code date} in the client zone, as an instant. */
    public OffsetDateTime startOfDay(LocalDate date) {
        return date.atStartOfDay(zone()).toOffsetDateTime();
    }

    /** The client-zone calendar date on which {@code instant} fell. */
    public LocalDate localDateOf(OffsetDateTime instant) {
        return instant.atZoneSameInstant(zone()).toLocalDate();
    }

    public OffsetDateTime now() {
        return OffsetDateTime.now(clock);
    }

    /**
     * Health records describe something that already happened. A few minutes of slack absorbs
     * phone clocks that run fast; anything beyond that is a typo or a corrupt record.
     */
    public void assertNotFuture(OffsetDateTime value, String field) {
        if (value != null && value.toInstant().isAfter(clock.instant().plus(maxFutureSkew))) {
            throw new BadRequestException(field + " must not be in the future");
        }
    }

    public void assertNotFutureDate(LocalDate value, String field) {
        if (value != null && value.isAfter(today())) {
            throw new BadRequestException(field + " must not be in the future");
        }
    }
}
