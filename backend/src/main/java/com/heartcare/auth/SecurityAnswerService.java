package com.heartcare.auth;

import com.heartcare.auth.dto.SecurityAnswerInput;
import com.heartcare.auth.model.SecurityAnswer;
import com.heartcare.auth.model.SecurityQuestion;
import com.heartcare.common.exception.BadRequestException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Stores and checks the answers to a patient's three recovery questions.
 *
 * <p>Answers are normalised (SecurityAnswerNormalizer) and kept only as BCrypt hashes. Checking
 * always runs the same number of BCrypt comparisons, right answers or wrong, known phone or not,
 * so response time says nothing about which answer was wrong or whether the account exists.
 */
@Service
public class SecurityAnswerService {

    static final int REQUIRED_ANSWERS = 3;

    /** Hashed at startup and checked against when there is no real answer to compare with. */
    private static final String DUMMY_ANSWER = "no-such-answer";

    private final SecurityAnswerRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final String dummyHash;
    private final byte[] decoyKey;

    public SecurityAnswerService(SecurityAnswerRepository repository,
                                 PasswordEncoder passwordEncoder,
                                 @Value("${app.jwt.secret}") String jwtSecret) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.dummyHash = passwordEncoder.encode(DUMMY_ANSWER);
        // A separate key for decoy questions, derived from the JWT secret with its own label, so
        // no new secret has to be configured and the two uses never share a key.
        this.decoyKey = hmac(jwtSecret.getBytes(StandardCharsets.UTF_8), "pin-recovery-decoy-v1");
    }

    /** A normalised, validated answer, ready to hash. */
    public record PreparedAnswer(SecurityQuestion question, String normalizedAnswer) {
    }

    public List<SecurityQuestion> catalogue() {
        return List.of(SecurityQuestion.values());
    }

    /**
     * Checks an answer set before anything is saved: exactly three answers, three different
     * questions, each answer 2–100 characters after normalising.
     *
     * @throws BadRequestException if any rule is broken
     */
    public List<PreparedAnswer> prepare(List<SecurityAnswerInput> answers) {
        if (answers == null || answers.size() != REQUIRED_ANSWERS) {
            throw new BadRequestException("exactly " + REQUIRED_ANSWERS + " security answers are required");
        }
        Set<SecurityQuestion> seen = EnumSet.noneOf(SecurityQuestion.class);
        List<PreparedAnswer> prepared = new ArrayList<>();
        for (SecurityAnswerInput input : answers) {
            if (input == null || input.questionId() == null) {
                throw new BadRequestException("questionId is required");
            }
            if (!seen.add(input.questionId())) {
                throw new BadRequestException("security answers must use " + REQUIRED_ANSWERS + " different questions");
            }
            prepared.add(new PreparedAnswer(input.questionId(), SecurityAnswerNormalizer.normalize(input.answer())));
        }
        return prepared;
    }

    /** Replaces all of the user's answers with {@code prepared}. */
    @Transactional
    public void store(UUID userId, List<PreparedAnswer> prepared) {
        repository.deleteByUserId(userId);
        for (PreparedAnswer answer : prepared) {
            repository.save(new SecurityAnswer(userId, answer.question(),
                    passwordEncoder.encode(answer.normalizedAnswer())));
        }
    }

    @Transactional(readOnly = true)
    public List<SecurityQuestion> questionsOf(UUID userId) {
        return repository.findByUserId(userId).stream()
                .map(SecurityAnswer::getQuestion)
                .sorted()
                .toList();
    }

    /**
     * The questions to show for a phone during recovery. For a phone with no account, or an
     * account with no answers, it returns three questions picked from a keyed hash of the phone
     * number: always the same three for the same phone, and indistinguishable from a real set.
     * That way this endpoint can't be used to find out which numbers have accounts.
     */
    @Transactional(readOnly = true)
    public List<SecurityQuestion> questionsForRecovery(UUID userIdOrNull, String phone) {
        if (userIdOrNull != null) {
            List<SecurityQuestion> real = questionsOf(userIdOrNull);
            if (!real.isEmpty()) {
                return real;
            }
        }
        return decoyQuestions(phone);
    }

    /**
     * True only if {@code given} answers exactly the user's stored questions, each correctly.
     * Always performs {@value #REQUIRED_ANSWERS} BCrypt comparisons.
     */
    @Transactional(readOnly = true)
    public boolean matches(UUID userId, List<SecurityAnswerInput> given) {
        Map<SecurityQuestion, String> stored = new EnumMap<>(SecurityQuestion.class);
        for (SecurityAnswer answer : repository.findByUserId(userId)) {
            stored.put(answer.getQuestion(), answer.getAnswerHash());
        }
        if (stored.size() != REQUIRED_ANSWERS) {
            burnEquivalentWork();
            return false;
        }

        Map<SecurityQuestion, String> givenByQuestion = new EnumMap<>(SecurityQuestion.class);
        boolean wellFormed = given != null && given.size() == REQUIRED_ANSWERS;
        if (wellFormed) {
            for (SecurityAnswerInput input : given) {
                if (input == null || input.questionId() == null
                        || givenByQuestion.put(input.questionId(), input.answer()) != null) {
                    wellFormed = false;
                }
            }
        }

        // No early exit: every stored hash is checked, so timing does not reveal which was wrong.
        boolean allMatch = wellFormed;
        for (Map.Entry<SecurityQuestion, String> entry : stored.entrySet()) {
            String candidate = normalizeOrNull(givenByQuestion.get(entry.getKey()));
            boolean match = passwordEncoder.matches(candidate == null ? DUMMY_ANSWER : candidate, entry.getValue());
            allMatch &= candidate != null && match;
        }
        return allMatch;
    }

    /** Spends the same BCrypt work as {@link #matches} when there is nothing real to compare. */
    public void burnEquivalentWork() {
        for (int i = 0; i < REQUIRED_ANSWERS; i++) {
            passwordEncoder.matches(DUMMY_ANSWER, dummyHash);
        }
    }

    private static String normalizeOrNull(String answer) {
        try {
            return answer == null ? null : SecurityAnswerNormalizer.normalize(answer);
        } catch (BadRequestException e) {
            return null;   // too short or long: cannot be right, but still costs a full check
        }
    }

    private List<SecurityQuestion> decoyQuestions(String phone) {
        SecurityQuestion[] all = SecurityQuestion.values();
        byte[] digest = hmac(decoyKey, phone);
        Set<SecurityQuestion> picked = EnumSet.noneOf(SecurityQuestion.class);
        for (byte b : digest) {
            picked.add(all[Math.floorMod(b, all.length)]);
            if (picked.size() == REQUIRED_ANSWERS) {
                break;
            }
        }
        // 32 random bytes over 8 questions all but guarantee three distinct picks; top up in
        // catalogue order on the vanishingly rare digest that doesn't.
        Arrays.stream(all).filter(q -> picked.size() < REQUIRED_ANSWERS).forEach(picked::add);
        return picked.stream().sorted(Comparator.naturalOrder()).toList();
    }

    private static byte[] hmac(byte[] key, String message) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(message.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HmacSHA256 is required by every Java platform", e);
        }
    }
}
