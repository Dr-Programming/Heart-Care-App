package com.heartcare.sync.dto;

import java.util.List;

/** An object, not a bare array, so a pull direction could be added later without breaking clients. */
public record SyncResponse(List<SyncResult> results) {
}
