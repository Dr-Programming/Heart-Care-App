package com.heartcare.admin;

import com.heartcare.admin.dto.AdminRecords;
import com.heartcare.admin.dto.AdminStatsResponse;
import com.heartcare.admin.dto.AdminUserDetail;
import com.heartcare.admin.dto.AdminUserSummary;
import com.heartcare.admin.dto.PageResponse;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.medication.model.DoseStatus;
import com.heartcare.symptoms.model.Severity;
import com.heartcare.vitals.model.VitalType;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.springframework.format.annotation.DateTimeFormat.ISO.DATE;

/**
 * Read-only admin endpoints. Access is restricted to ROLE_ADMIN in SecurityConfig; there are
 * deliberately no write mappings here.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminDataController {

    private static final Set<String> USER_SORTS = Set.of("createdAt", "fullName");
    private static final Set<String> MEASURED_SORTS = Set.of("measuredAt", "createdAt");
    private static final Set<String> DOSE_SORTS = Set.of("scheduledDate", "loggedAt");
    private static final Sort BY_MEASURED = Sort.by(Sort.Direction.DESC, "measuredAt").and(Sort.by(Sort.Direction.DESC, "id"));

    private final AdminDataService service;

    public AdminDataController(AdminDataService service) {
        this.service = service;
    }

    @GetMapping("/stats")
    public ApiResponse<AdminStatsResponse> stats() {
        return ApiResponse.ok(service.stats());
    }

    @GetMapping("/users")
    public ApiResponse<PageResponse<AdminUserSummary>> users(
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.listUsers(q, AdminPaging.of(page, size, sort, USER_SORTS,
                Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "id")))));
    }

    @GetMapping("/users/{id}")
    public ApiResponse<AdminUserDetail> user(@PathVariable UUID id) {
        return ApiResponse.ok(service.getUser(id));
    }

    @GetMapping("/users/{id}/medications")
    public ApiResponse<List<AdminRecords.Medication>> medications(@PathVariable UUID id) {
        return ApiResponse.ok(service.medications(id));
    }

    @GetMapping("/users/{id}/dose-logs")
    public ApiResponse<PageResponse<AdminRecords.Dose>> userDoseLogs(
            @PathVariable UUID id,
            @RequestParam(required = false) DoseStatus status,
            @RequestParam(required = false) UUID medicationId,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.doseLogs(id, status, medicationId, from, to,
                AdminPaging.of(page, size, sort, DOSE_SORTS, Sort.by(Sort.Direction.DESC, "scheduledDate")
                        .and(Sort.by(Sort.Direction.DESC, "loggedAt")).and(Sort.by(Sort.Direction.DESC, "id")))));
    }

    @GetMapping("/users/{id}/vitals")
    public ApiResponse<PageResponse<AdminRecords.Vital>> userVitals(
            @PathVariable UUID id,
            @RequestParam(required = false) VitalType type,
            @RequestParam(required = false) Boolean flagged,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.vitals(id, type, flagged, from, to,
                AdminPaging.of(page, size, sort, MEASURED_SORTS, BY_MEASURED)));
    }

    @GetMapping("/users/{id}/symptoms")
    public ApiResponse<PageResponse<AdminRecords.Symptom>> userSymptoms(
            @PathVariable UUID id,
            @RequestParam(required = false) Severity minSeverity,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.symptoms(id, minSeverity, from, to,
                AdminPaging.of(page, size, sort, MEASURED_SORTS, BY_MEASURED)));
    }

    @GetMapping("/users/{id}/activities")
    public ApiResponse<PageResponse<AdminRecords.Activity>> userActivities(
            @PathVariable UUID id,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.activities(id, from, to,
                AdminPaging.of(page, size, sort, MEASURED_SORTS, BY_MEASURED)));
    }

    /** Cross-patient vitals, for triage. Defaults to flagged readings only. */
    @GetMapping("/vitals")
    public ApiResponse<PageResponse<AdminRecords.Vital>> vitals(
            @RequestParam(required = false) VitalType type,
            @RequestParam(defaultValue = "true") Boolean flagged,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.vitals(null, type, flagged, from, to,
                AdminPaging.of(page, size, sort, MEASURED_SORTS, BY_MEASURED)));
    }

    /** Cross-patient symptom check-ins, for triage. Defaults to URGENT and above. */
    @GetMapping("/symptoms")
    public ApiResponse<PageResponse<AdminRecords.Symptom>> symptoms(
            @RequestParam(defaultValue = "URGENT") Severity minSeverity,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ApiResponse.ok(service.symptoms(null, minSeverity, from, to,
                AdminPaging.of(page, size, sort, MEASURED_SORTS, BY_MEASURED)));
    }
}
