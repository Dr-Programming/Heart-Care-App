package com.heartcare.research.dto;

import java.time.OffsetDateTime;

public record ResearchLoginResponse(String token, OffsetDateTime expiresAt, ResearcherMe researcher) {
}
