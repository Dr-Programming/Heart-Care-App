package com.heartcare.auth;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * POST /auth/pin-change: the PIN change a phone made offline, sent when it is back online. It
 * proves itself with the old PIN (no session needed), and a retry with the same changeId is safe.
 */
class PinChangeIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    private String register(String phone) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"phone\": \"%s\", \"pin\": \"1234\", \"name\": \"Abebe\", \"preferredLanguage\": \"en\" }"
                                .formatted(phone)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
    }

    private ResultActions pinChange(String phone, String currentPin, String newPin, String changeId) throws Exception {
        String id = changeId == null ? "" : ", \"changeId\": \"" + changeId + "\"";
        return mockMvc.perform(post("/api/v1/auth/pin-change")
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\", \"currentPin\": \"%s\", \"newPin\": \"%s\"%s }"
                        .formatted(phone, currentPin, newPin, id)));
    }

    private ResultActions login(String phone, String pin) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/login")
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\", \"pin\": \"%s\" }".formatted(phone, pin)));
    }

    @Test
    void changesThePinWithoutASessionAndSignsIn() throws Exception {
        String phone = TestUsers.nextPhone();
        String oldRefresh = JsonPath.read(register(phone), "$.data.refreshToken");

        pinChange(phone, "1234", "5678", UUID.randomUUID().toString())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.refreshToken").exists());

        login(phone, "1234").andExpect(status().isUnauthorized());
        login(phone, "5678").andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"refreshToken\": \"" + oldRefresh + "\" }"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void retryWithTheSameChangeIdSucceedsAgain() throws Exception {
        // The phone's first request went through but the answer was lost; the retry still
        // carries the old PIN, which no longer matches. The changeId makes it a safe replay.
        String phone = TestUsers.nextPhone();
        register(phone);
        String changeId = UUID.randomUUID().toString();

        pinChange(phone, "1234", "5678", changeId).andExpect(status().isOk());
        pinChange(phone, "1234", "5678", changeId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists());

        login(phone, "5678").andExpect(status().isOk());
    }

    @Test
    void replayNeedsTheSameNewPin() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone);
        String changeId = UUID.randomUUID().toString();
        pinChange(phone, "1234", "5678", changeId).andExpect(status().isOk());

        pinChange(phone, "1234", "9999", changeId).andExpect(status().isUnauthorized());
        login(phone, "5678").andExpect(status().isOk());
    }

    @Test
    void staleChangeLosesToANewerOne() throws Exception {
        // Server wins: another device changed the PIN first, so this phone's queued change,
        // which still carries the old PIN, is refused.
        String phone = TestUsers.nextPhone();
        register(phone);
        pinChange(phone, "1234", "1111", UUID.randomUUID().toString()).andExpect(status().isOk());

        pinChange(phone, "1234", "5678", UUID.randomUUID().toString())
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
        login(phone, "1111").andExpect(status().isOk());
    }

    @Test
    void wrongCurrentPinCountsTowardTheLoginLockout() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone);
        for (int attempt = 1; attempt <= 4; attempt++) {
            pinChange(phone, "9999", "5678", UUID.randomUUID().toString()).andExpect(status().isUnauthorized());
        }
        pinChange(phone, "9999", "5678", UUID.randomUUID().toString()).andExpect(status().isLocked());
        login(phone, "1234").andExpect(status().isLocked());
    }

    @Test
    void unknownPhoneLooksLikeAWrongPin() throws Exception {
        pinChange(TestUsers.nextPhone(), "1234", "5678", UUID.randomUUID().toString())
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid phone or PIN"));
    }

    @Test
    void changeIdIsRequired() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone);
        pinChange(phone, "1234", "5678", null).andExpect(status().isBadRequest());
    }

    @Test
    void newPinMustDiffer() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone);
        pinChange(phone, "1234", "1234", UUID.randomUUID().toString()).andExpect(status().isBadRequest());
    }

    @Test
    void aReplayIsRefusedWhileTheAccountIsLocked() throws Exception {
        // A lock means locked: even a correct retry of an applied change waits it out.
        String phone = TestUsers.nextPhone();
        register(phone);
        String changeId = UUID.randomUUID().toString();
        pinChange(phone, "1234", "5678", changeId).andExpect(status().isOk());
        for (int attempt = 1; attempt <= 5; attempt++) {
            login(phone, "0000");
        }

        pinChange(phone, "1234", "5678", changeId).andExpect(status().isLocked());
    }
}
