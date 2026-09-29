package com.heartcare.admin;

import com.heartcare.auth.model.User;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.UUID;

/**
 * Composable filters for the admin queries. Each returns null when its argument is null, and
 * {@link #all} skips nulls, so optional query parameters need no special casing at the call site.
 */
final class AdminSpecs {

    private AdminSpecs() {
    }

    /**
     * AND of the non-null specs. Written out rather than using Specification.allOf because the
     * null-handling of the built-in combinators has changed between Spring Data versions.
     */
    @SafeVarargs
    static <T> Specification<T> all(Specification<T>... specs) {
        List<Specification<T>> present = Arrays.stream(specs).filter(Objects::nonNull).toList();
        return (root, query, cb) -> cb.and(present.stream()
                .map(spec -> spec.toPredicate(root, query, cb))
                .filter(Objects::nonNull)
                .toArray(Predicate[]::new));
    }

    static <T> Specification<T> userIs(UUID userId) {
        return userId == null ? null : (root, q, cb) -> cb.equal(root.get("userId"), userId);
    }

    static <T> Specification<T> fieldEquals(String field, Object value) {
        return value == null ? null : (root, q, cb) -> cb.equal(root.get(field), value);
    }

    static <T> Specification<T> fieldIn(String field, Collection<?> values) {
        return values == null || values.isEmpty() ? null : (root, q, cb) -> root.get(field).in(values);
    }

    /** {@code from} and {@code to} are inclusive calendar days, interpreted in UTC. */
    static <T> Specification<T> instantBetween(String field, LocalDate from, LocalDate to) {
        OffsetDateTime start = from == null ? null : from.atStartOfDay().atOffset(ZoneOffset.UTC);
        OffsetDateTime end = to == null ? null : to.plusDays(1).atStartOfDay().atOffset(ZoneOffset.UTC);
        Specification<T> lower = start == null ? null
                : (root, q, cb) -> cb.greaterThanOrEqualTo(root.<OffsetDateTime>get(field), start);
        Specification<T> upper = end == null ? null
                : (root, q, cb) -> cb.lessThan(root.<OffsetDateTime>get(field), end);
        return all(lower, upper);
    }

    /** Inclusive range over a {@code LocalDate} column. */
    static <T> Specification<T> dateBetween(String field, LocalDate from, LocalDate to) {
        Specification<T> lower = from == null ? null
                : (root, q, cb) -> cb.greaterThanOrEqualTo(root.<LocalDate>get(field), from);
        Specification<T> upper = to == null ? null
                : (root, q, cb) -> cb.lessThanOrEqualTo(root.<LocalDate>get(field), to);
        return all(lower, upper);
    }

    /** Case-insensitive substring match on name, or a digit match anywhere in the phone. */
    static Specification<User> userMatches(String query) {
        if (query == null || query.isBlank()) {
            return null;
        }
        String needle = "%" + escapeLike(query.trim().toLowerCase(Locale.ROOT)) + "%";
        return (root, q, cb) -> cb.or(
                cb.like(cb.lower(root.get("fullName")), needle, '\\'),
                cb.like(root.get("phone"), needle, '\\'));
    }

    static Specification<User> lockedAt(OffsetDateTime now) {
        return (root, q, cb) -> cb.greaterThan(root.<OffsetDateTime>get("lockedUntil"), now);
    }

    private static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
