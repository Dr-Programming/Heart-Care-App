package com.heartcare.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.heartcare.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Malformed requests must map to 4xx, not the catch-all 500.
 *
 * <p>These all returned 500 before GlobalExceptionHandler gained handlers for Spring's own binding
 * exceptions. A 500 is not merely the wrong number: it tells an offline-first client the failure is
 * transient and worth retrying, when in fact the request can never succeed as written.
 */
class RequestErrorMappingTest extends AbstractIntegrationTest {

    @Autowired WebApplicationContext wac;
    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private String jwt;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).apply(springSecurity()).build();
        ObjectNode body = objectMapper.createObjectNode();
        body.put("fullName", "Abebe");
        body.put("email", UUID.randomUUID() + "@example.com");
        body.put("password", "password1");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body.toString()))
                .andExpect(status().isOk()).andReturn();
        jwt = JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    @Test
    void unknownEnumValueInQueryParamIsBadRequest() throws Exception {
        mockMvc.perform(get("/api/v1/vitals?type=BOGUS").header("Authorization", "Bearer " + jwt))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("type has an invalid value"));
    }

    @Test
    void unparseableDateInQueryParamIsBadRequest() throws Exception {
        mockMvc.perform(get("/api/v1/vitals?from=not-a-date").header("Authorization", "Bearer " + jwt))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("from has an invalid value"));
    }

    @Test
    void nonUuidInQueryParamIsBadRequest() throws Exception {
        mockMvc.perform(get("/api/v1/dose-logs?medicationId=nope")
                        .header("Authorization", "Bearer " + jwt))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("medicationId has an invalid value"));
    }

    @Test
    void unmatchedRouteIsNotFound() throws Exception {
        mockMvc.perform(post("/api/v1/vitals/nonexistent").header("Authorization", "Bearer " + jwt))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void wrongMethodOnAKnownRouteIsMethodNotAllowed() throws Exception {
        // /medications/{id} exists for PUT and DELETE, but there is no GET.
        mockMvc.perform(get("/api/v1/medications/" + UUID.randomUUID())
                        .header("Authorization", "Bearer " + jwt))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void missingTokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/vitals"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Unauthorized"));
    }
}
