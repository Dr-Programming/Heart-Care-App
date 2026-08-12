package com.heartcare.patient;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PatientControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    final ObjectMapper objectMapper = new ObjectMapper();

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    /** Registers a fresh user via the real auth endpoint and returns its JWT. */
    private String registerAndGetToken() throws Exception {
        ObjectNode body = objectMapper.createObjectNode();
        body.put("phone", TestUsers.nextPhone());
        body.put("pin", "1234");
        body.put("name", "Abebe");
        body.put("preferredLanguage", "en");

        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body.toString()))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    @Test
    void getProfileWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/patients/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void getProfileBeforeAnySaveReturnsEmptySkeleton() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(get("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.userId").exists())
                .andExpect(jsonPath("$.data.birthYear").doesNotExist())
                .andExpect(jsonPath("$.data.comorbidities").isArray())
                .andExpect(jsonPath("$.data.comorbidities").isEmpty());
    }

    @Test
    void putThenGetReturnsSavedProfile() throws Exception {
        String token = registerAndGetToken();

        String putBody = """
                {
                  "birthYear": 1975,
                  "preferredLanguage": "am",
                  "heightCm": 172,
                  "chdStage": "Stage II",
                  "diseaseHistory": "prior MI",
                  "comorbidities": ["diabetes", "hypertension"],
                  "managementPlan": "statin + aspirin",
                  "goals": { "bpSystolic": 120, "bpDiastolic": 80, "totalCholesterol": 180,
                             "stepsPerDay": 8000, "targetWeightKg": 70, "dietNote": "low salt" }
                }
                """;

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(putBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.goals.stepsPerDay").value(8000));

        mockMvc.perform(get("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.birthYear").value(1975))
                .andExpect(jsonPath("$.data.comorbidities[0]").value("diabetes"))
                .andExpect(jsonPath("$.data.goals.dietNote").value("low salt"));
    }

    @Test
    void putIsIdempotentAndUpdatesInPlace() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"en\" }"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"am\", \"birthYear\": 1990 }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.birthYear").value(1990));
    }

    @Test
    void putWithInvalidLanguageReturns400() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"preferredLanguage\": \"fr\" }"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void putWithOutOfRangeHeightReturns400() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"heightCm\": 500 }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void putWithNegativeGoalReturns400() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"goals\": { \"bpSystolic\": -100 } }"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }
}
