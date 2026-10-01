package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.UUID;

/**
 * Body of POST /auth/pin-change. Proves itself with phone + current PIN instead of a session, so a
 * change the phone made offline can be applied whenever it reconnects, even with expired tokens.
 */
public record PinChangeRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "currentPin must be exactly 4 digits")
        String currentPin,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "newPin must be exactly 4 digits")
        String newPin,

        // Required: it is what makes a retry after a lost response safe.
        @NotNull(message = "changeId is required")
        UUID changeId) {
}
