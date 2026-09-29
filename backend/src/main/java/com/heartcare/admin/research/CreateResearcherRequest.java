package com.heartcare.admin.research;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateResearcherRequest(
        @NotBlank(message = "username is required")
        @Pattern(regexp = "^[a-z0-9][a-z0-9._-]{2,63}$",
                message = "username must be 3-64 characters: lowercase letters, digits, dot, dash or underscore")
        String username,

        @NotBlank(message = "fullName is required")
        @Size(max = 255, message = "fullName must be at most 255 characters")
        String fullName,

        @Size(max = 255, message = "organisation must be at most 255 characters")
        String organisation,

        @NotNull(message = "grant is required")
        @Valid
        GrantRequest grant) {
}
