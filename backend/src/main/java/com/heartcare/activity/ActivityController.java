package com.heartcare.activity;

import com.heartcare.activity.dto.ActivityLogRequest;
import com.heartcare.activity.dto.ActivityLogResponse;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class ActivityController {

    private final ActivityService activityService;

    public ActivityController(ActivityService activityService) {
        this.activityService = activityService;
    }

    @PostMapping("/activities")
    public ApiResponse<ActivityLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody ActivityLogRequest request) {
        return ApiResponse.ok(activityService.log(principal.userId(), request), "Activity logged");
    }

    @GetMapping("/activities")
    public ApiResponse<List<ActivityLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(activityService.history(principal.userId(), from, to));
    }
}
