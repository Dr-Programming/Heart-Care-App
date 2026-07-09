package com.heartcare.medication;

import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.medication.dto.MedicationRequest;
import com.heartcare.medication.dto.MedicationResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/medications")
public class MedicationController {

    private final MedicationService medicationService;

    public MedicationController(MedicationService medicationService) {
        this.medicationService = medicationService;
    }

    @PostMapping
    public ApiResponse<MedicationResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody MedicationRequest request) {
        return ApiResponse.ok(medicationService.create(principal.userId(), request), "Medication created");
    }

    @GetMapping
    public ApiResponse<List<MedicationResponse>> list(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return ApiResponse.ok(medicationService.list(principal.userId(), includeInactive));
    }

    @PutMapping("/{id}")
    public ApiResponse<MedicationResponse> update(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id,
            @Valid @RequestBody MedicationRequest request) {
        return ApiResponse.ok(medicationService.update(principal.userId(), id, request), "Medication updated");
    }

    @DeleteMapping("/{id}")
    public ApiResponse<MedicationResponse> deactivate(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id) {
        return ApiResponse.ok(medicationService.deactivate(principal.userId(), id), "Medication deactivated");
    }
}
