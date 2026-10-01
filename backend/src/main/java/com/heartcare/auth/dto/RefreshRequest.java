package com.heartcare.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Body of POST /auth/refresh and POST /auth/logout. */
public record RefreshRequest(
        @NotBlank(message = "refreshToken is required")
        @Size(max = 200, message = "refreshToken is too long")
        String refreshToken) {
}
