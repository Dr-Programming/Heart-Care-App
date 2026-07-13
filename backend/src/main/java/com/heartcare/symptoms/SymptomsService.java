package com.heartcare.symptoms;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.symptoms.SymptomAssessment.Assessment;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.dto.SymptomLogResponse;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.symptoms.model.SymptomLog;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class SymptomsService {

    // Required check-in keys (worseThanYesterday is optional; assessment is server-owned).
    private static final Set<String> REQUIRED_KEYS = Set.of(
            "chestPain", "shortnessOfBreath", "heartRate", "bloodPressure", "swelling", "energyLevel");
    private static final Set<String> OPTIONAL_KEYS = Set.of("worseThanYesterday");
    private static final Set<String> SOB_LEVELS = Set.of("NONE", "MILD", "SEVERE");
    private static final Set<String> KNOWN_SYMPTOM_NAMES = Set.of(
            "chestPain", "shortnessOfBreath", "heartRate", "bloodPressure", "swelling", "energyLevel");

    // Sentinel bounds for open-ended date filters (safe within Postgres timestamptz range).
    private static final OffsetDateTime MIN_INSTANT = OffsetDateTime.of(1, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC);
    private static final OffsetDateTime MAX_INSTANT = OffsetDateTime.of(9999, 12, 31, 0, 0, 0, 0, ZoneOffset.UTC);

    private final SymptomsRepository symptomsRepository;
    private final SymptomAssessment assessment;

    public SymptomsService(SymptomsRepository symptomsRepository, SymptomAssessment assessment) {
        this.symptomsRepository = symptomsRepository;
        this.assessment = assessment;
    }

    @Transactional
    public SymptomLogResponse log(UUID userId, SymptomLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = symptomsRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, Object> data = validate(request.data());
        Assessment result = assessment.assess(data);

        SymptomLog log = new SymptomLog();
        log.setUserId(userId);
        log.setData(data);
        log.setAssessment(toAssessmentMap(result));
        log.setOverallSeverity(result.overall());
        log.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        log.setNote(request.note());
        log.setClientRecordId(request.clientRecordId());
        return toResponse(symptomsRepository.save(log));
    }

    @Transactional(readOnly = true)
    public List<SymptomLogResponse> history(UUID userId, LocalDate from, LocalDate to) {
        // Bucket calendar-date filters by UTC day; the query range is half-open [fromTs, toTs).
        OffsetDateTime fromTs = from == null ? MIN_INSTANT : from.atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        OffsetDateTime toTs = to == null ? MAX_INSTANT : to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toOffsetDateTime();
        return symptomsRepository.findHistory(userId, fromTs, toTs)
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

        validateChestPain(asMap(raw.get("chestPain"), "chestPain"));
        validateEnum(raw.get("shortnessOfBreath"), "shortnessOfBreath", SOB_LEVELS);
        intInRange(raw.get("heartRate"), "heartRate", 20, 300);
        validateBloodPressure(asMap(raw.get("bloodPressure"), "bloodPressure"));
        boolValue(raw.get("swelling"), "swelling");
        intInRange(raw.get("energyLevel"), "energyLevel", 0, 10);
        if (raw.containsKey("worseThanYesterday")) {
            validateWorseThanYesterday(asMap(raw.get("worseThanYesterday"), "worseThanYesterday"));
        }
        return raw;
    }

    private void validateChestPain(Map<String, Object> chestPain) {
        boolean present = boolValue(chestPain.get("present"), "chestPain.present");
        if (present) {
            if (!chestPain.containsKey("severity")) {
                throw new BadRequestException("chestPain.severity is required when present");
            }
            intInRange(chestPain.get("severity"), "chestPain.severity", 0, 10);
        }
    }

    private void validateBloodPressure(Map<String, Object> bp) {
        int systolic = intInRange(bp.get("systolic"), "systolic", 40, 300);
        int diastolic = intInRange(bp.get("diastolic"), "diastolic", 40, 300);
        if (systolic <= diastolic) {
            throw new BadRequestException("systolic must be greater than diastolic");
        }
    }

    private void validateWorseThanYesterday(Map<String, Object> worse) {
        for (Map.Entry<String, Object> entry : worse.entrySet()) {
            if (!KNOWN_SYMPTOM_NAMES.contains(entry.getKey())) {
                throw new BadRequestException("unknown symptom in worseThanYesterday: " + entry.getKey());
            }
            boolValue(entry.getValue(), "worseThanYesterday." + entry.getKey());
        }
    }

    private void validateEnum(Object value, String field, Set<String> allowed) {
        if (!(value instanceof String s) || !allowed.contains(s)) {
            throw new BadRequestException(field + " must be one of " + allowed);
        }
    }

    private int intInRange(Object value, String field, int min, int max) {
        if (!(value instanceof Number number)) {
            throw new BadRequestException(field + " must be a number");
        }
        double d = number.doubleValue();
        if (d != Math.rint(d)) {
            throw new BadRequestException(field + " must be a whole number");
        }
        int i = number.intValue();
        if (i < min || i > max) {
            throw new BadRequestException(field + " is out of range");
        }
        return i;
    }

    private boolean boolValue(Object value, String field) {
        if (!(value instanceof Boolean b)) {
            throw new BadRequestException(field + " must be true or false");
        }
        return b;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object value, String field) {
        if (!(value instanceof Map)) {
            throw new BadRequestException(field + " must be an object");
        }
        return (Map<String, Object>) value;
    }

    private Map<String, Object> toAssessmentMap(Assessment result) {
        Map<String, Object> symptoms = new LinkedHashMap<>();
        result.symptoms().forEach((k, v) -> symptoms.put(k, v.name()));
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("overall", result.overall().name());
        map.put("symptoms", symptoms);
        return map;
    }

    private SymptomLogResponse toResponse(SymptomLog log) {
        return new SymptomLogResponse(
                log.getId() == null ? null : log.getId().toString(),
                log.getData(),
                log.getAssessment(),
                log.getMeasuredAt(),
                log.getNote(),
                log.getClientRecordId() == null ? null : log.getClientRecordId().toString(),
                log.getCreatedAt());
    }
}
