package com.heartcare.monitoring.controller;

import com.heartcare.monitoring.common.ApiResponse;
import com.heartcare.monitoring.dto.DemoSession;
import com.heartcare.monitoring.service.DemoService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;

@RestController
@RequestMapping("/api/monitoring/demo")
public class DemoController {

    private static final DateTimeFormatter FILE_STAMP =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneOffset.UTC);

    private final DemoService demo;

    public DemoController(DemoService demo) {
        this.demo = demo;
    }

    /**
     * @param conditions what the operator configured (e.g. "30 JMeter users, 10 minutes"); stored
     *                   verbatim and reported apart from the measurements
     */
    public record StartRequest(@Size(max = 80) String label, @Size(max = 500) String conditions) {
    }

    @PostMapping("/start")
    public ApiResponse<DemoSession> start(@Valid @RequestBody(required = false) StartRequest body) {
        return ApiResponse.ok(body == null ? demo.start(null, null) : demo.start(body.label(), body.conditions()));
    }

    @PostMapping("/stop")
    public ApiResponse<DemoSession> stop() {
        return ApiResponse.ok(demo.stop());
    }

    /** Data is null when no demonstration is running. */
    @GetMapping("/current")
    public ApiResponse<DemoSession> current() {
        return ApiResponse.ok(demo.current());
    }

    @GetMapping("/sessions")
    public ApiResponse<List<DemoSession>> sessions() {
        return ApiResponse.ok(demo.sessions());
    }

    /** The session as a downloadable JSON report. */
    @GetMapping("/sessions/{id}/export")
    public ResponseEntity<DemoSession> export(@PathVariable String id) {
        DemoSession session = demo.get(id);
        String filename = "scc-demonstration-" + FILE_STAMP.format(session.startedAt()) + ".json";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(filename).build().toString())
                .body(session);
    }
}
