package com.heartcare.auth.dto;

/**
 * Register and login both return the token plus the full user, so the client can seed its
 * offline cache in one round trip instead of following up with GET /auth/me.
 */
public record AuthResponse(String token, UserResponse user) {
}
