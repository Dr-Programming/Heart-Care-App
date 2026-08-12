package com.heartcare.medication;

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

class DoseLogControllerIntegrationTest extends AbstractIntegrationTest {

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

    private String createMedication(String token) throws Exception {
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"BID\", \"scheduleTimes\": [\"08:00\"] }"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");
    }

    @Test
    void logThenHistoryReturnsDose() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\", \"scheduledTime\": \"08:00\", \"note\": \"with food\" }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("TAKEN"))
                .andExpect(jsonPath("$.data.medicationId").value(medId));

        mockMvc.perform(get("/api/v1/dose-logs")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].status").value("TAKEN"))
                .andExpect(jsonPath("$.data[0].note").value("with food"));
    }

    @Test
    void historyFiltersByDateRange() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        logDose(token, medId, "2026-07-05");
        logDose(token, medId, "2026-07-20");

        mockMvc.perform(get("/api/v1/dose-logs?from=2026-07-10&to=2026-07-31")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].scheduledDate").value("2026-07-20"));
    }

    @Test
    void historyFiltersByMedicationId() throws Exception {
        String token = registerAndGetToken();
        String medA = createMedication(token);
        String medB = createMedication(token);
        logDose(token, medA, "2026-07-10");
        logDose(token, medB, "2026-07-10");

        mockMvc.perform(get("/api/v1/dose-logs?medicationId=" + medA)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].medicationId").value(medA));
    }

    @Test
    void reLogWithSameClientRecordIdReturnsSingleRow() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        String crid = UUID.randomUUID().toString();
        String body = "{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\", \"clientRecordId\": \"%s\" }".formatted(crid);

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                .header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                .header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dose-logs").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void invalidStatusReturns400() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"LATER\", \"scheduledDate\": \"2026-07-10\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingScheduledDateReturns400() throws Exception {
        String token = registerAndGetToken();
        String medId = createMedication(token);
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void loggingAgainstOthersMedicationReturns404() throws Exception {
        String tokenA = registerAndGetToken();
        String medId = createMedication(tokenA);
        String tokenB = registerAndGetToken();

        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"2026-07-10\" }"))
                .andExpect(status().isNotFound());
    }

    private void logDose(String token, String medId, String date) throws Exception {
        mockMvc.perform(post("/api/v1/medications/" + medId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"status\": \"TAKEN\", \"scheduledDate\": \"%s\" }".formatted(date)))
                .andExpect(status().isOk());
    }
}
