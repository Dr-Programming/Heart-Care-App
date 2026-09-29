package com.heartcare.research.analytics;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.research.anon.ResearchScope;
import com.heartcare.research.model.Dataset;
import com.heartcare.symptoms.model.Severity;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/**
 * Compiles a {@link CohortDefinition} into a {@code cohort(user_id)} CTE. Every value is bound as
 * a parameter; only fixed fragments written here are concatenated into SQL.
 *
 * <p>Checks the grant too: a filter on a dataset the researcher cannot see is refused rather
 * than silently applied, because "how many patients match X" is itself information about X.
 */
final class CohortSql {

    private CohortSql() {
    }

    /**
     * @param params receives the bindings; {@code :wFrom}/{@code :wTo} (timestamps) must already be
     *               bound by the caller for the window-dependent filters
     */
    static String cte(CohortDefinition def, ResearchScope scope, MapSqlParameterSource params) {
        CohortDefinition d = def == null ? CohortDefinition.ALL : def;
        List<String> where = new ArrayList<>();
        where.add("u.role = 'PATIENT'");

        if (!CohortDefinition.empty(d.ageBands()) || !CohortDefinition.empty(d.chdStages())
                || !CohortDefinition.empty(d.comorbidities()) || !CohortDefinition.empty(d.languages())) {
            scope.require(Dataset.DEMOGRAPHICS);
        }
        if (!CohortDefinition.empty(d.ageBands())) {
            for (String band : d.ageBands()) {
                if (!AgeBands.LABELS.contains(band)) {
                    throw new BadRequestException("Unknown age band: " + band);
                }
            }
            where.add("(" + AgeBands.SQL + ") IN (:cAgeBands)");
            params.addValue("cAgeBands", d.ageBands());
        }
        if (!CohortDefinition.empty(d.chdStages())) {
            where.add("lower(p.chd_stage) IN (:cStages)");
            params.addValue("cStages", lower(d.chdStages()));
        }
        if (!CohortDefinition.empty(d.comorbidities())) {
            params.addValue("cComorb", lower(d.comorbidities()));
            if ("ALL".equalsIgnoreCase(d.comorbidityMatch())) {
                where.add("""
                        (SELECT COUNT(DISTINCT lower(c)) FROM jsonb_array_elements_text(p.comorbidities) c
                          WHERE lower(c) IN (:cComorb)) = :cComorbN""");
                params.addValue("cComorbN", d.comorbidities().stream().map(s -> s.toLowerCase(Locale.ROOT)).distinct().count());
            } else {
                where.add("""
                        EXISTS (SELECT 1 FROM jsonb_array_elements_text(p.comorbidities) c
                                 WHERE lower(c) IN (:cComorb))""");
            }
        }
        if (!CohortDefinition.empty(d.languages())) {
            where.add("u.preferred_language IN (:cLangs)");
            params.addValue("cLangs", d.languages());
        }
        if (d.medicationName() != null && !d.medicationName().isBlank()) {
            scope.require(Dataset.MEDICATIONS);
            where.add("EXISTS (SELECT 1 FROM medications m WHERE m.user_id = u.id AND lower(m.name) LIKE :cMed ESCAPE '\\')");
            params.addValue("cMed", "%" + escapeLike(d.medicationName().trim().toLowerCase(Locale.ROOT)) + "%");
        }
        if (Boolean.TRUE.equals(d.hadFlaggedVital())) {
            scope.require(Dataset.VITALS);
            where.add("""
                    EXISTS (SELECT 1 FROM vitals_logs fv WHERE fv.user_id = u.id AND fv.flagged
                             AND fv.measured_at >= :wFrom AND fv.measured_at < :wTo)""");
        }
        if (d.minSymptomSeverity() != null) {
            scope.require(Dataset.SYMPTOMS);
            where.add("""
                    EXISTS (SELECT 1 FROM symptom_logs fs WHERE fs.user_id = u.id AND fs.overall_severity IN (:cSev)
                             AND fs.measured_at >= :wFrom AND fs.measured_at < :wTo)""");
            params.addValue("cSev", Arrays.stream(Severity.values())
                    .filter(s -> s.compareTo(d.minSymptomSeverity()) >= 0).map(Enum::name).toList());
        }

        return """
                cohort AS (
                    SELECT u.id AS user_id
                      FROM users u
                      LEFT JOIN patient_profiles p ON p.user_id = u.id
                     WHERE %s
                )""".formatted(String.join("\n   AND ", where));
    }

    private static List<String> lower(List<String> values) {
        return values.stream().map(s -> s.trim().toLowerCase(Locale.ROOT)).toList();
    }

    private static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
