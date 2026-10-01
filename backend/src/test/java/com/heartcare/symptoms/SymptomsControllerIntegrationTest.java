package com.heartcare.symptoms;

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

    private void postCheckIn(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    private void postCheckInInUtc(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .header("X-Timezone", "UTC")
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
        postCheckInInUtc(token, withMeasuredAt("2026-07-10T23:30:00Z"));
        postCheckInInUtc(token, withMeasuredAt("2026-07-11T00:30:00Z"));

        mockMvc.perform(get("/api/v1/symptoms?from=2026-07-11&to=2026-07-11")
                        .header("Authorization", "Bearer " + token)
                        .header("X-Timezone", "UTC"))
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

    @Test
    void secondCheckInOnSameLocalDayReturns400() throws Exception {
        // T-SYM-02: 08:00 and 20:00 on Sep 29 in Addis Ababa are the same calendar day.
        String token = registerAndGetToken();
        postCheckIn(token, withMeasuredAt("2026-09-29T08:00:00+03:00"));

        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .header("X-Timezone", "Africa/Addis_Ababa")
                        .contentType(APPLICATION_JSON).content(withMeasuredAt("2026-09-29T20:00:00+03:00")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("A symptom check-in already exists for 2026-09-29"));

        mockMvc.perform(get("/api/v1/symptoms").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void checkInsEitherSideOfLocalMidnightAreBothAccepted() throws Exception {
        // 20:30Z is 23:30 on Sep 28 in Addis Ababa; 21:30Z is 00:30 on Sep 29 — two local days,
        // even though both instants fall on the same UTC day.
        String token = registerAndGetToken();
        postCheckIn(token, withMeasuredAt("2026-09-28T20:30:00Z"));
        postCheckIn(token, withMeasuredAt("2026-09-28T21:30:00Z"));

        mockMvc.perform(get("/api/v1/symptoms?from=2026-09-29&to=2026-09-29")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void secondCheckInSameDayViaSyncIsRejectedNotFailed() throws Exception {
        String token = registerAndGetToken();
        postCheckIn(token, withMeasuredAt("2026-09-29T08:00:00+03:00"));
        String crid = UUID.randomUUID().toString();
        String batch = """
                { "records": [ { "entityType": "SYMPTOM", "clientRecordId": "%s", "payload": %s } ] }"""
                .formatted(crid, withMeasuredAt("2026-09-29T20:00:00+03:00"));

        mockMvc.perform(post("/api/v1/sync")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(batch))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.data.results[0].reason").value("A symptom check-in already exists for 2026-09-29"));
    }

    @Test
    void futureMeasuredAtReturns400() throws Exception {
        // T-SYM-03
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/symptoms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(withMeasuredAt("2099-01-01T09:00:00Z")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("measuredAt must not be in the future"));
    }
}
