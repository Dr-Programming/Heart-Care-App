// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.research.dto;

import java.time.OffsetDateTime;

public record ResearchLoginResponse(String token, OffsetDateTime expiresAt, ResearcherMe researcher) {
}
