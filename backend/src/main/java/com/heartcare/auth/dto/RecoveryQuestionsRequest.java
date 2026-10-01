package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** Body of POST /auth/recovery/questions. */
public record RecoveryQuestionsRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone) {
}
