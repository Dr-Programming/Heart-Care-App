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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** TEST_REPORT Issue 5 (change PIN) and Issue 6 (token refresh). */
class RefreshAndPinIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    @Autowired
    JdbcTemplate jdbcTemplate;

    final ObjectMapper objectMapper = new ObjectMapper();

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    /** Registers a fresh user; returns the raw JSON of the register response. */
    private String register(String phone) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RegisterRequest(phone, "1234", "Abebe", "en"))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/refresh")
                .contentType(APPLICATION_JSON)
                .content("{ \"refreshToken\": \"" + refreshToken + "\" }"));
    }

    private ResultActions changePin(String accessToken, String currentPin, String newPin) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/change-pin")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(APPLICATION_JSON)
                .content("{ \"currentPin\": \"%s\", \"newPin\": \"%s\" }".formatted(currentPin, newPin)));
    }

    private ResultActions login(String phone, String pin) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/login")
                .contentType(APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new LoginRequest(phone, pin))));
    }

    private static String read(String json, String path) {
        return JsonPath.read(json, path);
    }

    // ---- Issue 6: refresh tokens -------------------------------------------------------------

    @Test
    void registerAndLoginReturnARefreshTokenAndExpiries() throws Exception {
        String phone = TestUsers.nextPhone();
        String body = register(phone);
        assertThat(read(body, "$.data.refreshToken")).isNotBlank();
        assertThat(read(body, "$.data.accessTokenExpiresAt")).isNotBlank();
        assertThat(read(body, "$.data.refreshTokenExpiresAt")).isNotBlank();

        login(phone, "1234")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.refreshToken").exists());
    }

    @Test
    void refreshRotatesAndReturnsAWorkingAccessToken() throws Exception {
        String body = register(TestUsers.nextPhone());
        String firstRefresh = read(body, "$.data.refreshToken");

        String refreshed = refresh(firstRefresh)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.user.role").value("PATIENT"))
                .andReturn().getResponse().getContentAsString();

        String secondRefresh = read(refreshed, "$.data.refreshToken");
        assertThat(secondRefresh).isNotEqualTo(firstRefresh);
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + read(refreshed, "$.data.token")))
                .andExpect(status().isOk());
    }

    @Test
    void reusingARotatedRefreshTokenRevokesTheWholeFamily() throws Exception {
        String first = read(register(TestUsers.nextPhone()), "$.data.refreshToken");
        String second = read(refresh(first).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "$.data.refreshToken");

        // The old token coming back means it leaked: refuse it, and kill its successor too.
        refresh(first).andExpect(status().isUnauthorized());
        refresh(second).andExpect(status().isUnauthorized());
    }

    @Test
    void unknownRefreshTokenReturns401() throws Exception {
        refresh("not-a-real-token").andExpect(status().isUnauthorized());
    }

    @Test
    void expiredRefreshTokenReturns401() throws Exception {
        String phone = TestUsers.nextPhone();
        String token = read(register(phone), "$.data.refreshToken");
        jdbcTemplate.update("""
                UPDATE refresh_tokens SET expires_at = now() - interval '1 minute'
                 WHERE user_id = (SELECT id FROM users WHERE phone = ?)""", phone);

        refresh(token).andExpect(status().isUnauthorized());
    }

    @Test
    void refreshTokenIsStoredOnlyAsAHash() throws Exception {
        String phone = TestUsers.nextPhone();
        String token = read(register(phone), "$.data.refreshToken");

        Integer plaintextRows = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM refresh_tokens WHERE token_hash = ?", Integer.class, token);
        assertThat(plaintextRows).isZero();
    }

    @Test
    void logoutRevokesTheRefreshToken() throws Exception {
        String token = read(register(TestUsers.nextPhone()), "$.data.refreshToken");

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"refreshToken\": \"" + token + "\" }"))
                .andExpect(status().isOk());

        refresh(token).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutWithUnknownTokenStillReturns200() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"refreshToken\": \"whatever\" }"))
                .andExpect(status().isOk());
    }

    // ---- Issue 5: change PIN -----------------------------------------------------------------

    @Test
    void changePinSwapsThePinAndRevokesOldRefreshTokens() throws Exception {
        String phone = TestUsers.nextPhone();
        String body = register(phone);
        String access = read(body, "$.data.token");
        String oldRefresh = read(body, "$.data.refreshToken");

        changePin(access, "1234", "5678")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.refreshToken").exists());

        login(phone, "1234").andExpect(status().isUnauthorized());
        login(phone, "5678").andExpect(status().isOk());
        refresh(oldRefresh).andExpect(status().isUnauthorized());
    }

    @Test
    void changePinWithWrongCurrentPinReturns400() throws Exception {
        String access = read(register(TestUsers.nextPhone()), "$.data.token");

        // 400 rather than 401: the access token is fine, and a 401 would send the app's
        // refresh-and-retry interceptor round in a loop or sign the patient out.
        changePin(access, "9999", "5678")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Current PIN is incorrect"));
    }

    @Test
    void wrongCurrentPinsCountTowardTheLoginLockout() throws Exception {
        String phone = TestUsers.nextPhone();
        String access = read(register(phone), "$.data.token");

        for (int attempt = 1; attempt <= 4; attempt++) {
            changePin(access, "9999", "5678").andExpect(status().isBadRequest());
        }
        changePin(access, "9999", "5678").andExpect(status().isLocked());

        // A stolen access token must not become a way to grind through the PIN space.
        changePin(access, "1234", "5678").andExpect(status().isLocked());
        login(phone, "1234").andExpect(status().isLocked());
    }

    @Test
    void changePinToTheSamePinReturns400() throws Exception {
        String access = read(register(TestUsers.nextPhone()), "$.data.token");
        changePin(access, "1234", "1234").andExpect(status().isBadRequest());
    }

    @Test
    void changePinWithMalformedNewPinReturns400() throws Exception {
        String access = read(register(TestUsers.nextPhone()), "$.data.token");
        changePin(access, "1234", "12ab").andExpect(status().isBadRequest());
    }

    @Test
    void changePinRequiresAnAccessToken() throws Exception {
        mockMvc.perform(post("/api/v1/auth/change-pin")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"currentPin\": \"1234\", \"newPin\": \"5678\" }"))
                .andExpect(status().isUnauthorized());
    }
}
