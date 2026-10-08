package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.ChangePinRequest;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.PinChangeRequest;
import com.heartcare.auth.dto.RegisterRequest;
import com.heartcare.auth.dto.UserResponse;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.AccountLockedException;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ConflictException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.exception.UnauthorizedException;
import com.heartcare.common.security.JwtTokenProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;

@Service
public class AuthService {

    /**
     * One message for both "no such phone" and "wrong PIN". Anything more specific would turn
     * login into an account-enumeration oracle. The message alone is not enough — see
     * {@link #UNKNOWN_PHONE_PLACEHOLDER} for the timing half of the same problem.
     */
    static final String INVALID_CREDENTIALS = "Invalid phone or PIN";

    /**
     * Hashed at startup and verified against whenever the phone is unknown, so that branch costs
     * the same BCrypt work as a wrong PIN on a real account. It is not a PIN and can never match
     * one: PINs are exactly 4 digits.
     */
    private static final String UNKNOWN_PHONE_PLACEHOLDER = "no-such-account";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenService refreshTokenService;
    private final SecurityAnswerService securityAnswerService;
    private final int maxAttempts;
    private final int lockoutMinutes;

    /**
     * Encoded once here rather than written in as a literal, so it always carries this encoder's
     * algorithm and cost factor — a stale literal would verify at the wrong speed and reopen the
     * timing gap it exists to close.
     */
    private final String unknownPhoneHash;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider tokenProvider,
                       RefreshTokenService refreshTokenService,
                       SecurityAnswerService securityAnswerService,
                       @Value("${app.auth.lockout.max-attempts}") int maxAttempts,
                       @Value("${app.auth.lockout.duration-minutes}") int lockoutMinutes) {
        // Fail at startup, not at 3am. max-attempts below 1 makes `priorAttempts + 1 >= maxAttempts`
        // true on the very first failure, locking every account on one typo; duration-minutes below
        // 1 stamps a lock that has already expired, silently disabling the lockout entirely.
        if (maxAttempts < 1) {
            throw new IllegalArgumentException(
                    "app.auth.lockout.max-attempts must be at least 1, but was " + maxAttempts);
        }
        if (lockoutMinutes < 1) {
            throw new IllegalArgumentException(
                    "app.auth.lockout.duration-minutes must be at least 1, but was " + lockoutMinutes);
        }
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.refreshTokenService = refreshTokenService;
        this.securityAnswerService = securityAnswerService;
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
        this.unknownPhoneHash = passwordEncoder.encode(UNKNOWN_PHONE_PLACEHOLDER);
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByPhone(request.phone())) {
            throw new ConflictException("Phone already registered");
        }
        // Validated before the account exists, so a bad answer set never leaves a half-made user.
        List<SecurityAnswerService.PreparedAnswer> answers = request.securityAnswers() == null
                ? null : securityAnswerService.prepare(request.securityAnswers());
        User user = new User(
                request.phone(),
                passwordEncoder.encode(request.pin()),
                request.name(),
                request.preferredLanguage());
        try {
            userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            // Two registrations for the same phone racing past the existsByPhone check.
            throw new ConflictException("Phone already registered");
        }
        if (answers != null) {
            securityAnswerService.store(user.getId(), answers);
        }
        return authResponseFor(user);
    }

    /**
     * noRollbackFor is load-bearing, not defensive: the failure counter is written and then the
     * request is rejected by throwing. Without it Spring rolls the increment back with the
     * exception and the account never locks.
     */
    @Transactional(noRollbackFor = {UnauthorizedException.class, AccountLockedException.class})
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByPhone(request.phone()).orElse(null);
        if (user == null) {
            // Burn the same BCrypt work a real account would before failing identically. Without
            // this, an unknown phone answers after one indexed lookup while a wrong PIN answers a
            // full verify later — a gap of two to three orders of magnitude, measurable over the
            // network and enough to enumerate accounts despite the shared message above. Spring
            // Security's own DaoAuthenticationProvider.mitigateAgainstTimingAttack does exactly
            // this; the result is deliberately discarded.
            passwordEncoder.matches(request.pin(), unknownPhoneHash);
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }

        verifyPinCountingFailures(user, request.pin(), () -> new UnauthorizedException(INVALID_CREDENTIALS));
        return authResponseFor(user);
    }

    /**
     * Change PIN (TEST_REPORT Issue 5). Requires the current PIN even though the caller holds a
     * valid access token: a token lifted from an unlocked phone must not be enough to take the
     * account over. Wrong guesses feed the same lockout as login, so the endpoint cannot be used
     * to grind through the 10,000 PINs either.
     *
     * <p>A wrong current PIN is a 400, not a 401. The token is fine; a 401 would tell the app's
     * refresh interceptor the session expired and send it round a refresh-and-retry loop.
     *
     * <p>On success every refresh token is revoked and a fresh pair returned, so other devices
     * are signed out once their (short-lived, after the mobile update) access tokens expire.
     */
    @Transactional(noRollbackFor = {BadRequestException.class, AccountLockedException.class})
    public AuthResponse changePin(UUID userId, ChangePinRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        verifyCurrentPin(user, request.currentPin());
        if (request.newPin().equals(request.currentPin())) {
            throw new BadRequestException("newPin must be different from currentPin");
        }

        user.changePinHash(passwordEncoder.encode(request.newPin()));
        userRepository.save(user);
        refreshTokenService.revokeAllForUser(userId);
        return authResponseFor(user);
    }

    /**
     * PIN change that proves itself with phone + current PIN rather than a session, so the change
     * a phone made offline can be applied whenever it reconnects, even after its tokens expired or
     * were cancelled. It is effectively a login, so it follows login's rules exactly: same lockout,
     * same 401 for a wrong PIN or an unknown phone, same BCrypt work either way.
     *
     * <p>The server wins conflicts: if the PIN was changed elsewhere first, this request's old PIN
     * no longer matches and it is refused with 401.
     *
     * <p>A retry of a change that was already applied (same changeId, same new PIN) is answered
     * with a fresh session instead of a 401, without counting a failure.
     */
    @Transactional(noRollbackFor = {UnauthorizedException.class, AccountLockedException.class})
    public AuthResponse changePinWithCredentials(PinChangeRequest request) {
        User user = userRepository.findByPhone(request.phone()).orElse(null);
        if (user == null) {
            passwordEncoder.matches(request.currentPin(), unknownPhoneHash);
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        // Lock first: a replay is effectively a correct sign-in, and a locked
        // account refuses those too until the window passes.
        OffsetDateTime now = OffsetDateTime.now();
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(now)) {
            throw new AccountLockedException(lockedMessage(user.getLockedUntil(), now));
        }
        if (isReplay(user, request.changeId(), request.newPin())) {
            return authResponseFor(user);
        }
        verifyPinCountingFailures(user, request.currentPin(), () -> new UnauthorizedException(INVALID_CREDENTIALS));
        if (request.newPin().equals(request.currentPin())) {
            throw new BadRequestException("newPin must be different from currentPin");
        }

        user.changePinHash(passwordEncoder.encode(request.newPin()), request.changeId());
        userRepository.save(user);
        refreshTokenService.revokeAllForUser(user.getId());
        return authResponseFor(user);
    }

    /**
     * True when {@code changeId} is the last change applied to this account and {@code newPin} is
     * the PIN it set: a retry whose first answer was lost. Checking the new PIN too means a
     * changeId alone, without the PIN, is worth nothing.
     */
    boolean isReplay(User user, java.util.UUID changeId, String newPin) {
        return changeId != null
                && changeId.equals(user.getLastPinChangeId())
                && passwordEncoder.matches(newPin, user.getPinHash());
    }

    /**
     * Exchanges a refresh token for a new access + refresh pair (TEST_REPORT Issue 6). The
     * presented refresh token is rotated: it stops working and the response carries its successor.
     */
    @Transactional(noRollbackFor = UnauthorizedException.class)
    public AuthResponse refresh(String refreshToken) {
        RefreshTokenService.Rotated rotated = refreshTokenService.rotate(refreshToken);
        User user = userRepository.findById(rotated.userId())
                .orElseThrow(() -> new UnauthorizedException(RefreshTokenService.INVALID));
        return authResponseFor(user, rotated.next());
    }

    /** Revokes the presented refresh token's family. Always succeeds, known token or not. */
    public void logout(String refreshToken) {
        refreshTokenService.revokeFamilyOf(refreshToken);
    }

    /** Checks the signed-in patient's current PIN, for sensitive changes (PIN, security answers). */
    void verifyCurrentPin(User user, String pin) {
        verifyPinCountingFailures(user, pin, () -> new BadRequestException("Current PIN is incorrect"));
    }

    /** A fresh session (new refresh-token family), e.g. after a PIN reset. */
    AuthResponse sessionFor(User user) {
        return authResponseFor(user);
    }

    /**
     * The lockout-aware PIN check shared by login and change-pin. Throws AccountLockedException
     * while locked or on the failure that trips the lock, {@code wrongPin} on any other failure,
     * and returns normally (with the failure streak cleared) on a match.
     */
    private void verifyPinCountingFailures(User user, String pin, Supplier<RuntimeException> wrongPin) {
        OffsetDateTime now = OffsetDateTime.now();
        // Snapshot taken before the atomic UPDATE runs, so it can be stale under concurrency: if
        // several wrong-PIN requests race in, each reads the same pre-increment count and each
        // may compute "this isn't attempt 5 yet" even though the DB's atomic increments correctly
        // reach and stamp the lock. Worst case, a caller sees one extra 401 instead of a 423 on
        // the request that actually trips the lock — the lock itself is still applied correctly
        // (recordFailedAttempt is atomic), so security is unaffected; only this response's status
        // code can lag by one attempt. Do not "fix" this by re-reading after the UPDATE — that
        // reintroduces the read-modify-write race this design avoids.
        int priorAttempts = user.getFailedLoginAttempts();
        boolean counterAlreadyCleared = false;

        if (user.getLockedUntil() != null) {
            if (user.getLockedUntil().isAfter(now)) {
                throw new AccountLockedException(lockedMessage(user.getLockedUntil(), now));
            }
            // The window elapsed: this attempt starts a fresh streak, otherwise the next single
            // mistake would re-lock the account immediately.
            userRepository.resetFailedAttempts(user.getId());
            priorAttempts = 0;
            counterAlreadyCleared = true;
        }

        if (!passwordEncoder.matches(pin, user.getPinHash())) {
            OffsetDateTime lockUntil = now.plusMinutes(lockoutMinutes);
            userRepository.recordFailedAttempt(user.getId(), maxAttempts, lockUntil);
            if (priorAttempts + 1 >= maxAttempts) {
                throw new AccountLockedException(lockedMessage(lockUntil, now));
            }
            throw wrongPin.get();
        }

        if (priorAttempts > 0 && !counterAlreadyCleared) {
            userRepository.resetFailedAttempts(user.getId());
        }
    }

    static String lockedMessage(OffsetDateTime lockedUntil, OffsetDateTime now) {
        long minutes = Math.max(1,
                (long) Math.ceil(Duration.between(now, lockedUntil).toSeconds() / 60.0));
        return "Too many failed attempts. Try again in " + minutes
                + (minutes == 1 ? " minute." : " minutes.");
    }

    @Transactional(readOnly = true)
    public UserResponse getCurrentUser(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return toUserResponse(user);
    }

    /** Starts a new refresh-token family: used at sign-in and after a PIN change. */
    private AuthResponse authResponseFor(User user) {
        return authResponseFor(user, refreshTokenService.issue(user.getId()));
    }

    private AuthResponse authResponseFor(User user, RefreshTokenService.Issued refresh) {
        OffsetDateTime accessExpiresAt =
                OffsetDateTime.now().plusNanos(tokenProvider.getExpirationMs() * 1_000_000L);
        String token = tokenProvider.generateToken(user.getId(), user.getRole());
        return new AuthResponse(token, toUserResponse(user),
                refresh.token(), accessExpiresAt, refresh.expiresAt());
    }

    private UserResponse toUserResponse(User user) {
        return new UserResponse(
                user.getId().toString(),
                user.getFullName(),
                user.getPhone(),
                user.getPreferredLanguage(),
                user.getRole());
    }
}
