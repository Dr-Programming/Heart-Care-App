package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** Body of POST /auth/change-pin. Same 4-digit rule as RegisterRequest. */
public record ChangePinRequest(
        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "currentPin must be exactly 4 digits")
        String currentPin,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "newPin must be exactly 4 digits")
        String newPin) {
}
