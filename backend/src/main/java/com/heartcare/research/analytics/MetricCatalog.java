package com.heartcare.research.analytics;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.research.model.Dataset;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The fixed list of things a researcher can measure. Each metric is a whitelisted SQL fragment
 * over one table (aliased {@code t}); researchers pick metrics by id and never supply SQL.
 *
 * <p>Rate metrics are 0/100 per record, so their mean is a percentage and the same machinery
 * (describe, trend, correlation) works for them unchanged.
 */
public final class MetricCatalog {

    public enum Kind { MEASURE, RATE }

    /**
     * @param table     source table, aliased {@code t}; must have a {@code user_id} column
     * @param value     numeric SQL expression for one record's value
     * @param filter    SQL predicate selecting the records that carry this metric
     * @param timeSql   the record's timestamp/date column, used for the window and trends
     * @param dateTyped true when {@code timeSql} is a DATE (dose_logs) rather than TIMESTAMPTZ
     */
    public record Metric(String id, String label, String unit, Dataset dataset, Kind kind, String group,
                         String table, String value, String filter, String timeSql, boolean dateTyped) {
    }

    private static final Map<String, Metric> METRICS = new LinkedHashMap<>();

    static {
        vital("systolic", "Systolic blood pressure", "mmHg", "BLOOD_PRESSURE", "systolic");
        vital("diastolic", "Diastolic blood pressure", "mmHg", "BLOOD_PRESSURE", "diastolic");
        vital("glucose", "Blood glucose", "mmol/L", "GLUCOSE", "glucose");
        vital("heart_rate", "Resting heart rate", "bpm", "HEART_RATE", "heartRate");
        vital("weight", "Weight", "kg", "WEIGHT", "weight");
        vital("bmi", "Body mass index", "kg/m²", "WEIGHT", "bmi");
        vital("ldl", "LDL cholesterol", "mmol/L", "CHOLESTEROL", "ldl");
        vital("hdl", "HDL cholesterol", "mmol/L", "CHOLESTEROL", "hdl");
        vital("total_cholesterol", "Total cholesterol", "mmol/L", "CHOLESTEROL", "total");
        add(new Metric("vitals_out_of_range", "Vital readings out of range", "%", Dataset.VITALS, Kind.RATE, "Vitals",
                "vitals_logs", "CASE WHEN t.flagged THEN 100.0 ELSE 0.0 END", "TRUE", "t.measured_at", false));

        symptom("symptom_energy", "Energy level (check-in)", "0–10", "(t.data->>'energyLevel')::numeric",
                "t.data->>'energyLevel' IS NOT NULL", Kind.MEASURE);
        symptom("symptom_heart_rate", "Heart rate (check-in)", "bpm", "(t.data->>'heartRate')::numeric",
                "t.data->>'heartRate' IS NOT NULL", Kind.MEASURE);
        symptom("chest_pain_severity", "Chest pain severity, when present", "0–10",
                "(t.data->'chestPain'->>'severity')::numeric",
                "(t.data->'chestPain'->>'present') = 'true' AND t.data->'chestPain'->>'severity' IS NOT NULL", Kind.MEASURE);
        symptom("symptom_severity", "Assessed severity (0 none – 3 emergency)", "rank",
                "CASE t.overall_severity WHEN 'NONE' THEN 0 WHEN 'MONITOR' THEN 1 WHEN 'URGENT' THEN 2 ELSE 3 END",
                "TRUE", Kind.MEASURE);
        symptom("symptom_urgent", "Check-ins assessed urgent or emergency", "%",
                "CASE WHEN t.overall_severity IN ('URGENT', 'EMERGENCY') THEN 100.0 ELSE 0.0 END", "TRUE", Kind.RATE);

        activity("activity_minutes", "Activity duration", "min", "durationMinutes");
        activity("activity_steps", "Steps per activity", "steps", "steps");
        activity("activity_distance", "Distance per activity", "m", "distanceMeters");

        add(new Metric("dose_adherence", "Doses taken", "%", Dataset.MEDICATIONS, Kind.RATE, "Medications",
                "dose_logs", "CASE WHEN t.status = 'TAKEN' THEN 100.0 ELSE 0.0 END", "TRUE", "t.scheduled_date", true));
    }

    private MetricCatalog() {
    }

    private static void vital(String id, String label, String unit, String type, String key) {
        add(new Metric(id, label, unit, Dataset.VITALS, Kind.MEASURE, "Vitals", "vitals_logs",
                "(t.vital_values->>'" + key + "')::numeric",
                "t.type = '" + type + "' AND t.vital_values->>'" + key + "' IS NOT NULL", "t.measured_at", false));
    }

    private static void symptom(String id, String label, String unit, String value, String filter, Kind kind) {
        add(new Metric(id, label, unit, Dataset.SYMPTOMS, kind, "Symptoms", "symptom_logs", value, filter,
                "t.measured_at", false));
    }

    private static void activity(String id, String label, String unit, String key) {
        add(new Metric(id, label, unit, Dataset.ACTIVITY, Kind.MEASURE, "Activity", "activity_logs",
                "(t.data->>'" + key + "')::numeric", "t.data->>'" + key + "' IS NOT NULL", "t.measured_at", false));
    }

    private static void add(Metric m) {
        METRICS.put(m.id(), m);
    }

    public static Metric get(String id) {
        Metric m = id == null ? null : METRICS.get(id);
        if (m == null) {
            throw new BadRequestException("Unknown metric: " + id);
        }
        return m;
    }

    public static List<Metric> all() {
        return List.copyOf(METRICS.values());
    }
}
