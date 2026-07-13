package com.heartcare.symptoms;

import com.heartcare.symptoms.model.Severity;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Centralized clinical severity rules for the daily symptom check-in (FR-SYM-010).
 * Each private classifier is the single seam for tuning a symptom's bounds; the class
 * can later be promoted to {@code @ConfigurationProperties} without touching callers.
 *
 * <p>Assumes {@code data} has already been structurally validated by
 * {@code SymptomsService} (required keys present, correct types, ranges enforced).
 * The §4.3 bounds are documented defaults pending clinical sign-off.
 */
@Component
public class SymptomAssessment {

    /** Per-symptom severities plus the overall (max) level. */
    public record Assessment(Severity overall, Map<String, Severity> symptoms) {
    }

    public Assessment assess(Map<String, Object> data) {
        Map<String, Severity> symptoms = new LinkedHashMap<>();
        symptoms.put("chestPain", chestPain(asMap(data.get("chestPain"))));
        symptoms.put("shortnessOfBreath", shortnessOfBreath((String) data.get("shortnessOfBreath")));
        symptoms.put("bloodPressure", bloodPressure(asMap(data.get("bloodPressure"))));
        symptoms.put("heartRate", heartRate(asInt(data.get("heartRate"))));
        symptoms.put("swelling", swelling((Boolean) data.get("swelling")));
        symptoms.put("energyLevel", energyLevel(asInt(data.get("energyLevel"))));

        Severity overall = symptoms.values().stream()
                .max(Comparator.naturalOrder())
                .orElse(Severity.NONE);
        return new Assessment(overall, symptoms);
    }

    private Severity chestPain(Map<String, Object> chestPain) {
        if (!Boolean.TRUE.equals(chestPain.get("present"))) {
            return Severity.NONE;
        }
        int severity = asInt(chestPain.get("severity"));
        if (severity >= 7) {
            return Severity.EMERGENCY;
        }
        if (severity >= 4) {
            return Severity.URGENT;
        }
        if (severity >= 1) {
            return Severity.MONITOR;
        }
        return Severity.NONE;
    }

    private Severity shortnessOfBreath(String level) {
        return switch (level) {
            case "SEVERE" -> Severity.URGENT;
            case "MILD" -> Severity.MONITOR;
            default -> Severity.NONE; // "NONE"
        };
    }

    private Severity bloodPressure(Map<String, Object> bp) {
        int systolic = asInt(bp.get("systolic"));
        int diastolic = asInt(bp.get("diastolic"));
        if (systolic >= 180) {
            return Severity.EMERGENCY;
        }
        if (systolic >= 160 || systolic <= 90 || diastolic >= 100 || diastolic <= 60) {
            return Severity.URGENT;
        }
        return Severity.NONE;
    }

    private Severity heartRate(int heartRate) {
        return (heartRate < 40 || heartRate > 120) ? Severity.URGENT : Severity.NONE;
    }

    private Severity swelling(Boolean swelling) {
        return Boolean.TRUE.equals(swelling) ? Severity.MONITOR : Severity.NONE;
    }

    private Severity energyLevel(int energyLevel) {
        return energyLevel <= 2 ? Severity.MONITOR : Severity.NONE;
    }

    private static int asInt(Object value) {
        return ((Number) value).intValue();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value) {
        return (Map<String, Object>) value;
    }
}
