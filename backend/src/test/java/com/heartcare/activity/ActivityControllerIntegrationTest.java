package com.heartcare.activity;

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

class ActivityControllerIntegrationTest extends AbstractIntegrationTest {

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

    private void postActivity(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    private static final String FULL = """
            { "data": {
                "type": "WALKING",
                "durationMinutes": 30,
                "intensity": "MODERATE",
                "steps": 3200,
                "distanceMeters": 2400
            }, "note": "morning walk" }""";

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/activities")
                        .contentType(APPLICATION_JSON).content(FULL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsActivity() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(FULL))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.data.type").value("WALKING"))
                .andExpect(jsonPath("$.data.data.durationMinutes").value(30))
                .andExpect(jsonPath("$.data.data.steps").value(3200))
                .andExpect(jsonPath("$.data.note").value("morning walk"));

        mockMvc.perform(get("/api/v1/activities").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].data.type").value("WALKING"))
                .andExpect(jsonPath("$.data[0].note").value("morning walk"));
    }

    @Test
    void minimalActivityRoundTrips() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "FARMING",
                                    "durationMinutes": 90,
                                    "intensity": "VIGOROUS"
                                } }"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.data.type").value("FARMING"))
                .andExpect(jsonPath("$.data.data.intensity").value("VIGOROUS"));
    }

    @Test
    void historyFiltersByDateRangeInUtc() throws Exception {
        String token = registerAndGetToken();
        // 23:30Z on 2026-07-10 is still 2026-07-10 in UTC; 00:30Z on 2026-07-11 is 2026-07-11.
        postActivity(token, withMeasuredAt("2026-07-10T23:30:00Z"));
        postActivity(token, withMeasuredAt("2026-07-11T00:30:00Z"));

        mockMvc.perform(get("/api/v1/activities?from=2026-07-11&to=2026-07-11")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].measuredAt").value(org.hamcrest.Matchers.startsWith("2026-07-11")));
    }

    private static String withMeasuredAt(String iso) {
        return """
                { "data": {
                    "type": "WALKING",
                    "durationMinutes": 30,
                    "intensity": "MODERATE"
                }, "measuredAt": "%s" }""".formatted(iso);
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = """
                { "data": {
                    "type": "WALKING",
                    "durationMinutes": 30,
                    "intensity": "MODERATE"
                }, "clientRecordId": "%s" }""".formatted(crid);
        postActivity(token, body);
        postActivity(token, body);

        mockMvc.perform(get("/api/v1/activities").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void missingRequiredKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "WALKING",
                                    "durationMinutes": 30
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void badTypeEnumReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "SWIMMING",
                                    "durationMinutes": 30,
                                    "intensity": "MODERATE"
                                } }"""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void outOfRangeDurationReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/activities")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "data": {
                                    "type": "WALKING",
                                    "durationMinutes": 0,
                                    "intensity": "MODERATE"
                                } }"""))
                .andExpect(status().isBadRequest());
    }
}
