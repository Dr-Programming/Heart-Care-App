package com.heartcare.medication;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class MedicationControllerIntegrationTest extends AbstractIntegrationTest {

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

    private static final String ASPIRIN = """
            { "name": "Aspirin", "doseMg": 100, "frequency": "BID",
              "scheduleTimes": ["08:00", "20:00"] }
            """;

    @Test
    void createWithoutTokenReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/medications")
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void createThenListReturnsMedication() throws Exception {
        String token = registerAndGetToken();

        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Aspirin"))
                .andExpect(jsonPath("$.data.frequency").value("BID"))
                .andExpect(jsonPath("$.data.scheduleTimes[0]").value("08:00"))
                .andExpect(jsonPath("$.data.active").value(true));

        mockMvc.perform(get("/api/v1/medications")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].name").value("Aspirin"));
    }

    @Test
    void createIsIdempotentOnClientRecordId() throws Exception {
        String token = registerAndGetToken();
        String clientRecordId = UUID.randomUUID().toString();
        String body = """
                { "name": "Aspirin", "doseMg": 100, "frequency": "BID",
                  "scheduleTimes": ["08:00"], "clientRecordId": "%s" }
                """.formatted(clientRecordId);

        mockMvc.perform(post("/api/v1/medications").header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/medications").header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/medications").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void updateChangesFields() throws Exception {
        String token = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(put("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin EC\", \"doseMg\": 81, \"frequency\": \"ONCE_DAILY\", \"scheduleTimes\": [\"09:00\"] }"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Aspirin EC"))
                .andExpect(jsonPath("$.data.frequency").value("ONCE_DAILY"));
    }

    @Test
    void deleteDeactivatesAndHidesFromDefaultList() throws Exception {
        String token = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(delete("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.active").value(false));

        mockMvc.perform(get("/api/v1/medications")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(0));

        mockMvc.perform(get("/api/v1/medications?includeInactive=true")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    void accessingOthersMedicationReturns404() throws Exception {
        String tokenA = registerAndGetToken();
        MvcResult created = mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(APPLICATION_JSON).content(ASPIRIN))
                .andReturn();
        String id = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        String tokenB = registerAndGetToken();
        mockMvc.perform(delete("/api/v1/medications/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void invalidFrequencyReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"HOURLY\" }"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void negativeDoseReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": -5, \"frequency\": \"BID\" }"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidScheduleTimeReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/medications")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"name\": \"Aspirin\", \"doseMg\": 100, \"frequency\": \"BID\", \"scheduleTimes\": [\"25:00\"] }"))
                .andExpect(status().isBadRequest());
    }
}
