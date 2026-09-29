package com.heartcare.research.analytics;

import java.util.List;

/**
 * Birth year generalised to 10-year bands. Researchers never see a birth year or exact age;
 * the open-ended ends ("<30", "80+") keep outliers from standing out.
 */
public final class AgeBands {

    public static final List<String> LABELS = List.of("<30", "30-39", "40-49", "50-59", "60-69", "70-79", "80+");

    /** SQL for the band of profile alias {@code p}; NULL when the birth year is unknown. */
    public static final String SQL = """
            CASE
              WHEN p.birth_year IS NULL THEN NULL
              WHEN EXTRACT(YEAR FROM now())::int - p.birth_year < 30 THEN '<30'
              WHEN EXTRACT(YEAR FROM now())::int - p.birth_year >= 80 THEN '80+'
              ELSE ((EXTRACT(YEAR FROM now())::int - p.birth_year) / 10 * 10)::text || '-'
                   || ((EXTRACT(YEAR FROM now())::int - p.birth_year) / 10 * 10 + 9)::text
            END""";

    private AgeBands() {
    }
}
