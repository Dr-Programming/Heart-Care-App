package com.heartcare.medication;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.medication.dto.DoseLogRequest;
import com.heartcare.medication.dto.DoseLogResponse;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class DoseLogController {

    private final DoseLogService doseLogService;

    public DoseLogController(DoseLogService doseLogService) {
        this.doseLogService = doseLogService;
    }

    @PostMapping("/medications/{medicationId}/doses")
    public ApiResponse<DoseLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID medicationId,
            @Valid @RequestBody DoseLogRequest request) {
        return ApiResponse.ok(doseLogService.log(principal.userId(), medicationId, request), "Dose logged");
    }

    @GetMapping("/dose-logs")
    public ApiResponse<List<DoseLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) UUID medicationId) {
        return ApiResponse.ok(doseLogService.history(principal.userId(), from, to, medicationId));
    }
}
