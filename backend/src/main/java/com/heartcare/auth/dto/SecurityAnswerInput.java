package com.heartcare.auth.dto;

import com.heartcare.auth.model.SecurityQuestion;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** One question and the patient's answer, as typed. An unknown questionId fails JSON parsing (400). */
public record SecurityAnswerInput(
        @NotNull(message = "questionId is required")
        SecurityQuestion questionId,

        @NotBlank(message = "answer is required")
        @Size(max = 200, message = "answer is too long")
        String answer) {
}
