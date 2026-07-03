package com.heartcare.common.security;

import java.util.UUID;

public record UserPrincipal(UUID userId, String role) {
}
