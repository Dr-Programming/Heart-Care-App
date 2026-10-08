package com.heartcare.auth.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.List;
import java.util.UUID;

/** Body of POST /auth/reset-pin (forgot PIN). */
public record ResetPinRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        @NotNull(message = "answers is required")
        List<@Valid SecurityAnswerInput> answers,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "newPin must be exactly 4 digits")
        String newPin,

        // Optional: makes a retry after a lost response safe (see V16__pin_change_id.sql).
        UUID changeId) {
}
