package com.heartcare.auth.dto;

import java.time.OffsetDateTime;

/**
 * Register, login, refresh and change-pin all return the token pair plus the full user, so the
 * client can seed its offline cache in one round trip instead of following up with GET /auth/me.
 *
 * <p>{@code token} keeps its original name (it is the access token) so app builds that predate
 * refresh tokens keep working; they simply ignore the new fields.
 */
public record AuthResponse(
        String token,
        UserResponse user,
        String refreshToken,
        OffsetDateTime accessTokenExpiresAt,
        OffsetDateTime refreshTokenExpiresAt) {
}
