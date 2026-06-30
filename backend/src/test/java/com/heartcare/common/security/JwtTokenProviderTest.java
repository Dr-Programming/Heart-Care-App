package com.heartcare.common.security;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

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
}
