package com.heartcare.research.analytics;

import com.heartcare.symptoms.model.Severity;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * A group of patients described by filters. Every field is optional; an empty definition means
 * all patients. Demographic filters need the DEMOGRAPHICS dataset, and the others need the
 * dataset they look at, so a cohort can never be used to probe data outside the grant.
 */
public record CohortDefinition(
        /** e.g. ["40-49", "50-59"]; see {@link AgeBands#LABELS}. */
        @Size(max = 10) List<String> ageBands,
        @Size(max = 20) List<String> chdStages,
        @Size(max = 20) List<String> comorbidities,
        /** ANY (default) or ALL of {@code comorbidities}. */
        String comorbidityMatch,
        @Size(max = 5) List<String> languages,
        /** Currently or previously prescribed a medication whose name contains this text. */
        @Size(max = 100) String medicationName,
        /** At least one out-of-range vital inside the window. */
        Boolean hadFlaggedVital,
        /** At least one check-in at or above this severity inside the window. */
        Severity minSymptomSeverity) {

    public static final CohortDefinition ALL = new CohortDefinition(null, null, null, null, null, null, null, null);

    public boolean isEmpty() {
        return empty(ageBands) && empty(chdStages) && empty(comorbidities) && empty(languages)
                && (medicationName == null || medicationName.isBlank()) && hadFlaggedVital == null
                && minSymptomSeverity == null;
    }

    static boolean empty(List<?> l) {
        return l == null || l.isEmpty();
    }
}
