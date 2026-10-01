package com.heartcare.common.security;

import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** T-SEC-05. Own context with tiny limits; the shared test config raises them for everyone else. */
@TestPropertySource(properties = {
        "app.rate-limit.register.max-requests=3",
        "app.rate-limit.refresh.max-requests=2",
        "app.rate-limit.reset-pin.max-requests=2"})
class RateLimitIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    private ResultActions register(String remoteAddr) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/register")
                .with(request -> {
                    request.setRemoteAddr(remoteAddr);
                    return request;
                })
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\", \"pin\": \"1234\", \"name\": \"Abebe\", \"preferredLanguage\": \"en\" }"
                        .formatted(TestUsers.nextPhone())));
    }

    @Test
    void registrationIsLimitedPerIp() throws Exception {
        for (int i = 0; i < 3; i++) {
            register("10.0.0.1").andExpect(status().isOk());
        }
        register("10.0.0.1")
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Too many requests. Try again later."));

        // A different client is unaffected.
        register("10.0.0.2").andExpect(status().isOk());
    }

    @Test
    void refreshIsLimitedPerIp() throws Exception {
        for (int i = 0; i < 2; i++) {
            mockMvc.perform(post("/api/v1/auth/refresh")
                            .with(request -> {
                                request.setRemoteAddr("10.0.0.9");
                                return request;
                            })
                            .contentType(APPLICATION_JSON).content("{ \"refreshToken\": \"x\" }"))
                    .andExpect(status().isUnauthorized());
        }
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .with(request -> {
                            request.setRemoteAddr("10.0.0.9");
                            return request;
                        })
                        .contentType(APPLICATION_JSON).content("{ \"refreshToken\": \"x\" }"))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    void pinResetIsLimitedPerIp() throws Exception {
        String body = """
                { "phone": "+251900000000", "newPin": "5678", "answers": [
                  { "questionId": "FIRST_SCHOOL", "answer": "aa" },
                  { "questionId": "CHILDHOOD_FRIEND", "answer": "bb" },
                  { "questionId": "FAVORITE_TEACHER", "answer": "cc" } ] }""";
        for (int i = 0; i < 2; i++) {
            mockMvc.perform(post("/api/v1/auth/reset-pin")
                            .with(request -> {
                                request.setRemoteAddr("10.0.0.7");
                                return request;
                            })
                            .contentType(APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest());
        }
        mockMvc.perform(post("/api/v1/auth/reset-pin")
                        .with(request -> {
                            request.setRemoteAddr("10.0.0.7");
                            return request;
                        })
                        .contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isTooManyRequests());
    }
}
