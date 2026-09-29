package com.heartcare.research;

import com.heartcare.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;

import static com.heartcare.admin.AdminAuthControllerIntegrationTest.adminToken;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Shared fixtures: admin-created researchers, sign-in, and the forced first password change. */
abstract class ResearchTestSupport extends AbstractIntegrationTest {

    static final String NEW_PASSWORD = "researcher-chosen-password";

    @Autowired
    WebApplicationContext wac;

    @Autowired
    JdbcTemplate jdbcTemplate;

    MockMvc mockMvc;
    String admin;

    record Created(String id, String username, String password) {
    }

    @BeforeEach
    void setUpMvc() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
        admin = adminToken(mockMvc);
    }

    static String grantJson(String level, String datasets, boolean export, String dataFrom, String dataTo, String expiresAt) {
        return """
                { "accessLevel": "%s", "datasets": [%s], "exportAllowed": %s,
                  "dataFrom": %s, "dataTo": %s, "expiresAt": %s }"""
                .formatted(level, datasets, export, q(dataFrom), q(dataTo), q(expiresAt));
    }

    static String allDatasets() {
        return "\"VITALS\", \"SYMPTOMS\", \"ACTIVITY\", \"MEDICATIONS\", \"DEMOGRAPHICS\"";
    }

    private static String q(String s) {
        return s == null ? "null" : "\"" + s + "\"";
    }

    Created createResearcher(String grantJson) throws Exception {
        String username = "r-" + UUID.randomUUID().toString().substring(0, 12);
        MvcResult result = mockMvc.perform(post("/api/v1/admin/researchers")
                        .header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("""
                                { "username": "%s", "fullName": "Dr Test", "organisation": "UOW", "grant": %s }"""
                                .formatted(username, grantJson)))
                .andExpect(status().isOk())
                .andReturn();
        String body = result.getResponse().getContentAsString();
        return new Created(JsonPath.read(body, "$.data.researcher.id"), username, JsonPath.read(body, "$.data.password"));
    }

    String login(String username, String password) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/research/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"password\": \"%s\" }".formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    ResultActions changePassword(String token, String current, String next) throws Exception {
        return mockMvc.perform(post("/api/v1/research/auth/change-password")
                .header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON)
                .content("{ \"currentPassword\": \"%s\", \"newPassword\": \"%s\" }".formatted(current, next)));
    }

    /** Create, sign in and complete the forced change: a researcher ready to use the tools. */
    String readyResearcher(String grantJson) throws Exception {
        Created c = createResearcher(grantJson);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());
        return token;
    }

    ResultActions researchGet(String token, String path) throws Exception {
        return mockMvc.perform(get(path).header("Authorization", "Bearer " + token));
    }

    ResultActions researchPost(String token, String path, String json) throws Exception {
        return mockMvc.perform(post(path).header("Authorization", "Bearer " + token)
                .contentType(APPLICATION_JSON).content(json));
    }

    ResultActions adminPut(String path, String json) throws Exception {
        return mockMvc.perform(put(path).header("Authorization", "Bearer " + admin)
                .contentType(APPLICATION_JSON).content(json));
    }

    ResultActions adminPost(String path) throws Exception {
        return mockMvc.perform(post(path).header("Authorization", "Bearer " + admin));
    }
}
