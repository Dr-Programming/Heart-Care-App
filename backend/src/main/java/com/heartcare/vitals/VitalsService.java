package com.heartcare.vitals;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.patient.PatientProfileRepository;
import com.heartcare.patient.model.PatientProfile;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalLog;
import com.heartcare.vitals.model.VitalType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class VitalsService {

    private static final Map<VitalType, Set<String>> REQUIRED_KEYS = Map.of(
            VitalType.BLOOD_PRESSURE, Set.of("systolic", "diastolic"),
            VitalType.GLUCOSE, Set.of("glucose"),
            VitalType.HEART_RATE, Set.of("heartRate"),
            VitalType.WEIGHT, Set.of("weight"),
            VitalType.CHOLESTEROL, Set.of("ldl", "hdl", "total"));

    // Input-sanity ranges (reject typos/garbage); distinct from clinical flag thresholds.
    private static final Map<String, BigDecimal[]> SANE_RANGE = Map.of(
            "systolic", range(40, 300),
            "diastolic", range(40, 300),
            "glucose", range(0, 50),
            "heartRate", range(20, 300),
            "weight", range(0, 500),
            "ldl", range(0, 30),
            "hdl", range(0, 30),
            "total", range(0, 30));

    private final VitalsRepository vitalsRepository;
    private final PatientProfileRepository profileRepository;
    private final VitalThresholds thresholds;

    public VitalsService(VitalsRepository vitalsRepository,
                         PatientProfileRepository profileRepository,
                         VitalThresholds thresholds) {
        this.vitalsRepository = vitalsRepository;
        this.profileRepository = profileRepository;
        this.thresholds = thresholds;
    }

    @Transactional
    public VitalLogResponse log(UUID userId, VitalLogRequest request) {
        if (request.clientRecordId() != null) {
            var existing = vitalsRepository.findByUserIdAndClientRecordId(userId, request.clientRecordId());
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        Map<String, BigDecimal> values = validateAndClean(request.type(), request.values());

        if (request.type() == VitalType.WEIGHT) {
            Integer heightCm = profileRepository.findById(userId)
                    .map(PatientProfile::getHeightCm)
                    .orElse(null);
            if (heightCm != null) {
                values.put("bmi", computeBmi(values.get("weight"), heightCm));
            }
        }

        VitalLog vital = new VitalLog();
        vital.setUserId(userId);
        vital.setType(request.type());
        vital.setValues(values);
        vital.setFlagged(thresholds.isFlagged(values));
        vital.setMeasuredAt(request.measuredAt() == null
                ? OffsetDateTime.now(ZoneOffset.UTC) : request.measuredAt());
        vital.setNote(request.note());
        vital.setClientRecordId(request.clientRecordId());
        return toResponse(vitalsRepository.save(vital));
    }

    @Transactional(readOnly = true)
    public List<VitalLogResponse> history(UUID userId, VitalType type, LocalDate from, LocalDate to) {
        return vitalsRepository.findHistory(userId, from, to, type)
                .stream().map(this::toResponse).toList();
    }

    private Map<String, BigDecimal> validateAndClean(VitalType type, Map<String, BigDecimal> raw) {
        if (raw == null) {
            throw new BadRequestException("values is required");
        }
        Map<String, BigDecimal> values = new HashMap<>(raw);
        values.remove("bmi"); // server-owned; ignored if the client sends it

        Set<String> required = REQUIRED_KEYS.get(type);
        if (!values.keySet().equals(required)) {
            throw new BadRequestException("values for " + type + " must contain exactly " + required);
        }
        for (Map.Entry<String, BigDecimal> entry : values.entrySet()) {
            BigDecimal value = entry.getValue();
            if (value == null) {
                throw new BadRequestException(entry.getKey() + " must be a number");
            }
            BigDecimal[] sane = SANE_RANGE.get(entry.getKey());
            if (value.compareTo(sane[0]) < 0 || value.compareTo(sane[1]) > 0) {
                throw new BadRequestException(entry.getKey() + " is out of range");
            }
        }
        if (type == VitalType.BLOOD_PRESSURE
                && values.get("systolic").compareTo(values.get("diastolic")) <= 0) {
            throw new BadRequestException("systolic must be greater than diastolic");
        }
        return values;
    }

    private BigDecimal computeBmi(BigDecimal weightKg, int heightCm) {
        BigDecimal heightM = BigDecimal.valueOf(heightCm).movePointLeft(2); // cm -> m
        return weightKg.divide(heightM.multiply(heightM), 1, RoundingMode.HALF_UP);
    }

    private VitalLogResponse toResponse(VitalLog v) {
        return new VitalLogResponse(
                v.getId() == null ? null : v.getId().toString(),
                v.getType(),
                v.getValues(),
                v.isFlagged(),
                v.getMeasuredAt(),
                v.getNote(),
                v.getClientRecordId() == null ? null : v.getClientRecordId().toString(),
                v.getCreatedAt());
    }

    private static BigDecimal[] range(int low, int high) {
        return new BigDecimal[]{BigDecimal.valueOf(low), BigDecimal.valueOf(high)};
    }
}
