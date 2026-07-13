package com.heartcare.symptoms;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
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

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SymptomsControllerIntegrationTest extends AbstractIntegrationTest {

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

    private String registerAndGetToken() throws Exception {
        ObjectNode body = objectMapper.createObjectNode();
        body.put("fullName", "Abebe");
        body.put("email", UUID.randomUUID() + "@example.com");
        body.put("password", "password1");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body.toString()))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    private void postCheckIn(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    private static final String BENIGN = """
            { "data": {
                "chestPain": { "present": false },
                "shortnessOfBreath": "NONE",
                "heartRate": 70,
                "bloodPressure": { "systolic": 120, "diastolic": 80 },
                "swelling": false,
                "energyLevel": 8
            } }""";

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .contentType(APPLICATION_JSON).content(BENIGN))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsCheckIn() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": true, "severity": 8 },
                                    "shortnessOfBreath": "MILD",
                                    "heartRate": 82,
                                    "bloodPressure": { "systolic": 165, "diastolic": 92 },
                                    "swelling": true,
                                    "energyLevel": 4
                                }, "note": "tight chest" }"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assessment.overall").value("EMERGENCY"))
                .andExpect(jsonPath("$.data.assessment.symptoms.chestPain").value("EMERGENCY"))
                .andExpect(jsonPath("$.data.assessment.symptoms.bloodPressure").value("URGENT"))
                .andExpect(jsonPath("$.data.data.heartRate").value(82));

        mockMvc.perform(get("/api/v1/symptoms").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].assessment.overall").value("EMERGENCY"))
                .andExpect(jsonPath("$.data[0].note").value("tight chest"));
    }

    @Test
    void benignCheckInIsNone() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(BENIGN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assessment.overall").value("NONE"));
    }

    @Test
    void historyFiltersByDateRangeInUtc() throws Exception {
        String token = registerAndGetToken();
        // 23:30Z on 2026-07-10 is still 2026-07-10 in UTC; 00:30Z on 2026-07-11 is 2026-07-11.
        postCheckIn(token, withMeasuredAt("2026-07-10T23:30:00Z"));
        postCheckIn(token, withMeasuredAt("2026-07-11T00:30:00Z"));

        mockMvc.perform(get("/api/v1/symptoms?from=2026-07-11&to=2026-07-11")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].measuredAt").value(org.hamcrest.Matchers.startsWith("2026-07-11")));
    }

    private static String withMeasuredAt(String iso) {
        return """
                { "data": {
                    "chestPain": { "present": false },
                    "shortnessOfBreath": "NONE",
                    "heartRate": 70,
                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                    "swelling": false,
                    "energyLevel": 8
                }, "measuredAt": "%s" }""".formatted(iso);
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = """
                { "data": {
                    "chestPain": { "present": false },
                    "shortnessOfBreath": "NONE",
                    "heartRate": 70,
                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                    "swelling": false,
                    "energyLevel": 8
                }, "clientRecordId": "%s" }""".formatted(crid);
        postCheckIn(token, body);
        postCheckIn(token, body);

        mockMvc.perform(get("/api/v1/symptoms").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void missingRequiredKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "NONE",
                                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void badShortnessOfBreathEnumReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "WHEEZY",
                                    "heartRate": 70,
                                    "bloodPressure": { "systolic": 120, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void systolicNotGreaterThanDiastolicReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "chestPain": { "present": false },
                                    "shortnessOfBreath": "NONE",
                                    "heartRate": 70,
                                    "bloodPressure": { "systolic": 80, "diastolic": 80 },
                                    "swelling": false,
                                    "energyLevel": 8
                                } }"""))
                .andExpect(status().isBadRequest());
    }
}
