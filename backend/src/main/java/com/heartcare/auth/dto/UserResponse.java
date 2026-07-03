package com.heartcare.auth.dto;

public record UserResponse(String userId, String fullName, String email, String role) {
}
