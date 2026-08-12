package com.heartcare.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthControllerIntegrationTest extends AbstractIntegrationTest {

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

    @Test
    void registerThenLoginThenMe() throws Exception {
        String phone = TestUsers.nextPhone();
        String registerBody = objectMapper.writeValueAsString(
                new RegisterRequest(phone, "1234", "Abebe Girma", "am"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(registerBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.user.phone").value(phone))
                .andExpect(jsonPath("$.data.user.name").value("Abebe Girma"))
                .andExpect(jsonPath("$.data.user.preferredLanguage").value("am"))
                .andExpect(jsonPath("$.data.user.role").value("PATIENT"));

        String loginBody = objectMapper.writeValueAsString(new LoginRequest(phone, "1234"));

        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(loginBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andReturn();

        String token = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.data.token");

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(phone))
                .andExpect(jsonPath("$.data.name").value("Abebe Girma"))
                .andExpect(jsonPath("$.data.preferredLanguage").value("am"));
    }

    @Test
    void loginWithWrongPinReturns401() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(phone, "9999"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
    }

    @Test
    void loginWithUnknownPhoneReturns401WithTheSameMessage() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest(TestUsers.nextPhone(), "1234"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
    }

    @Test
    void meWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void meWithInvalidTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer not-a-real-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void duplicateRegisterReturns409() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest(TestUsers.nextPhone(), "1234", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                .contentType(APPLICATION_JSON).content(body)).andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Phone already registered"));
    }

    @Test
    void registerWithMalformedPhoneReturns400() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest("0911234567", "1234", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
    }

    @Test
    void registerWithNonNumericPinReturns400() throws Exception {
        String body = objectMapper.writeValueAsString(
                new RegisterRequest(TestUsers.nextPhone(), "abcd", "Abebe", "en"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
    }

    // This is the only test in the suite that would catch @Transactional(noRollbackFor = ...)
    // being deleted from AuthService.login: every AuthServiceTest case mocks the repository, so
    // there is no real transaction to roll back and the counter assertions pass either way. Here
    // the failure count is persisted for real, so if the rollback swallowed the increments this
    // test would never see attempt 5 return 423. Keep both in sync — do not "simplify" either.
    //
    // This test is also the one that pins application.yml's duration-minutes value: it asserts
    // the message ends with the exact text "in 15 minutes." (not a substring match — "15 minutes"
    // would still match "115 minutes" or "215 minutes"), so any wrong config value fails here even
    // though every other test either hardcodes 15 into the service directly or never checks the
    // minute count at all.
    @Test
    void fiveWrongPinsLockTheAccountAndTheCorrectPinIsThenRefused() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        String wrongPin = objectMapper.writeValueAsString(new LoginRequest(phone, "9999"));

        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }

        // The fifth failure trips the lock, and says so rather than repeating "invalid". The
        // second assertion below must be an exact-tail match, not containsString: "15 minutes" as
        // a substring would still match "115 minutes" or "215 minutes", silently passing a wrong
        // app.auth.lockout.duration-minutes value. endsWith("in 15 minutes.") cannot match any
        // duration other than 15.
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(wrongPin))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.containsString("Too many failed attempts")))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.endsWith("in 15 minutes.")));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(phone, "1234"))))
                .andExpect(status().isLocked());
    }

    @Test
    void aSuccessfulLoginClearsTheFailureStreak() throws Exception {
        String phone = TestUsers.nextPhone();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk());

        String wrongPin = objectMapper.writeValueAsString(new LoginRequest(phone, "9999"));
        String rightPin = objectMapper.writeValueAsString(new LoginRequest(phone, "1234"));

        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(APPLICATION_JSON).content(rightPin))
                .andExpect(status().isOk());

        // Streak cleared: four more failures must not lock, because the counter restarted.
        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(APPLICATION_JSON).content(wrongPin))
                    .andExpect(status().isUnauthorized());
        }
    }
}
