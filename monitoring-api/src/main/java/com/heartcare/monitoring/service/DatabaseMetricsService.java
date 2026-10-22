// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.dto.Common.SourceStatus;
import com.heartcare.monitoring.dto.DatabaseResponse;
import com.heartcare.monitoring.dto.DatabaseResponse.QueryStat;
import com.heartcare.monitoring.prometheus.PromQueries;
import com.heartcare.monitoring.prometheus.PrometheusClient;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * PostgreSQL as Postgres sees it (postgres_exporter) next to the connection pool as the backend
 * sees it (Hikari). Many idle connections are normal; what matters is active connections against
 * the pool limit and whether requests wait for a connection.
 */
@Service
public class DatabaseMetricsService {

    static final Duration CHART_RANGE = Duration.ofMinutes(15);

    private final Metrics metrics;
    private final TtlCache cache;
    private final String db;
    private final double slowThresholdMs;

    public DatabaseMetricsService(Metrics metrics, TtlCache cache, SccProperties properties) {
        this.metrics = metrics;
        this.cache = cache;
        this.db = properties.databaseName();
        this.slowThresholdMs = properties.slowQueryThresholdMs();
    }

    public DatabaseResponse database() {
        return cache.get("database", this::compute);
    }

    private DatabaseResponse compute() {
        boolean up = metrics.isUp(PromQueries.PG_UP);

        Integer poolActive = metrics.integer(PromQueries.POOL_ACTIVE);
        Integer poolMax = metrics.integer(PromQueries.POOL_MAX);
        DatabaseResponse.Pool pool = new DatabaseResponse.Pool(
                poolActive,
                metrics.integer(PromQueries.POOL_IDLE),
                metrics.integer(PromQueries.POOL_PENDING),
                poolMax,
                Metrics.percent(poolActive, poolMax),
                metrics.value(PromQueries.POOL_ACQUIRE_MS));

        List<ChartSeries> activity = List.of(
                metrics.series("transactions/s", PromQueries.pgTransactionsPerSecond(db), CHART_RANGE),
                metrics.series("active connections", PromQueries.pgConnections(db, "active"), CHART_RANGE),
                metrics.series("pool in use", PromQueries.POOL_ACTIVE, CHART_RANGE));

        if (!up) {
            return new DatabaseResponse(SourceStatus.UNAVAILABLE, db, null, null, null, null, null, null,
                    null, null, null, slowThresholdMs, null, pool, List.of(), activity, Instant.now());
        }

        Integer slow = metrics.integer(PromQueries.pgSlowQueries(db, slowThresholdMs));
        return new DatabaseResponse(
                SourceStatus.OK,
                db,
                zeroIfAbsent(metrics.integer(PromQueries.pgConnections(db, "active"))),
                zeroIfAbsent(metrics.integer(PromQueries.pgConnections(db, "idle"))),
                zeroIfAbsent(metrics.integer(PromQueries.pgConnections(db, "idle in transaction"))),
                zeroIfAbsent(metrics.integer(PromQueries.pgTotalConnections(db))),
                metrics.integer(PromQueries.PG_MAX_CONNECTIONS),
                metrics.value(PromQueries.pgTransactionsPerSecond(db)),
                metrics.value(PromQueries.pgCacheHitPercent(db)),
                metrics.value(PromQueries.pgDatabaseSize(db)),
                slow == null ? 0 : slow,
                slowThresholdMs,
                metrics.count(PromQueries.pgDeadlocks(db)),
                pool,
                topQueries(),
                activity,
                Instant.now());
    }

    /** From the custom query in monitoring/postgres-exporter/queries.yaml: the app's top 10 by time. */
    private List<QueryStat> topQueries() {
        Map<String, Double> totalMs = new HashMap<>();
        for (PrometheusClient.Sample s : metrics.client().query(PromQueries.PG_TOP_STATEMENTS_TIME_MS)) {
            totalMs.put(s.label("queryid"), s.value());
        }
        List<QueryStat> out = new ArrayList<>();
        for (PrometheusClient.Sample s : metrics.client().query(PromQueries.PG_TOP_STATEMENTS_CALLS)) {
            String id = s.label("queryid");
            long calls = Math.round(s.value());
            double ms = totalMs.getOrDefault(id, 0.0);
            out.add(new QueryStat(id, s.label("query"), calls, ms, calls == 0 ? null : ms / calls));
        }
        out.sort(Comparator.comparingDouble(QueryStat::totalTimeMs).reversed());
        return out;
    }

    /** With the exporter up, a missing state series just means no connections in that state. */
    private static Integer zeroIfAbsent(Integer v) {
        return v == null ? 0 : v;
    }
}
