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

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Forgot PIN through security questions. */
class PinRecoveryIntegrationTest extends AbstractIntegrationTest {

    private static final String ANSWERS = """
            [ { "questionId": "FIRST_SCHOOL", "answer": "Bole Primary" },
              { "questionId": "CHILDHOOD_FRIEND", "answer": "Dawit" },
              { "questionId": "FAVORITE_TEACHER", "answer": "Ato Kebede" } ]""";

    private static final String SAME_ANSWERS_DIFFERENT_TYPING = """
            [ { "questionId": "FIRST_SCHOOL", "answer": "  bole   PRIMARY " },
              { "questionId": "CHILDHOOD_FRIEND", "answer": "DAWIT" },
              { "questionId": "FAVORITE_TEACHER", "answer": "ato kebede" } ]""";

    private static final String ONE_WRONG = """
            [ { "questionId": "FIRST_SCHOOL", "answer": "Bole Primary" },
              { "questionId": "CHILDHOOD_FRIEND", "answer": "Dawit" },
              { "questionId": "FAVORITE_TEACHER", "answer": "Wrong Teacher" } ]""";

    @Autowired
    WebApplicationContext wac;

    MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac)
                .apply(SecurityMockMvcConfigurers.springSecurity())
                .build();
    }

    private String register(String phone, String securityAnswersJson) throws Exception {
        String answers = securityAnswersJson == null ? "" : ", \"securityAnswers\": " + securityAnswersJson;
        return mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"phone\": \"%s\", \"pin\": \"1234\", \"name\": \"Abebe\", \"preferredLanguage\": \"en\"%s }"
                                .formatted(phone, answers)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
    }

    private ResultActions resetPin(String phone, String answersJson, String newPin) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/reset-pin")
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\", \"answers\": %s, \"newPin\": \"%s\" }".formatted(phone, answersJson, newPin)));
    }

    private ResultActions recoveryQuestions(String phone) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/recovery/questions")
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\" }".formatted(phone)));
    }

    private ResultActions login(String phone, String pin) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/login")
                .contentType(APPLICATION_JSON)
                .content("{ \"phone\": \"%s\", \"pin\": \"%s\" }".formatted(phone, pin)));
    }

    private ResultActions refresh(String token) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/refresh")
                .contentType(APPLICATION_JSON)
                .content("{ \"refreshToken\": \"" + token + "\" }"));
    }

    // ---- catalogue and setup -----------------------------------------------------------------

    @Test
    void catalogueIsPublic() throws Exception {
        mockMvc.perform(get("/api/v1/auth/security-questions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(8)));
    }

    @Test
    void registrationWithoutAnswersStillWorks() throws Exception {
        String body = register(TestUsers.nextPhone(), null);
        String token = JsonPath.read(body, "$.data.token");

        mockMvc.perform(get("/api/v1/auth/security-answers").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.configured").value(false))
                .andExpect(jsonPath("$.data.questions", hasSize(0)));
    }

    @Test
    void registrationWithAnswersStoresTheChosenQuestions() throws Exception {
        String phone = TestUsers.nextPhone();
        String token = JsonPath.read(register(phone, ANSWERS), "$.data.token");

        mockMvc.perform(get("/api/v1/auth/security-answers").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.data.configured").value(true))
                .andExpect(jsonPath("$.data.questions",
                        containsInAnyOrder("FIRST_SCHOOL", "CHILDHOOD_FRIEND", "FAVORITE_TEACHER")));

        recoveryQuestions(phone)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questions",
                        containsInAnyOrder("FIRST_SCHOOL", "CHILDHOOD_FRIEND", "FAVORITE_TEACHER")));
    }

    @Test
    void invalidAnswerSetsAreRejectedAtRegistration() throws Exception {
        String twoAnswers = """
                [ { "questionId": "FIRST_SCHOOL", "answer": "Bole" },
                  { "questionId": "CHILDHOOD_FRIEND", "answer": "Dawit" } ]""";
        String repeated = """
                [ { "questionId": "FIRST_SCHOOL", "answer": "Bole" },
                  { "questionId": "FIRST_SCHOOL", "answer": "Dawit" },
                  { "questionId": "FAVORITE_TEACHER", "answer": "Kebede" } ]""";
        String unknownQuestion = """
                [ { "questionId": "MOTHERS_NAME", "answer": "Almaz" },
                  { "questionId": "CHILDHOOD_FRIEND", "answer": "Dawit" },
                  { "questionId": "FAVORITE_TEACHER", "answer": "Kebede" } ]""";
        for (String answers : List.of(twoAnswers, repeated, unknownQuestion)) {
            mockMvc.perform(post("/api/v1/auth/register")
                            .contentType(APPLICATION_JSON)
                            .content("{ \"phone\": \"%s\", \"pin\": \"1234\", \"name\": \"Abebe\", \"preferredLanguage\": \"en\", \"securityAnswers\": %s }"
                                    .formatted(TestUsers.nextPhone(), answers)))
                    .andExpect(status().isBadRequest());
        }
    }

    // ---- reset -------------------------------------------------------------------------------

    @Test
    void correctAnswersResetThePinAndSignOutOtherDevices() throws Exception {
        String phone = TestUsers.nextPhone();
        String oldRefresh = JsonPath.read(register(phone, ANSWERS), "$.data.refreshToken");

        resetPin(phone, SAME_ANSWERS_DIFFERENT_TYPING, "5678")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").exists())
                .andExpect(jsonPath("$.data.refreshToken").exists());

        login(phone, "1234").andExpect(status().isUnauthorized());
        login(phone, "5678").andExpect(status().isOk());
        refresh(oldRefresh).andExpect(status().isUnauthorized());
    }

    @Test
    void oneWrongAnswerIsRejectedWithoutSayingWhichOne() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);

        resetPin(phone, ONE_WRONG, "5678")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("The answers don't match"));
        login(phone, "1234").andExpect(status().isOk());
    }

    @Test
    void answeringDifferentQuestionsThanTheStoredOnesFails() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);
        String otherQuestions = """
                [ { "questionId": "CHILDHOOD_STREET", "answer": "Bole Primary" },
                  { "questionId": "CHILDHOOD_FRIEND", "answer": "Dawit" },
                  { "questionId": "FAVORITE_TEACHER", "answer": "Ato Kebede" } ]""";

        resetPin(phone, otherQuestions, "5678").andExpect(status().isBadRequest());
    }

    @Test
    void fiveWrongAttemptsLockRecovery() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);

        for (int attempt = 1; attempt <= 4; attempt++) {
            resetPin(phone, ONE_WRONG, "5678").andExpect(status().isBadRequest());
        }
        resetPin(phone, ONE_WRONG, "5678")
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.endsWith("in 60 minutes.")));

        // Locked means locked: even the right answers are refused until the window passes.
        resetPin(phone, ANSWERS, "5678").andExpect(status().isLocked());
        // The PIN itself still works; only recovery is locked.
        login(phone, "1234").andExpect(status().isOk());
    }

    @Test
    void recoveryWorksWhileThePinLockoutIsActiveAndClearsIt() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);
        for (int attempt = 1; attempt <= 5; attempt++) {
            login(phone, "9999");
        }
        login(phone, "1234").andExpect(status().isLocked());

        resetPin(phone, ANSWERS, "5678").andExpect(status().isOk());
        login(phone, "5678").andExpect(status().isOk());
    }

    @Test
    void unknownPhoneLooksLikeWrongAnswers() throws Exception {
        String phone = TestUsers.nextPhone();   // never registered

        resetPin(phone, ANSWERS, "5678")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("The answers don't match"));

        String first = recoveryQuestions(phone).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questions", hasSize(3)))
                .andReturn().getResponse().getContentAsString();
        String second = recoveryQuestions(phone).andReturn().getResponse().getContentAsString();
        List<String> a = JsonPath.read(first, "$.data.questions");
        List<String> b = JsonPath.read(second, "$.data.questions");
        assertThat(a).isEqualTo(b).doesNotHaveDuplicates();
    }

    @Test
    void accountWithoutAnswersCannotBeReset() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, null);

        resetPin(phone, ANSWERS, "5678").andExpect(status().isBadRequest());
        recoveryQuestions(phone).andExpect(jsonPath("$.data.questions", hasSize(3)));
        login(phone, "1234").andExpect(status().isOk());
    }

    @Test
    void malformedResetRequestReturns400() throws Exception {
        resetPin(TestUsers.nextPhone(), ANSWERS, "12ab").andExpect(status().isBadRequest());
        resetPin("0911000000", ANSWERS, "5678").andExpect(status().isBadRequest());
    }

    // ---- changing answers --------------------------------------------------------------------

    @Test
    void answersCanBeReplacedWithTheCurrentPin() throws Exception {
        String phone = TestUsers.nextPhone();
        String token = JsonPath.read(register(phone, ANSWERS), "$.data.token");
        String newAnswers = """
                [ { "questionId": "CHILDHOOD_STREET", "answer": "Piassa" },
                  { "questionId": "FIRST_JOB_PLACE", "answer": "Merkato" },
                  { "questionId": "CHILDHOOD_HERO", "answer": "Abebe Bikila" } ]""";

        mockMvc.perform(put("/api/v1/auth/security-answers")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"currentPin\": \"1234\", \"answers\": %s }".formatted(newAnswers)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questions",
                        containsInAnyOrder("CHILDHOOD_STREET", "FIRST_JOB_PLACE", "CHILDHOOD_HERO")));

        resetPin(phone, ANSWERS, "5678").andExpect(status().isBadRequest());
        resetPin(phone, newAnswers, "5678").andExpect(status().isOk());
    }

    @Test
    void replacingAnswersNeedsTheCorrectPin() throws Exception {
        String token = JsonPath.read(register(TestUsers.nextPhone(), ANSWERS), "$.data.token");

        mockMvc.perform(put("/api/v1/auth/security-answers")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{ \"currentPin\": \"9999\", \"answers\": %s }".formatted(ANSWERS)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Current PIN is incorrect"));
    }

    @Test
    void replacingAnswersNeedsAnAccessToken() throws Exception {
        mockMvc.perform(put("/api/v1/auth/security-answers")
                        .contentType(APPLICATION_JSON)
                        .content("{ \"currentPin\": \"1234\", \"answers\": %s }".formatted(ANSWERS)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void resetRetryWithTheSameChangeIdSucceedsAgain() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);
        String body = "{ \"phone\": \"%s\", \"answers\": %s, \"newPin\": \"5678\", \"changeId\": \"%s\" }"
                .formatted(phone, ANSWERS, java.util.UUID.randomUUID());

        mockMvc.perform(post("/api/v1/auth/reset-pin").contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/auth/reset-pin").contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isOk());
        login(phone, "5678").andExpect(status().isOk());
    }

    @Test
    void aResetReplayIsRefusedWhileRecoveryIsLocked() throws Exception {
        String phone = TestUsers.nextPhone();
        register(phone, ANSWERS);
        String body = "{ \"phone\": \"%s\", \"answers\": %s, \"newPin\": \"5678\", \"changeId\": \"%s\" }"
                .formatted(phone, ANSWERS, java.util.UUID.randomUUID());
        mockMvc.perform(post("/api/v1/auth/reset-pin").contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isOk());
        for (int attempt = 1; attempt <= 5; attempt++) {
            resetPin(phone, ONE_WRONG, "1111");
        }

        mockMvc.perform(post("/api/v1/auth/reset-pin").contentType(APPLICATION_JSON).content(body))
                .andExpect(status().isLocked());
    }
}
