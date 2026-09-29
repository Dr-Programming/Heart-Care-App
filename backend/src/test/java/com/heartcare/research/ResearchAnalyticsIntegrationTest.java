package com.heartcare.research;

import com.heartcare.TestUsers;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.closeTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Analytics correctness, suppression and anonymisation, against a fixture of six patients who
 * share a unique comorbidity tag, so cohort filters isolate them from other tests' data.
 *
 * <p>Patient i (0..5): born 1970, 170 cm; one March-2026 BP reading of (120 + 10i)/80; one
 * activity of (10 + 10i) minutes; ten doses with 3, 3, 6, 6, 9, 9 taken; patients 0-2 report
 * chest pain (EMERGENCY), 3-5 a benign check-in. Patient 0 alone also has a rare comorbidity.
 */
class ResearchAnalyticsIntegrationTest extends ResearchTestSupport {

    private static final String WINDOW = "\"from\": \"2026-03-01\", \"to\": \"2026-03-31\"";
    private static final String SECRET_NOTE = "secret-note-do-not-leak";

    private static String tag;
    private static String rareTag;
    private static final List<String> names = new ArrayList<>();
    private static final List<String> phones = new ArrayList<>();
    private static final List<String> userIds = new ArrayList<>();

    private String pseudonymous;

    @BeforeEach
    void fixture() throws Exception {
        if (tag == null) {
            tag = "fx" + UUID.randomUUID().toString().substring(0, 8);
            rareTag = "rare" + UUID.randomUUID().toString().substring(0, 8);
            for (int i = 0; i < 6; i++) {
                seedPatient(i);
            }
        }
        pseudonymous = readyResearcher(grantJson("PSEUDONYMOUS", allDatasets(), true, null, null, null));
    }

    private void seedPatient(int i) throws Exception {
        String name = "Fixture Person " + i + " " + tag;
        String phone = TestUsers.nextPhone();
        MvcResult reg = mockMvc.perform(post("/api/v1/auth/register").contentType(APPLICATION_JSON)
                        .content("{ \"phone\": \"%s\", \"pin\": \"1234\", \"name\": \"%s\", \"preferredLanguage\": \"en\" }"
                                .formatted(phone, name)))
                .andExpect(status().isOk()).andReturn();
        String token = JsonPath.read(reg.getResponse().getContentAsString(), "$.data.token");
        userIds.add(JsonPath.read(reg.getResponse().getContentAsString(), "$.data.user.id"));
        names.add(name);
        phones.add(phone);
        String auth = "Bearer " + token;

        String comorbidities = i == 0 ? "[\"%s\", \"%s\"]".formatted(tag, rareTag) : "[\"%s\"]".formatted(tag);
        mockMvc.perform(put("/api/v1/patients/me").header("Authorization", auth).contentType(APPLICATION_JSON)
                        .content("{ \"birthYear\": 1970, \"heightCm\": 170, \"chdStage\": \"B\", \"comorbidities\": %s, \"diseaseHistory\": \"%s\" }"
                                .formatted(comorbidities, SECRET_NOTE)))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/vitals").header("Authorization", auth).contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": %d, \"diastolic\": 80 }, \"measuredAt\": \"2026-03-10T09:00:00Z\", \"note\": \"%s\" }"
                                .formatted(120 + 10 * i, SECRET_NOTE)))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/activities").header("Authorization", auth).contentType(APPLICATION_JSON)
                        .content("{ \"data\": { \"type\": \"WALKING\", \"durationMinutes\": %d, \"intensity\": \"MODERATE\" }, \"measuredAt\": \"2026-03-11T09:00:00Z\" }"
                                .formatted(10 + 10 * i)))
                .andExpect(status().isOk());
        String symptom = i < 3
                ? "{ \"chestPain\": { \"present\": true, \"severity\": 8 }, \"shortnessOfBreath\": \"MILD\", \"heartRate\": 82, \"bloodPressure\": { \"systolic\": 165, \"diastolic\": 92 }, \"swelling\": true, \"energyLevel\": 4 }"
                : "{ \"chestPain\": { \"present\": false }, \"shortnessOfBreath\": \"NONE\", \"heartRate\": 70, \"bloodPressure\": { \"systolic\": 120, \"diastolic\": 80 }, \"swelling\": false, \"energyLevel\": 8 }";
        mockMvc.perform(post("/api/v1/symptoms").header("Authorization", auth).contentType(APPLICATION_JSON)
                        .content("{ \"data\": %s, \"measuredAt\": \"2026-03-12T09:00:00Z\" }".formatted(symptom)))
                .andExpect(status().isOk());

        MvcResult med = mockMvc.perform(post("/api/v1/medications").header("Authorization", auth).contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Atorvastatin\", \"doseMg\": 20, \"frequency\": \"ONCE_DAILY\", \"scheduleTimes\": [\"08:00\"] }"))
                .andExpect(status().isOk()).andReturn();
        String medId = JsonPath.read(med.getResponse().getContentAsString(), "$.data.id");
        int taken = new int[]{3, 3, 6, 6, 9, 9}[i];
        for (int d = 1; d <= 10; d++) {
            mockMvc.perform(post("/api/v1/medications/" + medId + "/doses").header("Authorization", auth)
                            .contentType(APPLICATION_JSON)
                            .content("{ \"status\": \"%s\", \"scheduledDate\": \"2026-03-%02d\" }".formatted(d <= taken ? "TAKEN" : "MISSED", d)))
                    .andExpect(status().isOk());
        }
    }

    private String cohort() {
        return "{ \"comorbidities\": [\"%s\"] }".formatted(tag);
    }

    private void setK(int k) throws Exception {
        adminPut("/api/v1/admin/research-settings", "{ \"minGroupSize\": " + k + " }").andExpect(status().isOk());
    }

    @Test
    void cohortPreviewCountsAndSuppresses() throws Exception {
        researchPost(pseudonymous, "/api/v1/research/cohorts/preview", "{ \"definition\": %s, %s }".formatted(cohort(), WINDOW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.size").value(6))
                .andExpect(jsonPath("$.data.suppressed").value(false));
        researchPost(pseudonymous, "/api/v1/research/cohorts/preview",
                "{ \"definition\": { \"comorbidities\": [\"%s\"], \"minSymptomSeverity\": \"EMERGENCY\" }, %s }".formatted(tag, WINDOW))
                .andExpect(jsonPath("$.data.size").doesNotExist())
                .andExpect(jsonPath("$.data.suppressed").value(true));
        researchPost(pseudonymous, "/api/v1/research/cohorts/preview",
                "{ \"definition\": { \"comorbidities\": [\"%s\"], \"ageBands\": [\"70-79\"] } }".formatted(tag))
                .andExpect(jsonPath("$.data.size").value(0))
                .andExpect(jsonPath("$.data.suppressed").value(false));
    }

    @Test
    void describeComputesKnownStatistics() throws Exception {
        researchPost(pseudonymous, "/api/v1/research/analytics/describe",
                "{ \"metric\": \"systolic\", \"cohort\": %s, %s, \"groupBy\": \"AGE_BAND\" }".formatted(cohort(), WINDOW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.overall.readings").value(6))
                .andExpect(jsonPath("$.data.overall.patients").value(6))
                .andExpect(jsonPath("$.data.overall.mean").value(145.0))
                .andExpect(jsonPath("$.data.overall.median").value(145.0))
                .andExpect(jsonPath("$.data.overall.sd", closeTo(18.71, 0.01)))
                .andExpect(jsonPath("$.data.histogram", hasSize(12)))
                .andExpect(jsonPath("$.data.groups[0].group").value("50-59"))
                .andExpect(jsonPath("$.data.groups[0].stats.patients").value(6));
    }

    @Test
    void smallGroupsAreSuppressedAndKIsAdminControlled() throws Exception {
        String emergencyCohort = "{ \"comorbidities\": [\"%s\"], \"minSymptomSeverity\": \"EMERGENCY\" }".formatted(tag);
        String body = "{ \"metric\": \"systolic\", \"cohort\": %s, %s }".formatted(emergencyCohort, WINDOW);
        researchPost(pseudonymous, "/api/v1/research/analytics/describe", body)
                .andExpect(jsonPath("$.data.overall.suppressed").value(true))
                .andExpect(jsonPath("$.data.overall.mean").doesNotExist());
        try {
            setK(3);
            researchPost(pseudonymous, "/api/v1/research/analytics/describe", body)
                    .andExpect(jsonPath("$.data.k").value(3))
                    .andExpect(jsonPath("$.data.overall.suppressed").value(false))
                    .andExpect(jsonPath("$.data.overall.mean").value(130.0));
        } finally {
            setK(5);
        }
    }

    @Test
    void grantWindowCannotBeWidenedByTheRequest() throws Exception {
        String april = readyResearcher(grantJson("AGGREGATE", allDatasets(), false, "2026-04-01", null, null));
        researchPost(april, "/api/v1/research/analytics/describe",
                "{ \"metric\": \"systolic\", \"cohort\": %s, \"from\": \"2026-01-01\" }".formatted(cohort()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.window.from").value("2026-04-01"))
                .andExpect(jsonPath("$.data.overall.patients").value(0));
    }

    @Test
    void trendBucketsByMonth() throws Exception {
        researchPost(pseudonymous, "/api/v1/research/analytics/trend",
                "{ \"metric\": \"systolic\", \"period\": \"MONTH\", %s, \"cohorts\": [{ \"label\": \"Tagged\", \"definition\": %s }] }"
                        .formatted(WINDOW, cohort()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.series[0].label").value("Tagged"))
                .andExpect(jsonPath("$.data.series[0].points", hasSize(1)))
                .andExpect(jsonPath("$.data.series[0].points[0].period").value("2026-03-01"))
                .andExpect(jsonPath("$.data.series[0].points[0].mean").value(145.0));
    }

    @Test
    void correlationGivesPseudonymousPointsOrAnAggregateGrid() throws Exception {
        String body = "{ \"metricX\": \"systolic\", \"metricY\": \"activity_minutes\", \"cohort\": %s, %s }".formatted(cohort(), WINDOW);
        researchPost(pseudonymous, "/api/v1/research/analytics/correlation", body)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.patients").value(6))
                .andExpect(jsonPath("$.data.r").value(1.0))
                .andExpect(jsonPath("$.data.points", hasSize(6)))
                .andExpect(jsonPath("$.data.points[0].patient", startsWith("P-")))
                .andExpect(jsonPath("$.data.grid").doesNotExist());

        String aggregate = readyResearcher(grantJson("AGGREGATE", allDatasets(), false, null, null, null));
        researchPost(aggregate, "/api/v1/research/analytics/correlation", body)
                .andExpect(jsonPath("$.data.r").value(1.0))
                .andExpect(jsonPath("$.data.points").doesNotExist())
                .andExpect(jsonPath("$.data.grid.counts", hasSize(5)));
    }

    @Test
    void adherenceBandsLineUpWithBloodPressure() throws Exception {
        try {
            setK(2);
            researchPost(pseudonymous, "/api/v1/research/analytics/adherence-outcomes", "{ \"cohort\": %s, %s }".formatted(cohort(), WINDOW))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.bands[0].patients").value(2))
                    .andExpect(jsonPath("$.data.bands[0].meanAdherence").value(30.0))
                    .andExpect(jsonPath("$.data.bands[0].meanSystolic").value(125.0))
                    .andExpect(jsonPath("$.data.bands[1].meanAdherence").value(60.0))
                    .andExpect(jsonPath("$.data.bands[1].meanSystolic").value(145.0))
                    .andExpect(jsonPath("$.data.bands[2].meanAdherence").value(90.0))
                    .andExpect(jsonPath("$.data.bands[2].meanSystolic").value(165.0))
                    .andExpect(jsonPath("$.data.bands[2].pctUrgentCheckins").value(0.0));
        } finally {
            setK(5);
        }
        researchPost(pseudonymous, "/api/v1/research/analytics/adherence-outcomes", "{ \"cohort\": %s, %s }".formatted(cohort(), WINDOW))
                .andExpect(jsonPath("$.data.bands[0].suppressed").value(true));
    }

    @Test
    void severityMixPerMonth() throws Exception {
        researchPost(pseudonymous, "/api/v1/research/analytics/severity",
                "{ \"period\": \"MONTH\", \"cohort\": %s, %s }".formatted(cohort(), WINDOW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.buckets[0].checkins").value(6))
                .andExpect(jsonPath("$.data.buckets[0].counts.EMERGENCY").value(3))
                .andExpect(jsonPath("$.data.buckets[0].counts.NONE").value(3));
    }

    @Test
    void recordsArePseudonymousAndLeakNothingIdentifying() throws Exception {
        List<String> bodies = new ArrayList<>();
        for (String ds : List.of("vitals", "symptoms", "activity", "medications", "demographics")) {
            MvcResult r = researchPost(pseudonymous, "/api/v1/research/records/" + ds,
                    "{ \"cohort\": %s, %s, \"size\": 100 }".formatted(cohort(), WINDOW))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.rows[0].patient").value(org.hamcrest.Matchers.matchesPattern("^P-[A-Z2-9]{8}$")))
                    .andReturn();
            bodies.add(r.getResponse().getContentAsString());
        }
        String all = String.join("\n", bodies);
        for (int i = 0; i < 6; i++) {
            assertThat(all).doesNotContain(names.get(i)).doesNotContain(phones.get(i)).doesNotContain(userIds.get(i));
        }
        assertThat(all).doesNotContain(SECRET_NOTE).doesNotContain("1970").doesNotContain("birthYear");

        String demographics = bodies.get(4);
        assertThat((List<String>) JsonPath.read(demographics, "$.data.rows[*].ageBand")).containsOnly("50-59");
        assertThat((List<Integer>) JsonPath.read(demographics, "$.data.rows[*].heightCm")).containsOnly(170);
    }

    @Test
    void pseudonymsAreStablePerResearcherButDifferBetweenResearchers() throws Exception {
        Set<String> first = pseudonyms(pseudonymous);
        Set<String> again = pseudonyms(pseudonymous);
        String other = readyResearcher(grantJson("PSEUDONYMOUS", allDatasets(), false, null, null, null));
        Set<String> theirs = pseudonyms(other);
        assertThat(first).hasSize(6).isEqualTo(again);
        assertThat(theirs).hasSize(6).doesNotContainAnyElementsOf(first);
    }

    private Set<String> pseudonyms(String token) throws Exception {
        MvcResult r = researchPost(token, "/api/v1/research/records/vitals",
                "{ \"cohort\": %s, %s, \"size\": 100 }".formatted(cohort(), WINDOW)).andReturn();
        return new HashSet<>(JsonPath.<List<String>>read(r.getResponse().getContentAsString(), "$.data.rows[*].patient"));
    }

    @Test
    void recordsForSmallCohortsAreRefused() throws Exception {
        researchPost(pseudonymous, "/api/v1/research/records/vitals",
                "{ \"cohort\": { \"comorbidities\": [\"%s\"], \"minSymptomSeverity\": \"EMERGENCY\" }, %s }".formatted(tag, WINDOW))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("COHORT_TOO_SMALL"));
    }

    @Test
    void csvExportWhenAllowed() throws Exception {
        MvcResult r = researchPost(pseudonymous, "/api/v1/research/records/vitals?format=csv",
                "{ \"cohort\": %s, %s }".formatted(cohort(), WINDOW))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("attachment")))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andReturn();
        String csv = r.getResponse().getContentAsString();
        assertThat(csv.lines().count()).isEqualTo(7);
        assertThat(csv.lines().findFirst().orElseThrow()).contains("\"patient\"").contains("\"values.systolic\"");
        assertThat(csv).doesNotContain(SECRET_NOTE);

        researchPost(pseudonymous, "/api/v1/research/analytics/describe?format=csv",
                "{ \"metric\": \"systolic\", \"cohort\": %s, %s }".formatted(cohort(), WINDOW))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"));
    }

    @Test
    void catalogOnlyOffersCategoryValuesSharedByKPatients() throws Exception {
        MvcResult r = researchGet(pseudonymous, "/api/v1/research/catalog").andExpect(status().isOk()).andReturn();
        List<String> comorbidities = JsonPath.read(r.getResponse().getContentAsString(), "$.data.cohortFields.comorbidities");
        assertThat(comorbidities).contains(tag).doesNotContain(rareTag);
    }

    @Test
    void savedCohortsBelongToTheirResearcher() throws Exception {
        MvcResult saved = researchPost(pseudonymous, "/api/v1/research/cohorts",
                "{ \"name\": \"Tagged\", \"definition\": %s }".formatted(cohort()))
                .andExpect(status().isOk()).andReturn();
        String id = JsonPath.read(saved.getResponse().getContentAsString(), "$.data.id");
        researchGet(pseudonymous, "/api/v1/research/cohorts")
                .andExpect(jsonPath("$.data[?(@.id == '" + id + "')].name").value("Tagged"));

        String other = readyResearcher(grantJson("AGGREGATE", allDatasets(), false, null, null, null));
        researchGet(other, "/api/v1/research/cohorts").andExpect(jsonPath("$.data", hasSize(0)));
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .delete("/api/v1/research/cohorts/" + id).header("Authorization", "Bearer " + other))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/api/v1/research/cohorts").header("Authorization", "Bearer " + pseudonymous))
                .andExpect(jsonPath("$.data[?(@.id == '" + id + "')]", hasSize(1)));
    }
}
