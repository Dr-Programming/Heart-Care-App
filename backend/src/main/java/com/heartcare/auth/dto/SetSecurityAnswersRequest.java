package com.heartcare.auth.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.List;

/** Body of PUT /auth/security-answers. The current PIN is required to replace the answers. */
public record SetSecurityAnswersRequest(
        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "currentPin must be exactly 4 digits")
        String currentPin,

        @NotNull(message = "answers is required")
        List<@Valid SecurityAnswerInput> answers) {
}
