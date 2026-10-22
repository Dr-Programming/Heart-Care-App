// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.controller;

import com.heartcare.monitoring.common.ApiResponse;
import com.heartcare.monitoring.dto.ActivityResponse;
import com.heartcare.monitoring.dto.ApiPerformanceResponse;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.dto.DatabaseResponse;
import com.heartcare.monitoring.dto.HealthResponse;
import com.heartcare.monitoring.dto.InfrastructureResponse;
import com.heartcare.monitoring.dto.NetworkResponse;
import com.heartcare.monitoring.dto.OverviewResponse;
import com.heartcare.monitoring.prometheus.PrometheusException;
import com.heartcare.monitoring.service.ActivityService;
import com.heartcare.monitoring.service.ApiMetricsService;
import com.heartcare.monitoring.service.DatabaseMetricsService;
import com.heartcare.monitoring.service.HealthService;
import com.heartcare.monitoring.service.HistoryService;
import com.heartcare.monitoring.service.InfrastructureService;
import com.heartcare.monitoring.service.NetworkService;
import com.heartcare.monitoring.service.OverviewService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** One read endpoint per dashboard section. Each returns ready-to-render numbers, never PromQL. */
@RestController
@RequestMapping("/api/monitoring")
public class MonitoringController {

    private final OverviewService overview;
    private final ApiMetricsService api;
    private final DatabaseMetricsService database;
    private final InfrastructureService infrastructure;
    private final NetworkService network;
    private final ActivityService activity;
    private final HistoryService history;
    private final HealthService health;

    public MonitoringController(OverviewService overview, ApiMetricsService api, DatabaseMetricsService database,
                                InfrastructureService infrastructure, NetworkService network,
                                ActivityService activity, HistoryService history, HealthService health) {
        this.overview = overview;
        this.api = api;
        this.database = database;
        this.infrastructure = infrastructure;
        this.network = network;
        this.activity = activity;
        this.history = history;
        this.health = health;
    }

    @GetMapping("/overview")
    public ApiResponse<OverviewResponse> overview() {
        return ApiResponse.ok(overview.overview());
    }

    @GetMapping("/api-performance")
    public ApiResponse<ApiPerformanceResponse> apiPerformance() {
        return ApiResponse.ok(api.apiPerformance());
    }

    @GetMapping("/database")
    public ApiResponse<DatabaseResponse> database() {
        return ApiResponse.ok(database.database());
    }

    @GetMapping("/infrastructure")
    public ApiResponse<InfrastructureResponse> infrastructure() {
        return ApiResponse.ok(infrastructure.infrastructure());
    }

    @GetMapping("/network")
    public ApiResponse<NetworkResponse> network() {
        return ApiResponse.ok(network.network());
    }

    @GetMapping("/activity")
    public ApiResponse<ActivityResponse> activity() {
        return ApiResponse.ok(activity.activity());
    }

    @GetMapping("/history")
    public ApiResponse<List<ChartSeries>> history(@RequestParam String metric,
                                                  @RequestParam(defaultValue = "1h") String range) {
        return ApiResponse.ok(history.history(metric, range));
    }

    @GetMapping("/health")
    public ApiResponse<HealthResponse> health() {
        return ApiResponse.ok(health.health());
    }

    /** Sections other than the overview cannot render without Prometheus; say so plainly. */
    @ExceptionHandler(PrometheusException.class)
    public ResponseEntity<ApiResponse<Void>> prometheusDown(PrometheusException ex) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(ApiResponse.error("Metrics store (Prometheus) is unavailable"));
    }
}
