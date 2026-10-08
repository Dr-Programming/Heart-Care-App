package com.heartcare.admin;

import com.heartcare.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;

import static com.heartcare.admin.AdminAuthControllerIntegrationTest.adminToken;
import static com.heartcare.admin.AdminAuthControllerIntegrationTest.patientToken;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AdminDataControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;
    String admin;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
        admin = adminToken(mockMvc);
    }

    private String asPatient(String token, String path, String json) throws Exception {
        MvcResult result = mockMvc.perform(post(path)
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk())
                .andReturn();
        return result.getResponse().getContentAsString();
    }

    private String userIdOf(String patientToken) throws Exception {
        MvcResult me = mockMvc.perform(get("/api/v1/auth/me").header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk()).andReturn();
        return JsonPath.read(me.getResponse().getContentAsString(), "$.data.id");
    }

    private org.springframework.test.web.servlet.ResultActions adminGet(String path) throws Exception {
        return mockMvc.perform(get(path).header("Authorization", "Bearer " + admin));
    }

    @Test
    void userListSearchesAndMasksPhone() throws Exception {
        String name = "Searchable " + UUID.randomUUID().toString().substring(0, 8);
        String token = patientToken(mockMvc, name);
        asPatient(token, "/api/v1/vitals", "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }");

        MvcResult result = adminGet("/api/v1/admin/users?q=" + name.substring(11))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].name").value(name))
                .andExpect(jsonPath("$.data.items[0].phoneMasked", startsWith("+2519")))
                .andExpect(jsonPath("$.data.items[0].counts.vitals").value(1))
                .andExpect(jsonPath("$.data.items[0].locked").value(false))
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andReturn();
        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain("pinHash").doesNotContain("pin_hash");
        assertThat((String) JsonPath.read(body, "$.data.items[0].phoneMasked")).contains("••••");
    }

    @Test
    void userDetailIncludesProfileAndFullPhone() throws Exception {
        String token = patientToken(mockMvc, "Detail Patient");
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"heightCm\": 170, \"chdStage\": \"B\", \"comorbidities\": [\"diabetes\"] }"))
                .andExpect(status().isOk());
        String userId = userIdOf(token);

        MvcResult result = adminGet("/api/v1/admin/users/" + userId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Detail Patient"))
                .andExpect(jsonPath("$.data.phone", startsWith("+251")))
                .andExpect(jsonPath("$.data.profile.heightCm").value(170))
                .andExpect(jsonPath("$.data.profile.comorbidities[0]").value("diabetes"))
                .andReturn();
        assertThat(result.getResponse().getContentAsString()).doesNotContain("pinHash");
    }

    @Test
    void unknownUserIs404AndBadIdIs400() throws Exception {
        adminGet("/api/v1/admin/users/" + UUID.randomUUID()).andExpect(status().isNotFound());
        adminGet("/api/v1/admin/users/not-a-uuid").andExpect(status().isBadRequest());
    }

    @Test
    void vitalsFilterByFlaggedPerUserAndAcrossUsers() throws Exception {
        String token = patientToken(mockMvc, "Vitals Patient");
        asPatient(token, "/api/v1/vitals", "{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 190, \"diastolic\": 100 } }");
        asPatient(token, "/api/v1/vitals", "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }");
        String userId = userIdOf(token);

        adminGet("/api/v1/admin/users/" + userId + "/vitals")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)));
        adminGet("/api/v1/admin/users/" + userId + "/vitals?flagged=true")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].type").value("BLOOD_PRESSURE"))
                .andExpect(jsonPath("$.data.items[0].userName").value("Vitals Patient"));
        adminGet("/api/v1/admin/users/" + userId + "/vitals?type=GLUCOSE")
                .andExpect(jsonPath("$.data.items", hasSize(1)));

        adminGet("/api/v1/admin/vitals?size=100")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[?(@.userId == '" + userId + "')]", hasSize(1)));
    }

    @Test
    void symptomsFilterByMinimumSeverity() throws Exception {
        String token = patientToken(mockMvc, "Symptom Patient");
        asPatient(token, "/api/v1/symptoms", """
                { "data": {
                    "chestPain": { "present": true, "severity": 8 },
                    "shortnessOfBreath": "MILD",
                    "heartRate": 82,
                    "bloodPressure": { "systolic": 165, "diastolic": 92 },
                    "swelling": true,
                    "energyLevel": 4
                }, "note": "tight chest", "measuredAt": "2026-07-01T09:00:00Z" }""");
        asPatient(token, "/api/v1/symptoms", """
                { "data": {
                    "chestPain": { "present": false },
                    "shortnessOfBreath": "NONE",
                    "heartRate": 70,
                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                    "swelling": false,
                    "energyLevel": 8
                } }""");
        String userId = userIdOf(token);

        adminGet("/api/v1/admin/users/" + userId + "/symptoms")
                .andExpect(jsonPath("$.data.items", hasSize(2)));
        adminGet("/api/v1/admin/users/" + userId + "/symptoms?minSeverity=URGENT")
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].overallSeverity").value("EMERGENCY"))
                .andExpect(jsonPath("$.data.items[0].note").value("tight chest"));
    }

    @Test
    void medicationsCarryDoseTallies() throws Exception {
        String token = patientToken(mockMvc, "Med Patient");
        String med = asPatient(token, "/api/v1/medications",
                "{ \"name\": \"Aspirin\", \"doseMg\": 81, \"frequency\": \"ONCE_DAILY\", \"scheduleTimes\": [\"08:00\"] }");
        String medId = JsonPath.read(med, "$.data.id");
        asPatient(token, "/api/v1/medications/" + medId + "/doses", "{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-01\", \"clientRecordId\": \"%s\" }".formatted(java.util.UUID.randomUUID()));
        asPatient(token, "/api/v1/medications/" + medId + "/doses", "{ \"status\": \"MISSED\", \"scheduledDate\": \"2026-07-02\", \"clientRecordId\": \"%s\" }".formatted(java.util.UUID.randomUUID()));
        String userId = userIdOf(token);

        adminGet("/api/v1/admin/users/" + userId + "/medications")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].name").value("Aspirin"))
                .andExpect(jsonPath("$.data[0].taken").value(1))
                .andExpect(jsonPath("$.data[0].missed").value(1));
        adminGet("/api/v1/admin/users/" + userId + "/dose-logs?status=MISSED")
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].medicationName").value("Aspirin"));
        adminGet("/api/v1/admin/users/" + userId + "/dose-logs?from=2026-07-02&to=2026-07-02")
                .andExpect(jsonPath("$.data.items", hasSize(1)));
    }

    @Test
    void activitiesArePaged() throws Exception {
        String token = patientToken(mockMvc, "Active Patient");
        for (int i = 0; i < 3; i++) {
            asPatient(token, "/api/v1/activities", "{ \"data\": { \"type\": \"WALKING\", \"durationMinutes\": 30, \"intensity\": \"MODERATE\" } }");
        }
        String userId = userIdOf(token);
        adminGet("/api/v1/admin/users/" + userId + "/activities?size=2")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.totalElements").value(3))
                .andExpect(jsonPath("$.data.totalPages").value(2));
    }

    @Test
    void statsCoverEveryTableAndThirtyDays() throws Exception {
        patientToken(mockMvc, "Stats Patient");
        adminGet("/api/v1/admin/stats")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totals.users", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.data.newUsersLast7Days", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.data.signupsPerDay", hasSize(AdminDataService.CHART_DAYS)))
                .andExpect(jsonPath("$.data.recordsPerDay", hasSize(AdminDataService.CHART_DAYS)));
    }

    @Test
    void invalidPagingIs400() throws Exception {
        adminGet("/api/v1/admin/users?size=101").andExpect(status().isBadRequest());
        adminGet("/api/v1/admin/users?page=-1").andExpect(status().isBadRequest());
        adminGet("/api/v1/admin/users?sort=pinHash").andExpect(status().isBadRequest());
        adminGet("/api/v1/admin/users?sort=createdAt,sideways").andExpect(status().isBadRequest());
        adminGet("/api/v1/admin/users?sort=fullName,asc").andExpect(status().isOk());
    }

    @Test
    void adminDataIsReadOnly() throws Exception {
        mockMvc.perform(post("/api/v1/admin/users").header("Authorization", "Bearer " + admin))
                .andExpect(status().isMethodNotAllowed());
    }
}
