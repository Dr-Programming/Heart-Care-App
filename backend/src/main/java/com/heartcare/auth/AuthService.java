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
     * login into an account-enumeration oracle.
     */
    static final String INVALID_CREDENTIALS = "Invalid phone or PIN";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final int maxAttempts;
    private final int lockoutMinutes;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider tokenProvider,
                       @Value("${app.auth.lockout.max-attempts}") int maxAttempts,
                       @Value("${app.auth.lockout.duration-minutes}") int lockoutMinutes) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.maxAttempts = maxAttempts;
        this.lockoutMinutes = lockoutMinutes;
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
        User user = userRepository.findByPhone(request.phone())
                .orElseThrow(() -> new UnauthorizedException(INVALID_CREDENTIALS));

        OffsetDateTime now = OffsetDateTime.now();
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
