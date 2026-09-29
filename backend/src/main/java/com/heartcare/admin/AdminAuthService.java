package com.heartcare.admin;

import com.heartcare.admin.dto.AdminLoginRequest;
import com.heartcare.admin.dto.AdminLoginResponse;
import com.heartcare.admin.dto.AdminMeResponse;
import com.heartcare.admin.model.AdminUser;
import com.heartcare.admin.repository.AdminUserRepository;
import com.heartcare.common.exception.AccountLockedException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.common.exception.UnauthorizedException;
import com.heartcare.common.security.JwtTokenProvider;
import com.heartcare.common.security.LoginThrottle;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

@Service
public class AdminAuthService {

    public static final String ADMIN_ROLE = "ADMIN";

    /** One message for unknown username and wrong password, so login is not an enumeration oracle. */
    static final String INVALID_CREDENTIALS = "Invalid username or password";

    private static final Logger log = LoggerFactory.getLogger(AdminAuthService.class);

    private final AdminUserRepository adminUserRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final LoginThrottle throttle;
    private final long tokenTtlMs;

    /** Verified against when the username is unknown, so both failure paths cost one BCrypt check. */
    private final String unknownUserHash;

    public AdminAuthService(AdminUserRepository adminUserRepository,
                            PasswordEncoder passwordEncoder,
                            JwtTokenProvider tokenProvider,
                            @Qualifier("adminLoginThrottle") LoginThrottle throttle,
                            @Value("${app.admin.jwt-expiration-ms}") long tokenTtlMs) {
        this.adminUserRepository = adminUserRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.throttle = throttle;
        this.tokenTtlMs = tokenTtlMs;
        this.unknownUserHash = passwordEncoder.encode("no-such-admin");
    }

    @Transactional
    public AdminLoginResponse login(AdminLoginRequest request) {
        String username = request.username().trim();
        Optional<Instant> locked = throttle.lockedUntil(username);
        if (locked.isPresent()) {
            throw new AccountLockedException(lockedMessage(locked.get()));
        }

        AdminUser admin = adminUserRepository.findByUsername(username).orElse(null);
        boolean matches = passwordEncoder.matches(request.password(),
                admin == null ? unknownUserHash : admin.getPasswordHash());
        if (admin == null || !matches) {
            log.warn("Admin login failed for username '{}'", username);
            Optional<Instant> lockedNow = throttle.recordFailure(username);
            if (lockedNow.isPresent()) {
                throw new AccountLockedException(lockedMessage(lockedNow.get()));
            }
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }

        throttle.recordSuccess(username);
        admin.setLastLoginAt(OffsetDateTime.now(ZoneOffset.UTC));
        log.info("Admin '{}' signed in", admin.getUsername());

        String token = tokenProvider.generateToken(admin.getId(), ADMIN_ROLE, tokenTtlMs);
        OffsetDateTime expiresAt = OffsetDateTime.now(ZoneOffset.UTC).plus(Duration.ofMillis(tokenTtlMs));
        return new AdminLoginResponse(token, expiresAt, toMe(admin));
    }

    @Transactional(readOnly = true)
    public AdminMeResponse me(UUID adminId) {
        return adminUserRepository.findById(adminId)
                .map(AdminAuthService::toMe)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found"));
    }

    private static AdminMeResponse toMe(AdminUser admin) {
        return new AdminMeResponse(admin.getId().toString(), admin.getUsername(), admin.getLastLoginAt());
    }

    private static String lockedMessage(Instant until) {
        long minutes = Math.max(1, (long) Math.ceil(Duration.between(Instant.now(), until).toSeconds() / 60.0));
        return "Too many failed attempts. Try again in " + minutes + (minutes == 1 ? " minute." : " minutes.");
    }
}
