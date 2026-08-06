package com.heartcare.auth.dto;

/** The user as the mobile app caches it. Never carries the PIN hash. */
public record UserResponse(
        String id,
        String name,
        String phone,
        String preferredLanguage,
        String role) {
}
