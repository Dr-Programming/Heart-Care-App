package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record LoginRequest(
        @NotBlank
        @Pattern(regexp = "^\\+251\\d{9}$", message = "phone must be in +251XXXXXXXXX format")
        String phone,

        @NotBlank
        @Pattern(regexp = "^\\d{4}$", message = "pin must be exactly 4 digits")
        String pin) {
}
