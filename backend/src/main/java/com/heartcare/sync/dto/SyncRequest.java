package com.heartcare.sync.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record SyncRequest(
        @NotEmpty(message = "records is required and must not be empty")
        List<@Valid SyncRecord> records) {
}
