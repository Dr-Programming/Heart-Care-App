package com.heartcare.sync;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.sync.dto.SyncRequest;
import com.heartcare.sync.dto.SyncResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class SyncController {

    private final SyncService syncService;

    public SyncController(SyncService syncService) {
        this.syncService = syncService;
    }

    @PostMapping("/sync")
    public ApiResponse<SyncResponse> sync(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody SyncRequest request) {
        return ApiResponse.ok(syncService.sync(principal.userId(), request), "Sync processed");
    }
}
