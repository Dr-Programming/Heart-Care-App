package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Registration is identity only — phone, PIN, name, language. Medical onboarding is a
 * separate slice (patient profile), so nothing clinical is accepted here.
 */
public record RegisterRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        // A 4-digit PIN is 10,000 combinations, which is only defensible because login is
        // rate-limited by the account lockout. See AuthService.
        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "pin must be exactly 4 digits")
        String pin,

        @NotBlank
        @Size(max = 255, message = "name must be at most 255 characters")
        String name,

        @NotBlank
        @Pattern(regexp = "^(en|am)$", message = "preferredLanguage must be en or am")
        String preferredLanguage) {
}
