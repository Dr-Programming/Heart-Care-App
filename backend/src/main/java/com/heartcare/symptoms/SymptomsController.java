package com.heartcare.symptoms;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.symptoms.dto.SymptomLogRequest;
import com.heartcare.symptoms.dto.SymptomLogResponse;
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
public class SymptomsController {

    private final SymptomsService symptomsService;

    public SymptomsController(SymptomsService symptomsService) {
        this.symptomsService = symptomsService;
    }

    @PostMapping("/symptoms")
    public ApiResponse<SymptomLogResponse> log(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody SymptomLogRequest request) {
        return ApiResponse.ok(symptomsService.log(principal.userId(), request), "Symptom check-in logged");
    }

    @GetMapping("/symptoms")
    public ApiResponse<List<SymptomLogResponse>> history(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(symptomsService.history(principal.userId(), from, to));
    }
}
