// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.security;

import java.util.UUID;

public record UserPrincipal(UUID userId, String role) {
}
