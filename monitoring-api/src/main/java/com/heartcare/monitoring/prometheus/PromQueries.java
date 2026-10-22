// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.prometheus;

import java.time.Duration;

/**
 * Every PromQL expression the System Control Centre uses, in one place. The dashboard never
 * sees PromQL; services call these and map the results to DTOs.
 */
public final class PromQueries {

    private PromQueries() {
    }

    // ---- Backend HTTP traffic (Micrometer http.server.requests, with our `client` tag) ----

    /** Actuator scrapes would otherwise count as traffic. */
    private static final String HTTP_FILTER = "job=\"spring-boot\",uri!~\"/actuator.*\"";

    private static String http(String suffix, String extra) {
        return "http_server_requests_seconds_" + suffix + "{" + HTTP_FILTER + (extra.isEmpty() ? "" : "," + extra) + "}";
    }

    public static final String BACKEND_UP = "up{job=\"spring-boot\"}";
    public static final String TOTAL_REQUESTS = "sum(" + http("count", "") + ")";
    public static final String SERVER_ERRORS_TOTAL = "sum(" + http("count", "status=~\"5..\"") + ")";
    public static final String CLIENT_ERRORS_TOTAL = "sum(" + http("count", "status=~\"4..\"") + ")";
    public static final String REQUESTS_PER_SECOND = "sum(rate(" + http("count", "") + "[1m]))";
    public static final String AVG_LATENCY_MS =
            "sum(rate(" + http("sum", "") + "[1m])) / sum(rate(" + http("count", "") + "[1m])) * 1000";
    public static final String P95_LATENCY_MS =
            "histogram_quantile(0.95, sum by (le) (rate(" + http("bucket", "") + "[5m]))) * 1000";
    public static final String ERROR_RATE_PERCENT =
            "sum(rate(" + http("count", "status=~\"5..\"") + "[5m])) / sum(rate(" + http("count", "") + "[5m])) * 100";

    public static final String REQUESTS_BY_ENDPOINT = "sum by (method, uri, client) (" + http("count", "") + ")";
    public static final String LATENCY_SUM_BY_ENDPOINT = "sum by (method, uri) (" + http("sum", "") + ")";
    public static final String ERRORS_BY_ENDPOINT = "sum by (method, uri) (" + http("count", "status=~\"5..\"") + ")";
    public static final String REQUESTS_BY_STATUS = "sum by (status) (" + http("count", "") + ")";
    public static final String REQUESTS_BY_CLIENT = "sum by (client) (" + http("count", "") + ")";
    public static final String RPS_BY_CLIENT = "sum by (client) (rate(" + http("count", "") + "[1m]))";
    public static final String SERVER_ERRORS_BY_CLIENT = "sum by (client) (" + http("count", "status=~\"5..\"") + ")";
    public static final String CLIENT_ERRORS_BY_CLIENT = "sum by (client) (" + http("count", "status=~\"4..\"") + ")";

    public static final String ACTIVE_USERS = "sum(heartcare_active_users)";
    public static final String ACTIVE_USERS_BY_CLIENT = "heartcare_active_users";

    // ---- Host (windows_exporter), with the backend JVM's view of the Docker VM as fallback ----

    public static final String HOST_UP = "up{job=\"windows\"}";
    public static final String HOST_CPU_PERCENT =
            "100 * (1 - avg(rate(windows_cpu_time_total{mode=\"idle\"}[1m])))";
    /** windows_exporter 0.25+ names first, then the older os/cs collector names. */
    public static final String HOST_MEMORY_TOTAL_BYTES =
            "max(windows_memory_physical_total_bytes) or max(windows_cs_physical_memory_bytes)";
    public static final String HOST_MEMORY_FREE_BYTES =
            "max(windows_memory_physical_free_bytes) or max(windows_os_physical_memory_free_bytes)";
    public static final String HOST_MEMORY_PERCENT =
            "100 * (1 - ((max(windows_memory_physical_free_bytes) / max(windows_memory_physical_total_bytes))"
                    + " or (max(windows_os_physical_memory_free_bytes) / max(windows_cs_physical_memory_bytes))))";
    public static final String HOST_DISK_TOTAL_BYTES = "sum(windows_logical_disk_size_bytes{volume=~\"[A-Z]:\"})";
    public static final String HOST_DISK_FREE_BYTES = "sum(windows_logical_disk_free_bytes{volume=~\"[A-Z]:\"})";
    public static final String HOST_DISK_PERCENT =
            "100 * (1 - " + HOST_DISK_FREE_BYTES + " / " + HOST_DISK_TOTAL_BYTES + ")";
    public static final String HOST_NET_RX_BPS = "sum(rate(windows_net_bytes_received_total[1m]))";
    public static final String HOST_NET_TX_BPS = "sum(rate(windows_net_bytes_sent_total[1m]))";

    /** CPU of the Docker VM as seen by the backend JVM; used when windows_exporter is absent. */
    public static final String VM_CPU_PERCENT = "max(system_cpu_usage{job=\"spring-boot\"}) * 100";

    // ---- Containers (cAdvisor) ----

    public static final String CADVISOR_UP = "up{job=\"cadvisor\"}";
    public static final String CONTAINER_CPU_PERCENT =
            "sum by (name) (rate(container_cpu_usage_seconds_total{name=~\"heartcare-.*\"}[1m])) * 100";
    public static final String CONTAINER_MEMORY_BYTES =
            "sum by (name) (container_memory_working_set_bytes{name=~\"heartcare-.*\"})";
    /** Containers cAdvisor can actually name; 0 or absent when it runs but cannot resolve them. */
    public static final String CONTAINERS_REPORTING = "count(" + CONTAINER_MEMORY_BYTES + ")";

    // ---- PostgreSQL (postgres_exporter) and the backend's Hikari pool ----

    public static final String PG_UP = "max(pg_up)";

    public static String pgConnections(String db, String state) {
        return "sum(pg_stat_activity_count{datname=\"" + db + "\",state=\"" + state + "\"})";
    }

    public static String pgTotalConnections(String db) {
        return "sum(pg_stat_activity_count{datname=\"" + db + "\"})";
    }

    public static final String PG_MAX_CONNECTIONS = "max(pg_settings_max_connections)";

    public static String pgTransactionsPerSecond(String db) {
        return "sum(rate(pg_stat_database_xact_commit{datname=\"" + db + "\"}[1m]))"
                + " + sum(rate(pg_stat_database_xact_rollback{datname=\"" + db + "\"}[1m]))";
    }

    public static String pgCacheHitPercent(String db) {
        return "100 * sum(pg_stat_database_blks_hit{datname=\"" + db + "\"})"
                + " / (sum(pg_stat_database_blks_hit{datname=\"" + db + "\"})"
                + " + sum(pg_stat_database_blks_read{datname=\"" + db + "\"}))";
    }

    public static String pgDatabaseSize(String db) {
        return "max(pg_database_size_bytes{datname=\"" + db + "\"})";
    }

    public static String pgDeadlocks(String db) {
        return "sum(pg_stat_database_deadlocks{datname=\"" + db + "\"})";
    }

    /** The application's top statements, from monitoring/postgres-exporter/queries.yaml. */
    public static final String PG_TOP_STATEMENTS_CALLS = "pg_top_statements_calls";
    public static final String PG_TOP_STATEMENTS_TIME_MS = "pg_top_statements_total_time_ms";

    public static String pgSlowQueries(String db, double thresholdMs) {
        // The exporter's own polling queries are excluded: they are the monitoring, not the app.
        String sel = "{datname=\"" + db + "\",user!=\"monitoring_user\"}";
        return "count((pg_stat_statements_seconds_total" + sel
                + " / pg_stat_statements_calls_total" + sel + ") > " + (thresholdMs / 1000.0) + ")";
    }

    public static final String POOL_ACTIVE = "sum(hikaricp_connections_active{job=\"spring-boot\"})";
    public static final String POOL_IDLE = "sum(hikaricp_connections_idle{job=\"spring-boot\"})";
    public static final String POOL_PENDING = "sum(hikaricp_connections_pending{job=\"spring-boot\"})";
    public static final String POOL_MAX = "sum(hikaricp_connections_max{job=\"spring-boot\"})";
    public static final String POOL_ACQUIRE_MS =
            "sum(rate(hikaricp_connections_acquire_seconds_sum{job=\"spring-boot\"}[1m]))"
                    + " / sum(rate(hikaricp_connections_acquire_seconds_count{job=\"spring-boot\"}[1m])) * 1000";

    // ---- Demonstration windows: the same measures, over an explicit [end - window, end] ----

    private static String w(Duration window) {
        return Math.max(15, window.toSeconds()) + "s";
    }

    public static String windowRequests(Duration window, String statusMatcher) {
        String extra = statusMatcher == null ? "" : "status=~\"" + statusMatcher + "\"";
        return "sum(increase(" + http("count", extra) + "[" + w(window) + "]))";
    }

    public static String windowAvgLatencyMs(Duration window) {
        return "sum(increase(" + http("sum", "") + "[" + w(window) + "]))"
                + " / sum(increase(" + http("count", "") + "[" + w(window) + "])) * 1000";
    }

    public static String windowP95LatencyMs(Duration window) {
        return "histogram_quantile(0.95, sum by (le) (increase(" + http("bucket", "") + "[" + w(window) + "]))) * 1000";
    }

    /** Peak of an instant expression across the window, sampled every {@code resolution}. */
    public static String windowPeak(String expression, Duration window, String resolution) {
        return "max_over_time((" + expression + ")[" + w(window) + ":" + resolution + "])";
    }

    public static final String RPS_30S = "sum(rate(" + http("count", "") + "[30s]))";
}
