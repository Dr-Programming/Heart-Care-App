// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.auth;

import com.heartcare.monitoring.config.SccProperties;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;

/** Issues and checks SCC session tokens. Unrelated to the main backend's tokens or secret. */
@Component
public class SccTokenService {

    static final String ROLE = "SCC_ADMIN";
    private static final int MIN_SECRET_BYTES = 32;

    private final SecretKey key;
    private final long expirationMs;

    public SccTokenService(SccProperties properties) {
        String secret = properties.jwt().secret();
        // Refuse to start rather than sign sessions with an empty or guessable key.
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("SCC_JWT_SECRET must be at least " + MIN_SECRET_BYTES
                    + " bytes; generate one with: openssl rand -base64 48");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = properties.jwt().expirationMs();
    }

    public record IssuedToken(String token, Instant expiresAt) {
    }

    public IssuedToken issue(String username) {
        Instant now = Instant.now();
        Instant expiresAt = now.plusMillis(expirationMs);
        String token = Jwts.builder()
                .subject(username)
                .claim("role", ROLE)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiresAt))
                .signWith(key, Jwts.SIG.HS256)
                .compact();
        return new IssuedToken(token, expiresAt);
    }

    /** The username, when the token is valid and carries the SCC role. */
    public Optional<String> verify(String token) {
        try {
            var claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            if (!ROLE.equals(claims.get("role", String.class)) || claims.getSubject() == null) {
                return Optional.empty();
            }
            return Optional.of(claims.getSubject());
        } catch (JwtException | IllegalArgumentException ex) {
            return Optional.empty();
        }
    }
}
