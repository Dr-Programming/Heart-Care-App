package com.heartcare.auth;

import com.heartcare.common.exception.BadRequestException;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Puts an answer into one canonical form before it is hashed or compared, so that
 * "Bole Primary", " bole  primary " and "BOLE PRIMARY" all count as the same answer. Patients
 * typing on a phone, sometimes in a hurry and sometimes switching keyboards, should not fail
 * recovery over capitals or spaces.
 *
 * <p>The mobile app applies exactly the same steps for its offline check
 * ({@code answer_normalizer.dart}): trim, collapse whitespace runs to one space, lowercase
 * (locale-independent). There is deliberately no Unicode NFKC step: the phone has no NFKC
 * implementation, and the two checks must agree.
 */
public final class SecurityAnswerNormalizer {

    static final int MIN_LENGTH = 2;
    static final int MAX_LENGTH = 100;

    private static final Pattern WHITESPACE = Pattern.compile("\\s+", Pattern.UNICODE_CHARACTER_CLASS);

    private SecurityAnswerNormalizer() {
    }

    /** @throws BadRequestException if the normalised answer is shorter than 2 or longer than 100 characters */
    public static String normalize(String answer) {
        if (answer == null) {
            throw new BadRequestException("answer is required");
        }
        String normalized = WHITESPACE.matcher(answer.strip())
                .replaceAll(" ")
                .toLowerCase(Locale.ROOT);
        int length = normalized.codePointCount(0, normalized.length());
        if (length < MIN_LENGTH || length > MAX_LENGTH) {
            throw new BadRequestException(
                    "answers must be between " + MIN_LENGTH + " and " + MAX_LENGTH + " characters");
        }
        return normalized;
    }
}
