package com.heartcare.admin.research;

import com.heartcare.admin.dto.PageResponse;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.response.ApiResponse;
import com.heartcare.common.security.UserPrincipal;
import com.heartcare.research.repository.ResearchAuditRepository;
import com.heartcare.research.repository.ResearcherEventRepository;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.springframework.format.annotation.DateTimeFormat.ISO.DATE;

/** Admin control of researcher accounts, their grants, and the research access log. */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminResearcherController {

    private static final int MAX_EXPORT_ROWS = 50_000;

    private final AdminResearcherService service;
    private final ResearchAuditRepository auditLog;

    public AdminResearcherController(AdminResearcherService service, ResearchAuditRepository auditLog) {
        this.service = service;
        this.auditLog = auditLog;
    }

    @GetMapping("/researchers")
    public ApiResponse<List<ResearcherView>> list() {
        return ApiResponse.ok(service.list());
    }

    @PostMapping("/researchers")
    public ApiResponse<IssuedPassword> create(@AuthenticationPrincipal UserPrincipal admin,
                                              @Valid @RequestBody CreateResearcherRequest request) {
        return ApiResponse.ok(service.create(request, admin.userId()), "Researcher created");
    }

    /** Archived ("deleted") researchers, newest first: kept for audit, read-only. */
    @GetMapping("/researchers/archive")
    public ApiResponse<List<ResearcherView>> archive() {
        return ApiResponse.ok(service.archive());
    }

    public record ArchiveRequest(
            @jakarta.validation.constraints.NotBlank(message = "reason is required")
            @jakarta.validation.constraints.Size(min = 3, max = 500, message = "reason must be 3 to 500 characters")
            String reason) {
    }

    @PostMapping("/researchers/{id}/archive")
    public ApiResponse<ResearcherView> archiveResearcher(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id,
                                                         @Valid @RequestBody ArchiveRequest request) {
        return ApiResponse.ok(service.archive(id, request.reason(), admin.userId()), "Researcher deleted and archived");
    }

    @PostMapping("/researchers/{id}/unarchive")
    public ApiResponse<ResearcherView> unarchive(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id) {
        return ApiResponse.ok(service.unarchive(id, admin.userId()), "Researcher restored from archive");
    }

    @GetMapping("/researchers/{id}")
    public ApiResponse<ResearcherView> get(@PathVariable UUID id) {
        return ApiResponse.ok(service.get(id));
    }

    @PutMapping("/researchers/{id}/grant")
    public ApiResponse<ResearcherView> updateGrant(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id,
                                                   @Valid @RequestBody GrantRequest request) {
        return ApiResponse.ok(service.updateGrant(id, request, admin.userId()), "Access updated");
    }

    @PostMapping("/researchers/{id}/revoke")
    public ApiResponse<ResearcherView> revoke(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id) {
        return ApiResponse.ok(service.revoke(id, admin.userId()), "Access revoked");
    }

    @PostMapping("/researchers/{id}/restore")
    public ApiResponse<ResearcherView> restore(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id) {
        return ApiResponse.ok(service.restore(id, admin.userId()), "Access restored");
    }

    @PostMapping("/researchers/{id}/reset-password")
    public ApiResponse<IssuedPassword> resetPassword(@AuthenticationPrincipal UserPrincipal admin, @PathVariable UUID id) {
        return ApiResponse.ok(service.resetPassword(id, admin.userId()), "Password reset");
    }

    @GetMapping("/researchers/{id}/events")
    public ApiResponse<List<ResearcherEventRepository.Row>> events(@PathVariable UUID id) {
        return ApiResponse.ok(service.events(id));
    }

    /** The research access log, across all researchers or filtered to one. */
    @GetMapping("/research-activity")
    public ApiResponse<PageResponse<ResearchAuditRepository.Row>> activity(
            @RequestParam(required = false) UUID researcherId,
            @RequestParam(required = false) String path,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
            @RequestParam(required = false) Boolean failuresOnly,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        if (page < 0 || size < 1 || size > 200) {
            throw new BadRequestException("page must be >= 0 and size between 1 and 200");
        }
        ResearchAuditRepository.Filter f = new ResearchAuditRepository.Filter(researcherId, path, from, to, failuresOnly);
        long total = auditLog.count(f);
        return ApiResponse.ok(new PageResponse<>(auditLog.page(f, page, size), page, size, total,
                (int) Math.ceil(total / (double) size)));
    }

    @GetMapping(value = "/research-activity.csv", produces = "text/csv")
    public void activityCsv(@RequestParam(required = false) UUID researcherId,
                            @RequestParam(required = false) String path,
                            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate from,
                            @RequestParam(required = false) @DateTimeFormat(iso = DATE) LocalDate to,
                            @RequestParam(required = false) Boolean failuresOnly,
                            HttpServletResponse response) throws IOException {
        ResearchAuditRepository.Filter f = new ResearchAuditRepository.Filter(researcherId, path, from, to, failuresOnly);
        response.setContentType("text/csv; charset=utf-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"research-activity.csv\"");
        PrintWriter out = response.getWriter();
        out.println("occurred_at,researcher,username_attempted,method,path,status,rows_returned,duration_ms,ip,params");
        for (ResearchAuditRepository.Row r : auditLog.page(f, 0, MAX_EXPORT_ROWS)) {
            out.println(String.join(",", csv(r.occurredAt()), csv(r.researcherUsername()), csv(r.usernameAttempted()),
                    csv(r.method()), csv(r.path()), csv(r.status()), csv(r.rowsReturned()), csv(r.durationMs()),
                    csv(r.ip()), csv(r.paramsJson())));
        }
    }

    @GetMapping("/research-settings")
    public ApiResponse<Map<String, Integer>> settings() {
        return ApiResponse.ok(Map.of("minGroupSize", service.minGroupSize()));
    }

    @PutMapping("/research-settings")
    public ApiResponse<Map<String, Integer>> updateSettings(@AuthenticationPrincipal UserPrincipal admin,
                                                            @Valid @RequestBody ResearchSettingsRequest request) {
        return ApiResponse.ok(Map.of("minGroupSize", service.setMinGroupSize(request.minGroupSize(), admin.userId())),
                "Settings saved");
    }

    static String csv(Object value) {
        if (value == null) {
            return "";
        }
        String s = value.toString();
        // Neutralise spreadsheet formula injection, then quote.
        if (!s.isEmpty() && "=+-@".indexOf(s.charAt(0)) >= 0) {
            s = "'" + s;
        }
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }
}
