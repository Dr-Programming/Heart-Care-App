package com.heartcare.common.security;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtTokenProviderTest {

    private static final String SECRET = "test-secret-key-that-is-at-least-32-bytes-long!!";

    private final JwtTokenProvider provider = new JwtTokenProvider(SECRET, 604800000L);

    @Test
    void generatesTokenCarryingSubjectAndRole() {
        UUID id = UUID.randomUUID();

        String token = provider.generateToken(id, "PATIENT");

        assertThat(provider.validateToken(token)).isTrue();
        assertThat(provider.getUserId(token)).isEqualTo(id.toString());
        assertThat(provider.getRole(token)).isEqualTo("PATIENT");
    }

    @Test
    void rejectsTamperedToken() {
        String token = provider.generateToken(UUID.randomUUID(), "PATIENT");

        assertThat(provider.validateToken(token + "tampered")).isFalse();
    }

    @Test
    void rejectsExpiredToken() {
        JwtTokenProvider expiredProvider = new JwtTokenProvider(SECRET, -1000L);
        String token = expiredProvider.generateToken(UUID.randomUUID(), "PATIENT");

        assertThat(expiredProvider.validateToken(token)).isFalse();
    }

    @Test
    void refusesToStartWithSecretShorterThan32Bytes() {
        assertThatThrownBy(() -> new JwtTokenProvider("too-short", 604800000L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 32 bytes");
    }

    @Test
    void refusesToStartWithNullSecret() {
        assertThatThrownBy(() -> new JwtTokenProvider(null, 604800000L))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void enforcesHs256EvenForLongSecret() {
        // 68-byte secret: without explicit HS256 this would infer HS512
        String longSecret = "abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-0123456789-XYZ";
        JwtTokenProvider longProvider = new JwtTokenProvider(longSecret, 604800000L);

        String token = longProvider.generateToken(java.util.UUID.randomUUID(), "PATIENT");

        String alg = io.jsonwebtoken.Jwts.parser()
                .verifyWith(io.jsonwebtoken.security.Keys.hmacShaKeyFor(
                        longSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8)))
                .build()
                .parseSignedClaims(token)
                .getHeader()
                .getAlgorithm();

        assertThat(alg).isEqualTo("HS256");
    }
}
