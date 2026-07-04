package com.heartcare.patient;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.patient.dto.PatientProfileRequest;
import com.heartcare.patient.dto.PatientProfileResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    @GetMapping("/me")
    public ApiResponse<PatientProfileResponse> getMyProfile(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ApiResponse.ok(patientService.getProfile(principal.userId()));
    }

    @PutMapping("/me")
    public ApiResponse<PatientProfileResponse> updateMyProfile(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody PatientProfileRequest request) {
        return ApiResponse.ok(patientService.upsertProfile(principal.userId(), request), "Profile saved");
    }
}
