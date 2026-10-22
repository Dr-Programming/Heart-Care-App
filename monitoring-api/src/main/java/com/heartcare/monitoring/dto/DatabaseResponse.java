// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.dto;

import java.time.Instant;
import java.util.List;

public record DatabaseResponse(
        Common.SourceStatus source,
        String databaseName,
        Integer activeConnections,
        Integer idleConnections,
        Integer idleInTransaction,
        Integer totalConnections,
        Integer maxConnections,
        Double transactionsPerSecond,
        Double cacheHitRatioPercent,
        Double databaseSizeBytes,
        Integer slowQueries,
        double slowQueryThresholdMs,
        Long deadlocks,
        Pool pool,
        List<QueryStat> topQueries,
        List<Common.ChartSeries> activityOverTime,
        Instant generatedAt) {

    /** The backend's Hikari pool: what the application sees, as opposed to what Postgres sees. */
    public record Pool(Integer active, Integer idle, Integer pending, Integer max,
                       Double utilisationPercent, Double averageAcquireMs) {
    }

    /** Normalised statement text from pg_stat_statements ($1 placeholders, never values). */
    public record QueryStat(String queryId, String query, Long calls, Double totalTimeMs, Double meanTimeMs) {
    }
}
