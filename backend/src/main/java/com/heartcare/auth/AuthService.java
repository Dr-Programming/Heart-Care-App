package com.heartcare.auth;

import com.heartcare.auth.dto.AuthResponse;
import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import com.heartcare.auth.dto.UserResponse;
import com.heartcare.auth.model.User;
import com.heartcare.common.exception.AccountLockedException;
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
import java.util.UUID;

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
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
        this.unknownPhoneHash = passwordEncoder.encode(UNKNOWN_PHONE_PLACEHOLDER);
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByPhone(request.phone())) {
            throw new ConflictException("Phone already registered");
        }
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

        if (!passwordEncoder.matches(request.pin(), user.getPinHash())) {
            OffsetDateTime lockUntil = now.plusMinutes(lockoutMinutes);
            userRepository.recordFailedAttempt(user.getId(), maxAttempts, lockUntil);
            if (priorAttempts + 1 >= maxAttempts) {
                throw new AccountLockedException(lockedMessage(lockUntil, now));
            }
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }

        if (priorAttempts > 0 && !counterAlreadyCleared) {
            userRepository.resetFailedAttempts(user.getId());
        }
        return authResponseFor(user);
    }

    private String lockedMessage(OffsetDateTime lockedUntil, OffsetDateTime now) {
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

    private AuthResponse authResponseFor(User user) {
        String token = tokenProvider.generateToken(user.getId(), user.getRole());
        return new AuthResponse(token, toUserResponse(user));
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
