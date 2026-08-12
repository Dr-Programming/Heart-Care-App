package com.heartcare.sync;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.heartcare.AbstractIntegrationTest;
import com.heartcare.TestUsers;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SyncControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired WebApplicationContext wac;
    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).apply(springSecurity()).build();
    }

    /**
     * Registers a user and returns its bearer token. Copied verbatim from
     * ActivityControllerIntegrationTest so the auth flow matches the rest of the suite.
     */
    private String registerAndGetToken() throws Exception {
        ObjectNode body = objectMapper.createObjectNode();
        body.put("phone", TestUsers.nextPhone());
        body.put("pin", "1234");
        body.put("name", "Abebe");
        body.put("preferredLanguage", "en");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON).content(body.toString()))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    private String syncBody(String records) {
        return "{\"records\":[" + records + "]}";
    }

    private String vitalRecord(UUID crid, int systolic) {
        return """
                {"clientRecordId":"%s","entityType":"VITAL","payload":
                 {"type":"BLOOD_PRESSURE","values":{"systolic":%d,"diastolic":82},
                  "measuredAt":"2026-07-17T08:30:00+03:00"}}""".formatted(crid, systolic);
    }

    @Test
    void unauthenticatedReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(syncBody(vitalRecord(UUID.randomUUID(), 128))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void mixedBatchReturnsAllFourStatuses() throws Exception {
        String token = registerAndGetToken();
        UUID saved = UUID.randomUUID();
        UUID duplicate = UUID.randomUUID();
        UUID conflict = UUID.randomUUID();
        UUID rejected = UUID.randomUUID();
        UUID unknown = UUID.randomUUID();

        // Seed the duplicate and conflict keys.
        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(syncBody(vitalRecord(duplicate, 128) + "," + vitalRecord(conflict, 128))))
                .andExpect(status().isOk());

        String batch = String.join(",",
                vitalRecord(saved, 130),
                vitalRecord(duplicate, 128),          // identical resend
                vitalRecord(conflict, 155),           // divergent under the same key
                """
                {"clientRecordId":"%s","entityType":"VITAL","payload":
                 {"type":"BLOOD_PRESSURE","values":{"systolic":9000,"diastolic":82}}}""".formatted(rejected),
                """
                {"clientRecordId":"%s","entityType":"FOO","payload":{}}""".formatted(unknown));

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(syncBody(batch)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("SAVED"))
                .andExpect(jsonPath("$.data.results[0].serverId").exists())
                .andExpect(jsonPath("$.data.results[1].status").value("DUPLICATE"))
                .andExpect(jsonPath("$.data.results[2].status").value("CONFLICT"))
                .andExpect(jsonPath("$.data.results[3].status").value("REJECTED"))
                .andExpect(jsonPath("$.data.results[3].reason").exists())
                .andExpect(jsonPath("$.data.results[4].status").value("REJECTED"))
                .andExpect(jsonPath("$.data.results[4].reason").value(
                        org.hamcrest.Matchers.containsString("unknown entityType")));
    }

    /** One invalid record must not stop its neighbours committing (design Decision 4). */
    @Test
    void invalidRecordDoesNotBlockNeighbours() throws Exception {
        String token = registerAndGetToken();
        UUID good = UUID.randomUUID();
        String batch = String.join(",",
                """
                {"clientRecordId":"%s","entityType":"VITAL","payload":
                 {"type":"BLOOD_PRESSURE","values":{"systolic":9000,"diastolic":82}}}"""
                        .formatted(UUID.randomUUID()),
                vitalRecord(good, 128));

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(syncBody(batch)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.data.results[1].status").value("SAVED"));
    }

    /** Decision 8, end to end: add a medication and log its dose in one batch, never having synced. */
    @Test
    void medicationAndItsDoseSyncInOneBatch() throws Exception {
        String token = registerAndGetToken();
        UUID medCrid = UUID.randomUUID();
        String batch = String.join(",",
                // Dose first in the request: SyncService must still process the medication first.
                """
                {"clientRecordId":"%s","entityType":"DOSE_LOG","payload":
                 {"medicationClientRecordId":"%s","status":"TAKEN","scheduledDate":"2026-07-17",
                  "loggedAt":"2026-07-17T08:05:00+03:00"}}""".formatted(UUID.randomUUID(), medCrid),
                """
                {"clientRecordId":"%s","entityType":"MEDICATION","payload":
                 {"name":"Atorvastatin","doseMg":20,"frequency":"ONCE_DAILY","scheduleTimes":["08:00"]}}"""
                        .formatted(medCrid));

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(syncBody(batch)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("SAVED"))   // dose, request order
                .andExpect(jsonPath("$.data.results[1].status").value("SAVED"));  // medication
    }

    /** The transient-retry path: re-sending the whole batch must be safe (design §7). */
    @Test
    void resendingTheWholeBatchYieldsAllDuplicates() throws Exception {
        String token = registerAndGetToken();
        String batch = vitalRecord(UUID.randomUUID(), 128) + "," + vitalRecord(UUID.randomUUID(), 132);

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(syncBody(batch)));

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(syncBody(batch)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("DUPLICATE"))
                .andExpect(jsonPath("$.data.results[1].status").value("DUPLICATE"));
    }

    /**
     * Cross-user isolation (design's planned test, closing the gap flagged in whole-branch
     * review): dedup is keyed on (user_id, client_record_id), so the SAME clientRecordId used
     * by two different users must resolve to two distinct rows, not a DUPLICATE collision.
     */
    @Test
    void sameClientRecordIdAcrossUsersProducesDistinctRows() throws Exception {
        String tokenA = registerAndGetToken();
        String tokenB = registerAndGetToken();
        UUID sharedCrid = UUID.randomUUID();

        MvcResult resultA = mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(syncBody(vitalRecord(sharedCrid, 128))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("SAVED"))
                .andReturn();
        String serverIdA = JsonPath.read(resultA.getResponse().getContentAsString(),
                "$.data.results[0].serverId");

        MvcResult resultB = mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(syncBody(vitalRecord(sharedCrid, 128))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.results[0].status").value("SAVED"))
                .andReturn();
        String serverIdB = JsonPath.read(resultB.getResponse().getContentAsString(),
                "$.data.results[0].serverId");

        org.assertj.core.api.Assertions.assertThat(serverIdA).isNotEqualTo(serverIdB);
    }

    @Test
    void emptyBatchReturns400() throws Exception {
        String token = registerAndGetToken();
        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"records\":[]}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void recordMissingClientRecordIdReturns400() throws Exception {
        String token = registerAndGetToken();
        String body = syncBody("""
                {"entityType":"VITAL","payload":{"type":"BLOOD_PRESSURE",
                 "values":{"systolic":128,"diastolic":82}}}""");

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
    }

    @Test
    void overCapBatchReturns400() throws Exception {
        String token = registerAndGetToken();
        String records = IntStream.range(0, 201)
                .mapToObj(i -> vitalRecord(UUID.randomUUID(), 128))
                .collect(Collectors.joining(","));

        mockMvc.perform(post("/api/v1/sync").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(syncBody(records)))
                .andExpect(status().isBadRequest());
    }
}
