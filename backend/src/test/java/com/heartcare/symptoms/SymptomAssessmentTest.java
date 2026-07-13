package com.heartcare.symptoms;

import com.heartcare.symptoms.SymptomAssessment.Assessment;
import com.heartcare.symptoms.model.Severity;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class SymptomAssessmentTest {

    private final SymptomAssessment assessment = new SymptomAssessment();

    /** A fully benign check-in; individual tests override single fields. */
    private static Map<String, Object> benign() {
        Map<String, Object> data = new HashMap<>();
        data.put("chestPain", Map.of("present", false));
        data.put("shortnessOfBreath", "NONE");
        data.put("heartRate", 70);
        data.put("bloodPressure", Map.of("systolic", 120, "diastolic", 80));
        data.put("swelling", false);
        data.put("energyLevel", 8);
        return data;
    }

    @Test
    void allBenignIsNone() {
        Assessment result = assessment.assess(benign());
        assertThat(result.overall()).isEqualTo(Severity.NONE);
        assertThat(result.symptoms()).containsAllEntriesOf(Map.of(
                "chestPain", Severity.NONE,
                "shortnessOfBreath", Severity.NONE,
                "bloodPressure", Severity.NONE,
                "heartRate", Severity.NONE,
                "swelling", Severity.NONE,
                "energyLevel", Severity.NONE));
    }

    @Test
    void chestPainSeverityBoundaries() {
        assertThat(chestPain(0)).isEqualTo(Severity.NONE);
        assertThat(chestPain(1)).isEqualTo(Severity.MONITOR);
        assertThat(chestPain(3)).isEqualTo(Severity.MONITOR);
        assertThat(chestPain(4)).isEqualTo(Severity.URGENT);
        assertThat(chestPain(6)).isEqualTo(Severity.URGENT);
        assertThat(chestPain(7)).isEqualTo(Severity.EMERGENCY);
        assertThat(chestPain(10)).isEqualTo(Severity.EMERGENCY);
    }

    @Test
    void chestPainNotPresentIsNone() {
        Map<String, Object> data = benign();
        data.put("chestPain", Map.of("present", false));
        assertThat(assessment.assess(data).symptoms().get("chestPain")).isEqualTo(Severity.NONE);
    }

    @Test
    void shortnessOfBreathLevels() {
        assertThat(sob("NONE")).isEqualTo(Severity.NONE);
        assertThat(sob("MILD")).isEqualTo(Severity.MONITOR);
        assertThat(sob("SEVERE")).isEqualTo(Severity.URGENT);
    }

    @Test
    void bloodPressureLevels() {
        assertThat(bp(120, 80)).isEqualTo(Severity.NONE);
        assertThat(bp(160, 80)).isEqualTo(Severity.URGENT);   // systolic >= 160
        assertThat(bp(90, 80)).isEqualTo(Severity.URGENT);    // systolic <= 90
        assertThat(bp(140, 100)).isEqualTo(Severity.URGENT);  // diastolic >= 100
        assertThat(bp(140, 60)).isEqualTo(Severity.URGENT);   // diastolic <= 60
        assertThat(bp(180, 80)).isEqualTo(Severity.EMERGENCY); // systolic >= 180
    }

    @Test
    void heartRateLevels() {
        assertThat(hr(70)).isEqualTo(Severity.NONE);
        assertThat(hr(40)).isEqualTo(Severity.NONE);   // 40 is not < 40
        assertThat(hr(39)).isEqualTo(Severity.URGENT);
        assertThat(hr(120)).isEqualTo(Severity.NONE);  // 120 is not > 120
        assertThat(hr(121)).isEqualTo(Severity.URGENT);
    }

    @Test
    void swellingAndEnergyAreMonitorLevel() {
        Map<String, Object> swollen = benign();
        swollen.put("swelling", true);
        assertThat(assessment.assess(swollen).symptoms().get("swelling")).isEqualTo(Severity.MONITOR);

        assertThat(energy(2)).isEqualTo(Severity.MONITOR);
        assertThat(energy(3)).isEqualTo(Severity.NONE);
    }

    @Test
    void overallIsMaxAcrossSymptoms() {
        Map<String, Object> data = benign();
        data.put("swelling", true);                              // MONITOR
        data.put("chestPain", Map.of("present", true, "severity", 8)); // EMERGENCY
        Assessment result = assessment.assess(data);
        assertThat(result.overall()).isEqualTo(Severity.EMERGENCY);
    }

    // --- helpers: mutate one field of a benign check-in and read its classification ---

    private Severity chestPain(int severity) {
        Map<String, Object> data = benign();
        data.put("chestPain", Map.of("present", true, "severity", severity));
        return assessment.assess(data).symptoms().get("chestPain");
    }

    private Severity sob(String level) {
        Map<String, Object> data = benign();
        data.put("shortnessOfBreath", level);
        return assessment.assess(data).symptoms().get("shortnessOfBreath");
    }

    private Severity bp(int systolic, int diastolic) {
        Map<String, Object> data = benign();
        data.put("bloodPressure", Map.of("systolic", systolic, "diastolic", diastolic));
        return assessment.assess(data).symptoms().get("bloodPressure");
    }

    private Severity hr(int rate) {
        Map<String, Object> data = benign();
        data.put("heartRate", rate);
        return assessment.assess(data).symptoms().get("heartRate");
    }

    private Severity energy(int level) {
        Map<String, Object> data = benign();
        data.put("energyLevel", level);
        return assessment.assess(data).symptoms().get("energyLevel");
    }
}
