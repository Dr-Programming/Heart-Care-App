package com.heartcare.auth.dto;

public record AuthResponse(String token, String userId, String role) {
}
