package com.heartcare.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.heartcare.auth.model.SecurityQuestion;

import java.util.List;

/**
 * The questions set for an account. {@code configured} is only filled in for the signed-in
 * patient's own account (GET /auth/security-answers); the public recovery endpoint leaves it null
 * so its response looks the same whether or not the phone has an account.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record SecurityQuestionsResponse(Boolean configured, List<SecurityQuestion> questions) {
}
