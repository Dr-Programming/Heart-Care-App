package com.heartcare.research.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChangePasswordRequest(
        @NotBlank(message = "currentPassword is required")
        @Size(max = 128, message = "currentPassword must be at most 128 characters")
        String currentPassword,

        @NotBlank(message = "newPassword is required")
        @Size(min = 12, max = 128, message = "newPassword must be 12 to 128 characters")
        String newPassword) {
}
