// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.auth;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "scc.admin.username=scc-test",
        "scc.admin.password=scc-test-password",
        "scc.jwt.secret=test-only-scc-signing-secret-at-least-32-bytes",
        // Nothing listens here, so Prometheus-backed endpoints fail fast in these tests.
        "scc.prometheus-url=http://127.0.0.1:1"})
class AuthIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    private static String body(String username, String password) {
        return "{\"username\":\"" + username + "\",\"password\":\"" + password + "\"}";
    }

    private String token(String ip) throws Exception {
        String json = mockMvc.perform(post("/api/monitoring/auth/login").header("X-Real-IP", ip)
                        .contentType(APPLICATION_JSON).content(body("scc-test", "scc-test-password")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("scc-test"))
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(json, "$.data.token");
    }

    @Test
    void validCredentialsIssueAWorkingToken() throws Exception {
        String token = token("10.0.0.1");

        mockMvc.perform(get("/api/monitoring/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("scc-test"));
        mockMvc.perform(get("/api/monitoring/demo/sessions").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    @Test
    void wrongPasswordIsRejected() throws Exception {
        mockMvc.perform(post("/api/monitoring/auth/login").header("X-Real-IP", "10.0.0.2")
                        .contentType(APPLICATION_JSON).content(body("scc-test", "not-the-password")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void monitoringEndpointsRequireAToken() throws Exception {
        mockMvc.perform(get("/api/monitoring/overview"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Unauthorized"));
        mockMvc.perform(get("/api/monitoring/overview").header("Authorization", "Bearer forged.token.value"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void repeatedFailuresAreRateLimitedPerClient() throws Exception {
        for (int i = 0; i < LoginRateLimiter.MAX_ATTEMPTS; i++) {
            mockMvc.perform(post("/api/monitoring/auth/login").header("X-Real-IP", "10.0.0.3")
                            .contentType(APPLICATION_JSON).content(body("scc-test", "wrong-" + i)))
                    .andExpect(status().isUnauthorized());
        }
        mockMvc.perform(post("/api/monitoring/auth/login").header("X-Real-IP", "10.0.0.3")
                        .contentType(APPLICATION_JSON).content(body("scc-test", "scc-test-password")))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    void sectionEndpointsReport503WhenPrometheusIsDown() throws Exception {
        String token = token("10.0.0.4");
        mockMvc.perform(get("/api/monitoring/api-performance").header("Authorization", "Bearer " + token))
                .andExpect(status().isServiceUnavailable());
        // The overview still answers, reporting the system as OFFLINE instead of failing.
        mockMvc.perform(get("/api/monitoring/overview").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.systemStatus").value("OFFLINE"));
    }

    @Test
    void historyRejectsUnknownMetricsSoNoPromQLCanBeSent() throws Exception {
        String token = token("10.0.0.5");
        mockMvc.perform(get("/api/monitoring/history").param("metric", "up or vector(1)")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());
    }

    @Test
    void actuatorHealthIsOpenForTheContainerHealthcheck() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("WWW-Authenticate"));
    }
}
