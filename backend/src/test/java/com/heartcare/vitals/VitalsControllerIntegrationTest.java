package com.heartcare.vitals;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class VitalsControllerIntegrationTest extends AbstractIntegrationTest {

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

    private void setHeight(String token, int heightCm) throws Exception {
        mockMvc.perform(put("/api/v1/patients/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"heightCm\": " + heightCm + " }"))
                .andExpect(status().isOk());
    }

    private void postVital(String token, String json) throws Exception {
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(json))
                .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/vitals")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logThenHistoryReturnsVital() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"note\": \"fasting\" }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("GLUCOSE"))
                .andExpect(jsonPath("$.data.flagged").value(false))
                .andExpect(jsonPath("$.data.values.glucose").value(5.5));

        mockMvc.perform(get("/api/v1/vitals").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].type").value("GLUCOSE"))
                .andExpect(jsonPath("$.data[0].note").value("fasting"));
    }

    @Test
    void highBloodPressureIsFlagged() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 190, \"diastolic\": 100 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.flagged").value(true));
    }

    @Test
    void weightReturnsComputedBmiWhenHeightSet() throws Exception {
        String token = registerAndGetToken();
        setHeight(token, 170);
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"WEIGHT\", \"values\": { \"weight\": 72 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.values.bmi").value(24.9));
    }

    @Test
    void weightHasNoBmiWhenNoHeight() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"WEIGHT\", \"values\": { \"weight\": 72 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.values.bmi").doesNotExist());
    }

    @Test
    void cholesterolCanBeLoggedAndFlagged() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"CHOLESTEROL\", \"values\": { \"ldl\": 5.0, \"hdl\": 1.2, \"total\": 6.0 } }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("CHOLESTEROL"))
                .andExpect(jsonPath("$.data.values.ldl").value(5.0))
                .andExpect(jsonPath("$.data.flagged").value(true));
    }

    @Test
    void historyFiltersByType() throws Exception {
        String token = registerAndGetToken();
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 } }");
        postVital(token, "{ \"type\": \"HEART_RATE\", \"values\": { \"heartRate\": 70 } }");

        mockMvc.perform(get("/api/v1/vitals?type=HEART_RATE").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].type").value("HEART_RATE"));
    }

    @Test
    void historyFiltersByDateRange() throws Exception {
        String token = registerAndGetToken();
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"measuredAt\": \"2026-07-05T08:00:00Z\" }");
        postVital(token, "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 6.0 }, \"measuredAt\": \"2026-07-20T08:00:00Z\" }");

        mockMvc.perform(get("/api/v1/vitals?from=2026-07-10&to=2026-07-31")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].values.glucose").value(6.0));
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String crid = UUID.randomUUID().toString();
        String body = "{ \"type\": \"GLUCOSE\", \"values\": { \"glucose\": 5.5 }, \"clientRecordId\": \"%s\" }".formatted(crid);
        postVital(token, body);
        postVital(token, body);

        mockMvc.perform(get("/api/v1/vitals").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void invalidTypeReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"SUGAR\", \"values\": { \"x\": 1 } }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingValuesKeyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 120 } }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void systolicNotGreaterThanDiastolicReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/vitals")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"type\": \"BLOOD_PRESSURE\", \"values\": { \"systolic\": 80, \"diastolic\": 80 } }"))
                .andExpect(status().isBadRequest());
    }
}
