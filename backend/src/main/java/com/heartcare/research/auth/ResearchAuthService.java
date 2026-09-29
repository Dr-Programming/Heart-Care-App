package com.heartcare.research.auth;

import com.heartcare.common.exception.AccountLockedException;
import com.heartcare.common.exception.ForbiddenException;
import com.heartcare.common.exception.UnauthorizedException;
import com.heartcare.common.security.JwtTokenProvider;
import com.heartcare.common.security.LoginThrottle;
import com.heartcare.research.audit.ResearchAudit;
import com.heartcare.research.dto.ChangePasswordRequest;
import com.heartcare.research.dto.GrantView;
import com.heartcare.research.dto.ResearchLoginRequest;
import com.heartcare.research.dto.ResearchLoginResponse;
import com.heartcare.research.dto.ResearcherMe;
import com.heartcare.research.model.Researcher;
import com.heartcare.research.model.ResearcherGrant;
import com.heartcare.research.model.ResearcherStatus;
import com.heartcare.research.repository.ResearchSettingsRepository;
import com.heartcare.research.repository.ResearcherGrantRepository;
import com.heartcare.research.repository.ResearcherRepository;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;

@Service
public class ResearchAuthService {

    public static final String RESEARCHER_ROLE = "RESEARCHER";
    /** JWT claim carrying {@link Researcher#getTokenVersion()}; a mismatch means the session was ended. */
    public static final String VERSION_CLAIM = "ver";

    static final String INVALID_CREDENTIALS = "Invalid username or password";
    static final String CONTACT_ADMIN =
            "You've already used your one password change. Ask your administrator to reset your password.";

    private final ResearcherRepository researchers;
    private final ResearcherGrantRepository grants;
    private final ResearchSettingsRepository settings;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final LoginThrottle throttle;
    private final long tokenTtlMs;
    private final String unknownUserHash;

    public ResearchAuthService(ResearcherRepository researchers,
                               ResearcherGrantRepository grants,
                               ResearchSettingsRepository settings,
                               PasswordEncoder passwordEncoder,
                               JwtTokenProvider tokenProvider,
                               @Qualifier("researchLoginThrottle") LoginThrottle throttle,
                               @Value("${app.research.jwt-expiration-ms}") long tokenTtlMs) {
        this.researchers = researchers;
        this.grants = grants;
        this.settings = settings;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.throttle = throttle;
        this.tokenTtlMs = tokenTtlMs;
        this.unknownUserHash = passwordEncoder.encode("no-such-researcher");
    }

    @Transactional(noRollbackFor = {UnauthorizedException.class, AccountLockedException.class, ForbiddenException.class})
    public ResearchLoginResponse login(ResearchLoginRequest request) {
        String username = request.username().trim();
        ResearchAudit.usernameAttempted(username);

        Optional<Instant> locked = throttle.lockedUntil(username);
        if (locked.isPresent()) {
            throw new AccountLockedException(lockedMessage(locked.get()));
        }

        Researcher researcher = researchers.findByUsername(username).orElse(null);
        boolean matches = passwordEncoder.matches(request.password(),
                researcher == null ? unknownUserHash : researcher.getPasswordHash());
        if (researcher == null || !matches) {
            if (researcher != null) {
                ResearchAudit.researcher(researcher.getId());
            }
            Optional<Instant> lockedNow = throttle.recordFailure(username);
            if (lockedNow.isPresent()) {
                throw new AccountLockedException(lockedMessage(lockedNow.get()));
            }
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        throttle.recordSuccess(username);
        ResearchAudit.researcher(researcher.getId());

        // Checked only after the password, so these messages never reveal whether an account exists.
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        ResearcherGrant grant = requireGrant(researcher);
        if (researcher.getStatus() != ResearcherStatus.ACTIVE) {
            throw new ForbiddenException("ACCESS_REVOKED", researcher.isArchived()
                    ? "Your research access has been removed. Contact your administrator."
                    : "Your research access has been revoked. Contact your administrator.");
        }
        if (grant.isExpired(now)) {
            throw new ForbiddenException("ACCESS_EXPIRED",
                    "Your research access expired. Contact your administrator to extend it.");
        }

        researcher.setLastLoginAt(now);
        String token = tokenProvider.generateToken(researcher.getId(), RESEARCHER_ROLE, tokenTtlMs,
                Map.of(VERSION_CLAIM, researcher.getTokenVersion()));
        OffsetDateTime expiresAt = now.plus(Duration.ofMillis(tokenTtlMs));
        if (grant.getExpiresAt() != null && grant.getExpiresAt().isBefore(expiresAt)) {
            expiresAt = grant.getExpiresAt();
        }
        return new ResearchLoginResponse(token, expiresAt, me(researcher, grant));
    }

    @Transactional(readOnly = true)
    public ResearcherMe me(ResearchContext ctx) {
        return new ResearcherMe(
                ctx.researcher().getId().toString(), ctx.researcher().getUsername(), ctx.researcher().getFullName(),
                ctx.researcher().getOrganisation(), ctx.researcher().isMustChangePassword(),
                ctx.researcher().canSelfChangePassword(), ctx.researcher().getPasswordChangedAt(),
                ctx.researcher().getLastLoginAt(), GrantView.of(ctx.grant()), ctx.minGroupSize());
    }

    /**
     * The researcher's single self-service change. The first sign-in forces it, so in practice
     * every admin-issued password is replaced exactly once and any later change goes via an admin.
     */
    @Transactional
    public ResearcherMe changePassword(ResearchContext ctx, ChangePasswordRequest request) {
        Researcher researcher = researchers.findById(ctx.researcher().getId())
                .orElseThrow(() -> new UnauthorizedException("Session ended"));
        if (!researcher.canSelfChangePassword()) {
            throw new ForbiddenException("PASSWORD_CHANGE_USED", CONTACT_ADMIN);
        }
        if (!passwordEncoder.matches(request.currentPassword(), researcher.getPasswordHash())) {
            throw new UnauthorizedException("Current password is incorrect");
        }
        if (request.newPassword().equals(request.currentPassword())) {
            throw new com.heartcare.common.exception.BadRequestException(
                    "Choose a new password that is different from the one your administrator gave you");
        }
        researcher.selfChangePassword(passwordEncoder.encode(request.newPassword()), OffsetDateTime.now(ZoneOffset.UTC));
        return me(researcher, ctx.grant());
    }

    private ResearcherMe me(Researcher r, ResearcherGrant grant) {
        return me(new ResearchContext(r, grant, settings.minGroupSize()));
    }

    private ResearcherGrant requireGrant(Researcher researcher) {
        return grants.findById(researcher.getId())
                .orElseThrow(() -> new ForbiddenException("ACCESS_REVOKED", "No research access has been granted."));
    }

    private static String lockedMessage(Instant until) {
        long minutes = Math.max(1, (long) Math.ceil(Duration.between(Instant.now(), until).toSeconds() / 60.0));
        return "Too many failed attempts. Try again in " + minutes + (minutes == 1 ? " minute." : " minutes.");
    }
}
