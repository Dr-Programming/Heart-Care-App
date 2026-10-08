package com.heartcare.auth;

import com.heartcare.auth.model.RefreshToken;
import com.heartcare.common.exception.UnauthorizedException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Issues, rotates and revokes patient refresh tokens (TEST_REPORT Issue 6).
 *
 * <p>A refresh token is 256 random bits, handed to the client once and stored only as a SHA-256
 * hash. A plain hash is enough here (unlike the PIN, which needs BCrypt): the input has 256 bits
 * of entropy, so there is nothing to brute-force, and a fast hash keeps the lookup indexable.
 *
 * <p>Every refresh rotates: the presented token is revoked and a successor in the same family is
 * issued. Presenting a token that was already rotated means two parties hold it, and the server
 * cannot tell which is the patient, so the whole family is revoked and both must sign in again.
 */
@Service
public class RefreshTokenService {

    static final String INVALID = "Invalid or expired refresh token";

    private static final int TOKEN_BYTES = 32;

    private final RefreshTokenRepository repository;
    private final long ttlMs;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(RefreshTokenRepository repository,
                               @Value("${app.jwt.refresh-expiration-ms}") long ttlMs) {
        if (ttlMs < 1) {
            throw new IllegalArgumentException("app.jwt.refresh-expiration-ms must be positive, but was " + ttlMs);
        }
        this.repository = repository;
        this.ttlMs = ttlMs;
    }

    public record Issued(String token, OffsetDateTime expiresAt) {
    }

    public record Rotated(UUID userId, Issued next) {
    }

    /** Starts a new token family, e.g. at sign-in. */
    @Transactional
    public Issued issue(UUID userId) {
        return issueInFamily(userId, UUID.randomUUID());
    }

    /**
     * noRollbackFor is load-bearing: on reuse the family revocation is written and then the call
     * is refused by throwing. Without it the revocation would roll back with the exception.
     *
     * @throws UnauthorizedException if the token is unknown, expired or already used
     */
    @Transactional(noRollbackFor = UnauthorizedException.class)
    public Rotated rotate(String rawToken) {
        OffsetDateTime now = OffsetDateTime.now();
        RefreshToken current = repository.findByTokenHashForUpdate(hash(rawToken))
                .orElseThrow(() -> new UnauthorizedException(INVALID));

        if (current.isRevoked()) {
            repository.revokeFamily(current.getFamilyId(), now);
            throw new UnauthorizedException(INVALID);
        }
        if (!current.getExpiresAt().isAfter(now)) {
            throw new UnauthorizedException(INVALID);
        }

        current.revoke(now);
        repository.save(current);
        return new Rotated(current.getUserId(), issueInFamily(current.getUserId(), current.getFamilyId()));
    }

    /** Sign-out: revokes the presented token's family. Unknown tokens are ignored. */
    @Transactional
    public void revokeFamilyOf(String rawToken) {
        repository.findByTokenHash(hash(rawToken))
                .ifPresent(t -> repository.revokeFamily(t.getFamilyId(), OffsetDateTime.now()));
    }

    /** Signs out every device, e.g. after a PIN change. */
    @Transactional
    public void revokeAllForUser(UUID userId) {
        repository.revokeAllForUser(userId, OffsetDateTime.now());
    }

    private Issued issueInFamily(UUID userId, UUID familyId) {
        byte[] bytes = new byte[TOKEN_BYTES];
        random.nextBytes(bytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        OffsetDateTime expiresAt = OffsetDateTime.now().plusNanos(ttlMs * 1_000_000L);
        repository.save(new RefreshToken(userId, hash(raw), familyId, expiresAt));
        return new Issued(raw, expiresAt);
    }

    static String hash(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by every Java platform", e);
        }
    }
}
