package com.heartcare.admin.dto;

import java.time.OffsetDateTime;

public record AdminLoginResponse(String token, OffsetDateTime expiresAt, AdminMeResponse admin) {
}
