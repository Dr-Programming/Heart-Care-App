package com.heartcare.research;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import static com.heartcare.admin.AdminAuthControllerIntegrationTest.patientToken;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Account lifecycle, the one-change password rule, immediate cut-off, grant limits and auditing. */
class ResearchAccessIntegrationTest extends ResearchTestSupport {

    private static final String VITALS_ONLY = grantJson("AGGREGATE", "\"VITALS\"", false, null, null, null);

    @Test
    void onlyAdminsCanCreateResearchers() throws Exception {
        String patient = patientToken(mockMvc, "Not An Admin");
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + patient)
                        .contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden());

        String researcher = readyResearcher(VITALS_ONLY);
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + researcher)
                        .contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden());
        // ...and a researcher token is walled off from patient routes too.
        researchGet(researcher, "/api/v1/patients/me").andExpect(status().isForbidden());
        // ...while an admin token cannot act as a researcher.
        researchGet(admin, "/api/v1/research/catalog").andExpect(status().isForbidden());
    }

    @Test
    void createReturnsPasswordOnceAndNeverExposesHash() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        assertThat(c.password()).hasSize(19); // 16 symbols in groups of four
        MvcResult detail = mockMvc.perform(get("/api/v1/admin/researchers/" + c.id()).header("Authorization", "Bearer " + admin))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(c.username()))
                .andExpect(jsonPath("$.data.mustChangePassword").value(true))
                .andReturn();
        String body = detail.getResponse().getContentAsString();
        assertThat(body).doesNotContain(c.password()).doesNotContain("passwordHash").doesNotContain("$2a$");
    }

    @Test
    void duplicateUsernameIs409() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"fullName\": \"X\", \"grant\": %s }".formatted(c.username(), VITALS_ONLY)))
                .andExpect(status().isConflict());
    }

    @Test
    void firstSignInForcesTheOneAndOnlySelfServiceChange() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());

        researchGet(token, "/api/v1/research/catalog")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("PASSWORD_CHANGE_REQUIRED"));
        researchGet(token, "/api/v1/research/auth/me")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mustChangePassword").value(true))
                .andExpect(jsonPath("$.data.canChangePassword").value(true));

        changePassword(token, c.password(), c.password() + "x").andExpect(status().isOk());
        researchGet(token, "/api/v1/research/catalog").andExpect(status().isOk());

        changePassword(token, c.password() + "x", "yet-another-password-1")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("PASSWORD_CHANGE_USED"));

        login(c.username(), c.password() + "x");
        mockMvc.perform(post("/api/v1/research/auth/login").contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"password\": \"%s\" }".formatted(c.username(), c.password())))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void changeMustDifferAndBeLongEnough() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), "short").andExpect(status().isBadRequest());
        changePassword(token, c.password(), c.password()).andExpect(status().isBadRequest());
        changePassword(token, "wrong-current-password", NEW_PASSWORD).andExpect(status().isUnauthorized());
    }

    @Test
    void adminResetEndsSessionsAndGrantsOneMoreChange() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());

        MvcResult reset = adminPost("/api/v1/admin/researchers/" + c.id() + "/reset-password")
                .andExpect(status().isOk()).andReturn();
        String issued = JsonPath.read(reset.getResponse().getContentAsString(), "$.data.password");

        researchGet(token, "/api/v1/research/auth/me")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.data.code").value("SESSION_ENDED"));

        String fresh = login(c.username(), issued);
        researchGet(fresh, "/api/v1/research/catalog").andExpect(status().isForbidden());
        changePassword(fresh, issued, "second-chosen-password").andExpect(status().isOk());
        researchGet(fresh, "/api/v1/research/catalog").andExpect(status().isOk());
    }

    @Test
    void revokeCutsOffLiveTokensAndSignInUntilRestored() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());

        adminPost("/api/v1/admin/researchers/" + c.id() + "/revoke").andExpect(status().isOk());
        researchGet(token, "/api/v1/research/catalog")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.data.code").value("ACCESS_REVOKED"));
        mockMvc.perform(post("/api/v1/research/auth/login").contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"password\": \"%s\" }".formatted(c.username(), NEW_PASSWORD)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("ACCESS_REVOKED"));

        adminPost("/api/v1/admin/researchers/" + c.id() + "/restore").andExpect(status().isOk());
        String again = login(c.username(), NEW_PASSWORD);
        researchGet(again, "/api/v1/research/catalog").andExpect(status().isOk());
    }

    @Test
    void expiredGrantCutsOffImmediately() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());

        String past = OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1).toString();
        adminPut("/api/v1/admin/researchers/" + c.id() + "/grant",
                grantJson("AGGREGATE", "\"VITALS\"", false, null, null, past)).andExpect(status().isOk());
        researchGet(token, "/api/v1/research/catalog")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.data.code").value("ACCESS_EXPIRED"));
    }

    @Test
    void grantLimitsAreEnforced() throws Exception {
        String token = readyResearcher(VITALS_ONLY);
        researchGet(token, "/api/v1/research/catalog")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.datasets[0]").value("VITALS"))
                .andExpect(jsonPath("$.data.metrics[?(@.dataset == 'ACTIVITY')]").isEmpty());

        researchPost(token, "/api/v1/research/analytics/describe", "{ \"metric\": \"activity_minutes\" }")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("DATASET_NOT_GRANTED"));
        researchPost(token, "/api/v1/research/cohorts/preview", "{ \"definition\": { \"ageBands\": [\"40-49\"] } }")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("DATASET_NOT_GRANTED"));
        researchPost(token, "/api/v1/research/records/vitals", "{}")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("RECORDS_NOT_GRANTED"));
        researchPost(token, "/api/v1/research/analytics/describe?format=csv", "{ \"metric\": \"systolic\" }")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.data.code").value("EXPORT_NOT_GRANTED"));
        // A refused download must not have run the analysis first.
        Integer refusedRows = jdbcTemplate.queryForObject("""
                SELECT rows_returned FROM research_audit_log
                 WHERE status = 403 AND params->>'format' = 'csv' ORDER BY id DESC LIMIT 1""", Integer.class);
        assertThat(refusedRows).isNull();
        researchPost(token, "/api/v1/research/analytics/describe", "{ \"metric\": \"no_such_metric\" }")
                .andExpect(status().isBadRequest());
    }

    @Test
    void researchersCannotEditTheirProfile() throws Exception {
        String token = readyResearcher(VITALS_ONLY);
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/v1/research/auth/me")
                        .header("Authorization", "Bearer " + token).contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"hijack\" }"))
                .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void everyResearcherRequestIsAudited() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        UUID id = UUID.fromString(c.id());

        mockMvc.perform(post("/api/v1/research/auth/login").contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"password\": \"wrong-password-here\" }".formatted(c.username())))
                .andExpect(status().isUnauthorized());
        String token = login(c.username(), c.password());
        researchGet(token, "/api/v1/research/catalog").andExpect(status().isForbidden()); // before change
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());
        researchPost(token, "/api/v1/research/analytics/describe", "{ \"metric\": \"systolic\" }").andExpect(status().isOk());

        Integer rows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM research_audit_log WHERE researcher_id = ?", Integer.class, id);
        assertThat(rows).isEqualTo(5);
        String describeParams = jdbcTemplate.queryForObject(
                "SELECT params::text FROM research_audit_log WHERE researcher_id = ? AND path LIKE '%describe'", String.class, id);
        assertThat(describeParams).contains("systolic");
        String changeParams = jdbcTemplate.queryForObject(
                "SELECT COALESCE(params::text, '') FROM research_audit_log WHERE researcher_id = ? AND path LIKE '%change-password'",
                String.class, id);
        assertThat(changeParams).doesNotContain(NEW_PASSWORD).doesNotContain(c.password());

        mockMvc.perform(get("/api/v1/admin/research-activity?researcherId=" + id).header("Authorization", "Bearer " + admin))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(5))
                .andExpect(jsonPath("$.data.items[0].researcherUsername").value(c.username()));
    }

    @Test
    void adminActionsAreRecorded() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        adminPut("/api/v1/admin/researchers/" + c.id() + "/grant",
                grantJson("PSEUDONYMOUS", "\"VITALS\"", true, "2026-01-01", "2026-12-31", null)).andExpect(status().isOk());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/revoke").andExpect(status().isOk());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/restore").andExpect(status().isOk());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/reset-password").andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/admin/researchers/" + c.id() + "/events").header("Authorization", "Bearer " + admin))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(5))
                .andExpect(jsonPath("$.data[0].action").value("PASSWORD_RESET"))
                .andExpect(jsonPath("$.data[4].action").value("CREATED"))
                .andExpect(jsonPath("$.data[0].adminUsername").value("test-admin"));
    }

    private org.springframework.test.web.servlet.ResultActions archive(String id, String reason) throws Exception {
        return mockMvc.perform(post("/api/v1/admin/researchers/" + id + "/archive").header("Authorization", "Bearer " + admin)
                .contentType(APPLICATION_JSON).content(reason == null ? "{}" : "{ \"reason\": \"" + reason + "\" }"));
    }

    @Test
    void deletingArchivesTheResearcherAndKeepsTheirHistory() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        String token = login(c.username(), c.password());
        changePassword(token, c.password(), NEW_PASSWORD).andExpect(status().isOk());
        researchPost(token, "/api/v1/research/analytics/describe", "{ \"metric\": \"systolic\" }").andExpect(status().isOk());

        archive(c.id(), null).andExpect(status().isBadRequest());
        archive(c.id(), "Study ended").andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ARCHIVED"))
                .andExpect(jsonPath("$.data.archiveReason").value("Study ended"))
                .andExpect(jsonPath("$.data.archivedBy").value("test-admin"));

        // Out of the working list, into the archive.
        mockMvc.perform(get("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data[?(@.id == '" + c.id() + "')]").isEmpty());
        mockMvc.perform(get("/api/v1/admin/researchers/archive").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data[?(@.id == '" + c.id() + "')].archiveReason").value("Study ended"));

        // Cut off at once, and can't sign back in.
        researchGet(token, "/api/v1/research/catalog")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.data.code").value("ACCESS_REVOKED"));
        mockMvc.perform(post("/api/v1/research/auth/login").contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"password\": \"%s\" }".formatted(c.username(), NEW_PASSWORD)))
                .andExpect(status().isForbidden());

        // Read-only while archived.
        adminPut("/api/v1/admin/researchers/" + c.id() + "/grant", VITALS_ONLY).andExpect(status().isBadRequest());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/revoke").andExpect(status().isBadRequest());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/restore").andExpect(status().isBadRequest());
        adminPost("/api/v1/admin/researchers/" + c.id() + "/reset-password").andExpect(status().isBadRequest());
        archive(c.id(), "Again").andExpect(status().isBadRequest());

        // The username stays reserved.
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"%s\", \"fullName\": \"Someone Else\", \"grant\": %s }".formatted(c.username(), VITALS_ONLY)))
                .andExpect(status().isConflict());

        // History is still there for audits.
        mockMvc.perform(get("/api/v1/admin/researchers/" + c.id()).header("Authorization", "Bearer " + admin))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/admin/research-activity?researcherId=" + c.id()).header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data.items[?(@.path == '/api/v1/research/analytics/describe')]").isNotEmpty())
                .andExpect(jsonPath("$.data.items[0].researcherStatus").value("ARCHIVED"));
        mockMvc.perform(get("/api/v1/admin/researchers/" + c.id() + "/events").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data[0].action").value("ARCHIVED"))
                .andExpect(jsonPath("$.data[0].detailsJson", org.hamcrest.Matchers.containsString("Study ended")));
    }

    @Test
    void restoringFromTheArchiveReturnsARevokedAccount() throws Exception {
        Created c = createResearcher(VITALS_ONLY);
        archive(c.id(), "Mistake").andExpect(status().isOk());

        adminPost("/api/v1/admin/researchers/" + c.id() + "/unarchive").andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("REVOKED"))
                .andExpect(jsonPath("$.data.archiveReason").doesNotExist());
        mockMvc.perform(get("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data[?(@.id == '" + c.id() + "')].status").value("REVOKED"));
        adminPost("/api/v1/admin/researchers/" + c.id() + "/unarchive").andExpect(status().isBadRequest());

        adminPost("/api/v1/admin/researchers/" + c.id() + "/restore").andExpect(status().isOk());
        MvcResult reset = adminPost("/api/v1/admin/researchers/" + c.id() + "/reset-password").andExpect(status().isOk()).andReturn();
        String issued = JsonPath.read(reset.getResponse().getContentAsString(), "$.data.password");
        String token = login(c.username(), issued);
        researchGet(token, "/api/v1/research/catalog")
                .andExpect(jsonPath("$.data.code").value("PASSWORD_CHANGE_REQUIRED"));
        mockMvc.perform(get("/api/v1/admin/researchers/" + c.id() + "/events").header("Authorization", "Bearer " + admin))
                .andExpect(jsonPath("$.data[*].action", org.hamcrest.Matchers.hasItems("ARCHIVED", "UNARCHIVED")));
    }

    @Test
    void invalidGrantIsRejected() throws Exception {
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"valid-name\", \"fullName\": \"X\", \"grant\": %s }"
                                .formatted(grantJson("AGGREGATE", "", false, null, null, null))))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"valid-name-2\", \"fullName\": \"X\", \"grant\": %s }"
                                .formatted(grantJson("AGGREGATE", "\"VITALS\"", false, "2026-12-01", "2026-01-01", null))))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/admin/researchers").header("Authorization", "Bearer " + admin)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"username\": \"Bad Name!\", \"fullName\": \"X\", \"grant\": %s }".formatted(VITALS_ONLY)))
                .andExpect(status().isBadRequest());
    }
}
