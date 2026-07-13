package com.heartcare.vitals;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class VitalThresholdsTest {

    private final VitalThresholds thresholds = new VitalThresholds();

    private static Map<String, BigDecimal> values(Object... kv) {
        Map<String, BigDecimal> m = new java.util.HashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put((String) kv[i], new BigDecimal(kv[i + 1].toString()));
        }
        return m;
    }

    @Test
    void normalBloodPressureNotFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 120, "diastolic", 80))).isFalse();
    }

    @Test
    void highSystolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 180, "diastolic", 80))).isTrue();
    }

    @Test
    void lowSystolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 90, "diastolic", 70))).isTrue();
    }

    @Test
    void highDiastolicFlagged() {
        assertThat(thresholds.isFlagged(values("systolic", 130, "diastolic", 120))).isTrue();
    }

    @Test
    void diastolicLowEdge() {
        assertThat(thresholds.isFlagged(values("systolic", 120, "diastolic", 60))).isTrue();
        assertThat(thresholds.isFlagged(values("systolic", 120, "diastolic", 61))).isFalse();
    }

    @Test
    void glucoseBoundaries() {
        assertThat(thresholds.isFlagged(values("glucose", "5.5"))).isFalse();
        assertThat(thresholds.isFlagged(values("glucose", "4.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("glucose", "11.1"))).isTrue();
    }

    @Test
    void heartRateBoundaries() {
        assertThat(thresholds.isFlagged(values("heartRate", 70))).isFalse();
        assertThat(thresholds.isFlagged(values("heartRate", 40))).isTrue();
        assertThat(thresholds.isFlagged(values("heartRate", 120))).isTrue();
    }

    @Test
    void weightWithoutBmiNeverFlagged() {
        assertThat(thresholds.isFlagged(values("weight", 200))).isFalse();
    }

    @Test
    void bmiBoundaries() {
        assertThat(thresholds.isFlagged(values("weight", 70, "bmi", "24.0"))).isFalse();
        assertThat(thresholds.isFlagged(values("weight", 120, "bmi", "30.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("weight", 45, "bmi", "17.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("weight", 50, "bmi", "18.5"))).isTrue();
        assertThat(thresholds.isFlagged(values("weight", 55, "bmi", "18.6"))).isFalse();
    }

    @Test
    void cholesterolFlags() {
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.5", "total", "5.0"))).isFalse();
        assertThat(thresholds.isFlagged(values("ldl", "4.9", "hdl", "1.5", "total", "5.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "0.9", "total", "5.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.5", "total", "7.5"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.0", "total", "5.0"))).isTrue();
        assertThat(thresholds.isFlagged(values("ldl", "3.0", "hdl", "1.1", "total", "5.0"))).isFalse();
    }
}
