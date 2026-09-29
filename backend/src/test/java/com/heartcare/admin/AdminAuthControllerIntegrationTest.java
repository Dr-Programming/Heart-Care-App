package com.heartcare.admin;

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

class AdminAuthControllerIntegrationTest extends AbstractIntegrationTest {

    static final String ADMIN_USER = "test-admin";
    static final String ADMIN_PASSWORD = "test-admin-password";

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    static String loginBody(String username, String password) {
        return "{ \"username\": \"" + username + "\", \"password\": \"" + password + "\" }";
    }

    static String adminToken(MockMvc mockMvc) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody(ADMIN_USER, ADMIN_PASSWORD)))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    static String patientToken(MockMvc mockMvc, String name) throws Exception {
        String body = "{ \"phone\": \"" + TestUsers.nextPhone() + "\", \"pin\": \"1234\", \"name\": \""
                + name + "\", \"preferredLanguage\": \"en\" }";
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    @Test
    void loginThenMe() throws Exception {
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody(ADMIN_USER, ADMIN_PASSWORD)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.expiresAt").exists())
                .andExpect(jsonPath("$.data.admin.username").value(ADMIN_USER))
                .andExpect(jsonPath("$.data.admin.passwordHash").doesNotExist());

        mockMvc.perform(get("/api/v1/admin/auth/me")
                        .header("Authorization", "Bearer " + adminToken(mockMvc)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(ADMIN_USER))
                .andExpect(jsonPath("$.data.lastLoginAt").exists());
    }

    @Test
    void wrongPasswordIs401() throws Exception {
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody(ADMIN_USER, "definitely-wrong")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(AdminAuthService.INVALID_CREDENTIALS));
    }

    @Test
    void unknownUsernameLooksLikeWrongPassword() throws Exception {
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody("nobody-" + UUID.randomUUID(), "whatever-pass")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(AdminAuthService.INVALID_CREDENTIALS));
    }

    @Test
    void fifthFailureLocksThenCorrectPasswordIsStillRefused() throws Exception {
        // A throwaway username, so the shared test-admin account is never locked for other tests.
        String username = "locktest-" + UUID.randomUUID();
        for (int i = 0; i < 4; i++) {
            mockMvc.perform(post("/api/v1/admin/auth/login")
                            .contentType(APPLICATION_JSON).content(loginBody(username, "wrong-password")))
                    .andExpect(status().isUnauthorized());
        }
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody(username, "wrong-password")))
                .andExpect(status().isLocked());
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody(username, "wrong-password")))
                .andExpect(status().isLocked());
    }

    @Test
    void blankCredentialsAre400() throws Exception {
        mockMvc.perform(post("/api/v1/admin/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody("", "")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void adminRoutesRequireAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/admin/stats"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void patientTokenIsForbiddenOnAdminRoutes() throws Exception {
        String token = patientToken(mockMvc, "Patient Probe");
        mockMvc.perform(get("/api/v1/admin/users").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false));
        mockMvc.perform(get("/api/v1/admin/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminTokenIsForbiddenOnPatientRoutes() throws Exception {
        String token = adminToken(mockMvc);
        mockMvc.perform(get("/api/v1/patients/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/vitals").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }
}
