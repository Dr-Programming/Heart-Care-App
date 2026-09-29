package com.heartcare.admin.dto;

import java.time.OffsetDateTime;

public record AdminMeResponse(String id, String username, OffsetDateTime lastLoginAt) {
}
