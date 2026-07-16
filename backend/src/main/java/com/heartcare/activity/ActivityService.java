package com.heartcare.activity;

import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.dto.ActivityLogResponse;
import com.heartcare.activity.model.ActivityLog;
import com.heartcare.activity.model.ActivityType;
import com.heartcare.activity.model.Intensity;
import com.heartcare.common.exception.BadRequestException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ActivityService {

    private static final Set<String> REQUIRED_KEYS = Set.of("type", "durationMinutes", "intensity");
    private static final Set<String> OPTIONAL_KEYS = Set.of("steps", "distanceMeters");

    // Allowed enum string values, derived from the model enums (single source of truth).
    private static final Set<String> ACTIVITY_TYPES = Arrays.stream(ActivityType.values())
            .map(Enum::name).collect(Collectors.toUnmodifiableSet());
    private static final Set<String> INTENSITIES = Arrays.stream(Intensity.values())
            .map(Enum::name).collect(Collectors.toUnmodifiableSet());

    // Sentinel bounds for open-ended date filters (safe within Postgres timestamptz range).
    private static final OffsetDateTime MIN_INSTANT = OffsetDateTime.of(1, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC);
    private static final OffsetDateTime MAX_INSTANT = OffsetDateTime.of(9999, 12, 31, 0, 0, 0, 0, ZoneOffset.UTC);

    private final ActivityRepository activityRepository;

    public ActivityService(ActivityRepository activityRepository) {
        this.activityRepository = activityRepository;
    }

    @Transactional
    public ActivityLogResponse log(UUID userId, ActivityLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = activityRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, Object> data = validate(request.data());

        ActivityLog log = new ActivityLog();
        log.setUserId(userId);
        log.setData(data);
        log.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        log.setNote(request.note());
        log.setClientRecordId(request.clientRecordId());
        return toResponse(activityRepository.save(log));
    }

    @Transactional(readOnly = true)
    public List<ActivityLogResponse> history(UUID userId, LocalDate from, LocalDate to) {
        // Bucket calendar-date filters by UTC day; the query range is half-open [fromTs, toTs).
        OffsetDateTime fromTs = from == null ? MIN_INSTANT : from.atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        OffsetDateTime toTs = to == null ? MAX_INSTANT : to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        return activityRepository.findHistory(userId, fromTs, toTs)
                .stream().map(this::toResponse).toList();
    }

    private Map<String, Object> validate(Map<String, Object> raw) {
        if (raw == null) {
            throw new BadRequestException("data is required");
        }
        for (String key : raw.keySet()) {
            if (!REQUIRED_KEYS.contains(key) && !OPTIONAL_KEYS.contains(key)) {
                throw new BadRequestException("unknown key in data: " + key);
            }
        }
        for (String key : REQUIRED_KEYS) {
            if (!raw.containsKey(key)) {
                throw new BadRequestException("data must contain " + key);
            }
        }

        validateEnum(raw.get("type"), "type", ACTIVITY_TYPES);
        intInRange(raw.get("durationMinutes"), "durationMinutes", 1, 1440);
        validateEnum(raw.get("intensity"), "intensity", INTENSITIES);
        if (raw.containsKey("steps")) {
            intInRange(raw.get("steps"), "steps", 0, 100000);
        }
        if (raw.containsKey("distanceMeters")) {
            numberInRange(raw.get("distanceMeters"), "distanceMeters", 0, 100000);
        }
        return raw;
    }

    private void validateEnum(Object value, String field, Set<String> allowed) {
        if (!(value instanceof String s) || !allowed.contains(s)) {
            throw new BadRequestException(field + " must be one of " + allowed);
        }
    }

    private void intInRange(Object value, String field, int min, int max) {
        double d = numberInRange(value, field, min, max);
        if (d != Math.rint(d)) {
            throw new BadRequestException(field + " must be a whole number");
        }
    }

    private double numberInRange(Object value, String field, double min, double max) {
        if (!(value instanceof Number number)) {
            throw new BadRequestException(field + " must be a number");
        }
        double d = number.doubleValue();
        if (d < min || d > max) {
            throw new BadRequestException(field + " is out of range");
        }
        return d;
    }

    private ActivityLogResponse toResponse(ActivityLog log) {
        return new ActivityLogResponse(
                log.getId() == null ? null : log.getId().toString(),
                log.getData(),
                log.getMeasuredAt(),
                log.getNote(),
                log.getClientRecordId() == null ? null : log.getClientRecordId().toString(),
                log.getCreatedAt());
    }
}
