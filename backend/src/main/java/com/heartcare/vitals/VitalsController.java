package com.heartcare.vitals;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.vitals.dto.VitalLogRequest;
import com.heartcare.vitals.dto.VitalLogResponse;
import com.heartcare.vitals.model.VitalType;
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
public class VitalsController {

    private final VitalsService vitalsService;

    public VitalsController(VitalsService vitalsService) {
        this.vitalsService = vitalsService;
    }

    @PostMapping("/vitals")
    public ApiResponse<VitalLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody VitalLogRequest request) {
        return ApiResponse.ok(vitalsService.log(principal.userId(), request), "Vital logged");
    }

    @GetMapping("/vitals")
    public ApiResponse<List<VitalLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) VitalType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(vitalsService.history(principal.userId(), type, from, to));
    }
}
