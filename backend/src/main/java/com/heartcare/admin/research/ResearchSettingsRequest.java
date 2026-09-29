package com.heartcare.admin.research;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record ResearchSettingsRequest(
        @Min(value = 2, message = "minGroupSize must be at least 2")
        @Max(value = 50, message = "minGroupSize must be at most 50")
        int minGroupSize) {
}
