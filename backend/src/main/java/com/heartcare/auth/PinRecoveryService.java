package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.ResetPinRequest;
import com.heartcare.auth.dto.SecurityAnswerInput;
import com.heartcare.auth.dto.SecurityQuestionsResponse;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.AccountLockedException;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ResourceNotFoundException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Forgot PIN through security questions.
 *
 * <p>The server is the authority: it never accepts a new PIN because the app says the answers were
 * right. A reset the app did offline is simply this same request, sent once the phone is back
 * online, and the answers are checked here again.
 *
 * <p>Recovery has its own lockout (app.auth.recovery.*), separate from the PIN lockout, because a
 * patient who forgot the PIN has often just locked it.
 */
@Service
public class PinRecoveryService {

    static final String ANSWERS_DONT_MATCH = "The answers don't match";

    private final UserRepository userRepository;
    private final SecurityAnswerService answers;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final AuthService authService;
    private final int maxAttempts;
    private final int lockoutMinutes;

    public PinRecoveryService(UserRepository userRepository,
                              SecurityAnswerService answers,
                              PasswordEncoder passwordEncoder,
                              RefreshTokenService refreshTokenService,
                              AuthService authService,
                              @Value("${app.auth.recovery.max-attempts}") int maxAttempts,
                              @Value("${app.auth.recovery.duration-minutes}") int lockoutMinutes) {
        if (maxAttempts < 1 || lockoutMinutes < 1) {
            throw new IllegalArgumentException("app.auth.recovery.max-attempts and duration-minutes must be at least 1");
        }
        this.userRepository = userRepository;
        this.answers = answers;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.authService = authService;
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
    }

    /** The three questions to ask for {@code phone}. Unknown phones get stable decoy questions. */
    @Transactional(readOnly = true)
    public SecurityQuestionsResponse recoveryQuestions(String phone) {
        UUID userId = userRepository.findByPhone(phone).map(User::getId).orElse(null);
        return new SecurityQuestionsResponse(null, answers.questionsForRecovery(userId, phone));
    }

    /** Which questions the signed-in patient has set; never the answers. */
    @Transactional(readOnly = true)
    public SecurityQuestionsResponse status(UUID userId) {
        var questions = answers.questionsOf(userId);
        return new SecurityQuestionsResponse(!questions.isEmpty(), questions);
    }

    /** Sets or replaces all three answers. Needs the current PIN, which counts toward the PIN lockout. */
    @Transactional(noRollbackFor = {BadRequestException.class, AccountLockedException.class})
    public SecurityQuestionsResponse replaceAnswers(UUID userId, String currentPin, List<SecurityAnswerInput> input) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        List<SecurityAnswerService.PreparedAnswer> prepared = answers.prepare(input);
        authService.verifyCurrentPin(user, currentPin);
        answers.store(userId, prepared);
        return status(userId);
    }

    /**
     * Resets a forgotten PIN when all three answers are right.
     *
     * <p>Unknown phones and accounts without answers get the same 400 as wrong answers, after the
     * same BCrypt work, so this cannot be used to find out which numbers have accounts.
     *
     * <p>noRollbackFor keeps the failure counter: it is written and then the request is refused
     * by throwing, exactly as in AuthService.login.
     */
    @Transactional(noRollbackFor = {BadRequestException.class, AccountLockedException.class})
    public AuthResponse resetPin(ResetPinRequest request) {
        User user = userRepository.findByPhone(request.phone()).orElse(null);
        if (user == null) {
            answers.burnEquivalentWork();
            throw new BadRequestException(ANSWERS_DONT_MATCH);
        }

        OffsetDateTime now = OffsetDateTime.now();
        int priorFailures = user.getRecoveryFailedAttempts();
        if (user.getRecoveryLockedUntil() != null) {
            if (user.getRecoveryLockedUntil().isAfter(now)) {
                throw new AccountLockedException(AuthService.lockedMessage(user.getRecoveryLockedUntil(), now));
            }
            // The window passed: a fresh streak, or the next single mistake would re-lock at once.
            userRepository.resetRecoveryAttempts(user.getId());
            priorFailures = 0;
        }

        // After the lock check: a locked account refuses even a correct retry.
        if (authService.isReplay(user, request.changeId(), request.newPin())) {
            return authService.sessionFor(user);
        }

        if (!answers.matches(user.getId(), request.answers())) {
            OffsetDateTime lockUntil = now.plusMinutes(lockoutMinutes);
            userRepository.recordFailedRecovery(user.getId(), maxAttempts, lockUntil);
            if (priorFailures + 1 >= maxAttempts) {
                throw new AccountLockedException(AuthService.lockedMessage(lockUntil, now));
            }
            throw new BadRequestException(ANSWERS_DONT_MATCH);
        }

        user.changePinHash(passwordEncoder.encode(request.newPin()), request.changeId());
        userRepository.save(user);
        // A forgotten PIN has often just been locked by guessing; recovering clears both locks.
        userRepository.resetFailedAttempts(user.getId());
        userRepository.resetRecoveryAttempts(user.getId());
        // Anyone else holding a session (a found or stolen phone) is signed out.
        refreshTokenService.revokeAllForUser(user.getId());
        return authService.sessionFor(user);
    }
}
