package com.heartcare.vitals;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Centralized clinical alert thresholds (FR-VIT-008). Adjust the {@link #RANGES}
 * map to tune bounds; this class is the single seam for later promotion to
 * {@code @ConfigurationProperties} without touching flag logic.
 */
@Component
public class VitalThresholds {

    /** Breach when value &le; low (if non-null) or value &ge; high (if non-null). */
    public record FlagRange(BigDecimal low, BigDecimal high) {
        public boolean breached(BigDecimal v) {
            return (low != null && v.compareTo(low) <= 0)
                    || (high != null && v.compareTo(high) >= 0);
        }
    }

    private static final Map<String, FlagRange> RANGES = Map.of(
            "systolic", new FlagRange(bd("90"), bd("180")),
            "diastolic", new FlagRange(bd("60"), bd("120")),
            "glucose", new FlagRange(bd("4.0"), bd("11.1")),
            "heartRate", new FlagRange(bd("40"), bd("120")),
            "bmi", new FlagRange(bd("18.5"), bd("30")),
            "ldl", new FlagRange(null, bd("4.9")),
            "total", new FlagRange(null, bd("7.5")),
            "hdl", new FlagRange(bd("1.0"), null));

    public boolean isFlagged(Map<String, BigDecimal> values) {
        return values.entrySet().stream().anyMatch(e -> {
            FlagRange range = RANGES.get(e.getKey());
            return range != null && e.getValue() != null && range.breached(e.getValue());
        });
    }

    private static BigDecimal bd(String s) {
        return new BigDecimal(s);
    }
}
