package com.heartcare.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank String fullName,
        @NotBlank @Email String email,
        // Upper bound is not arbitrary: BCrypt silently truncates at 72 bytes, so a longer
        // passphrase would be weaker than the user believes. Reject it instead of ignoring the tail.
        @NotBlank
        @Size(min = 8, max = 72, message = "password must be between 8 and 72 characters")
        String password) {
}
