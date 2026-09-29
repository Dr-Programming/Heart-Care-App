package com.heartcare.research.analytics;

import com.heartcare.research.analytics.AnalyticsModels.AdherenceBand;
import com.heartcare.research.analytics.AnalyticsModels.AdherenceRequest;
import com.heartcare.research.analytics.AnalyticsModels.AdherenceResult;
import com.heartcare.research.analytics.AnalyticsModels.Bin;
import com.heartcare.research.analytics.AnalyticsModels.CohortPreview;
import com.heartcare.research.analytics.AnalyticsModels.CorrelationRequest;
import com.heartcare.research.analytics.AnalyticsModels.CorrelationResult;
import com.heartcare.research.analytics.AnalyticsModels.DescribeRequest;
import com.heartcare.research.analytics.AnalyticsModels.DescribeResult;
import com.heartcare.research.analytics.AnalyticsModels.Grid;
import com.heartcare.research.analytics.AnalyticsModels.GroupBy;
import com.heartcare.research.analytics.AnalyticsModels.GroupStats;
import com.heartcare.research.analytics.AnalyticsModels.MetricView;
import com.heartcare.research.analytics.AnalyticsModels.NamedCohort;
import com.heartcare.research.analytics.AnalyticsModels.Period;
import com.heartcare.research.analytics.AnalyticsModels.ScatterPoint;
import com.heartcare.research.analytics.AnalyticsModels.SeverityBucket;
import com.heartcare.research.analytics.AnalyticsModels.SeverityRequest;
import com.heartcare.research.analytics.AnalyticsModels.SeverityResult;
import com.heartcare.research.analytics.AnalyticsModels.Stats;
import com.heartcare.research.analytics.AnalyticsModels.TrendPoint;
import com.heartcare.research.analytics.AnalyticsModels.TrendRequest;
import com.heartcare.research.analytics.AnalyticsModels.TrendResult;
import com.heartcare.research.analytics.AnalyticsModels.TrendSeries;
import com.heartcare.research.analytics.AnalyticsModels.Unit;
import com.heartcare.research.analytics.AnalyticsModels.WindowView;
import com.heartcare.research.analytics.MetricCatalog.Metric;
import com.heartcare.research.anon.Pseudonymizer;
import com.heartcare.research.anon.ResearchScope;
import com.heartcare.research.anon.ResearchScope.Window;
import com.heartcare.research.model.AccessLevel;
import com.heartcare.research.model.Dataset;
import com.heartcare.symptoms.model.Severity;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * The research tools. All computation happens in Postgres; Java only assembles parameters and
 * applies suppression to what comes back. Identifiers never leave this class except as
 * researcher-specific pseudonyms, and only at PSEUDONYMOUS level.
 */
@Service
@Transactional(readOnly = true)
public class AnalyticsService {

    private static final int GRID = 5;

    private final NamedParameterJdbcTemplate jdbc;
    private final Pseudonymizer pseudonymizer;

    public AnalyticsService(NamedParameterJdbcTemplate jdbc, Pseudonymizer pseudonymizer) {
        this.jdbc = jdbc;
        this.pseudonymizer = pseudonymizer;
    }

    // ---- cohort ----------------------------------------------------------------------------

    public CohortPreview previewCohort(ResearchScope scope, CohortDefinition def, LocalDate from, LocalDate to) {
        Window w = scope.window(from, to);
        MapSqlParameterSource p = windowParams(w);
        String sql = "WITH " + CohortSql.cte(def, scope, p) + " SELECT COUNT(*) FROM cohort";
        long size = count(sql, p);
        boolean hidden = size > 0 && size < scope.k();
        return new CohortPreview(hidden ? null : size, hidden, scope.k());
    }

    long cohortSize(ResearchScope scope, CohortDefinition def, Window w) {
        MapSqlParameterSource p = windowParams(w);
        return count("WITH " + CohortSql.cte(def, scope, p) + " SELECT COUNT(*) FROM cohort", p);
    }

    // ---- describe --------------------------------------------------------------------------

    public DescribeResult describe(ResearchScope scope, DescribeRequest req) {
        Metric m = MetricCatalog.get(req.metric());
        scope.require(m.dataset());
        GroupBy groupBy = req.groupBy() == null ? GroupBy.NONE : req.groupBy();
        if (groupBy != GroupBy.NONE) {
            scope.require(Dataset.DEMOGRAPHICS);
        }
        Unit unit = req.unit() == null ? Unit.READING : req.unit();
        int bins = req.bins() == null ? 12 : req.bins();
        Window w = scope.window(req.from(), req.to());
        MapSqlParameterSource p = windowParams(w);

        String base = "WITH " + CohortSql.cte(req.cohort(), scope, p) + ",\n" + valuesCte(m, groupSql(groupBy))
                + (unit == Unit.PATIENT
                ? ",\nsrc AS (SELECT user_id, grp, AVG(value) AS value FROM vals GROUP BY user_id, grp)"
                : ",\nsrc AS (SELECT user_id, grp, value FROM vals)");

        Stats overall = stats(jdbc.queryForObject(base + "\n" + statsSelect("") , p, (rs, i) -> readStats(rs, scope.k())));

        List<Bin> histogram = List.of();
        if (!overall.suppressed() && overall.p5() != null) {
            histogram = histogram(base, p, overall.p5(), overall.p95(), bins, scope.k());
        }

        List<GroupStats> groups = List.of();
        if (groupBy != GroupBy.NONE) {
            groups = jdbc.query(base + "\n" + statsSelect("grp") , p,
                    (rs, i) -> new GroupStats(rs.getString("grp") == null ? "Not recorded" : rs.getString("grp"),
                            readStats(rs, scope.k())));
        }
        return new DescribeResult(MetricView.of(m), unit, windowView(w), overall, histogram, groupBy, groups, scope.k());
    }

    private static String statsSelect(String groupCol) {
        String select = """
                SELECT %s COUNT(*) AS n, COUNT(DISTINCT user_id) AS patients,
                       AVG(value)::float8 AS mean, STDDEV_SAMP(value)::float8 AS sd,
                       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY value) AS p5,
                       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY value) AS p25,
                       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY value) AS p50,
                       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY value) AS p75,
                       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) AS p95
                  FROM src""".formatted(groupCol.isEmpty() ? "" : groupCol + ",");
        return groupCol.isEmpty() ? select : select + " GROUP BY " + groupCol + " ORDER BY " + groupCol;
    }

    private static Stats stats(Stats s) {
        return s == null ? Stats.empty() : s;
    }

    private static Stats readStats(ResultSet rs, int k) throws SQLException {
        long n = rs.getLong("n");
        long patients = rs.getLong("patients");
        if (patients == 0) {
            return Stats.empty();
        }
        if (patients < k) {
            return Stats.hidden();
        }
        return new Stats(false, n, patients, round(rs, "mean"), round(rs, "sd"), round(rs, "p5"), round(rs, "p25"),
                round(rs, "p50"), round(rs, "p75"), round(rs, "p95"));
    }

    private List<Bin> histogram(String base, MapSqlParameterSource p, double lo, double hi, int bins, int k) {
        if (hi <= lo) {
            // Every value is the same (to within p5-p95): one bin.
            MapSqlParameterSource q = copy(p);
            List<Bin> single = jdbc.query(base + "\nSELECT COUNT(*) AS n, COUNT(DISTINCT user_id) AS patients FROM src", q,
                    (rs, i) -> bin(lo, hi, rs.getLong("n"), rs.getLong("patients"), k));
            return single;
        }
        MapSqlParameterSource q = copy(p).addValue("lo", lo).addValue("hi", hi).addValue("bins", bins);
        Map<Integer, Bin> byIndex = new java.util.HashMap<>();
        double width = (hi - lo) / bins;
        jdbc.query(base + """

                SELECT LEAST(GREATEST(WIDTH_BUCKET(value::float8, CAST(:lo AS float8), CAST(:hi AS float8), CAST(:bins AS int)), 1), CAST(:bins AS int)) AS b,
                       COUNT(*) AS n, COUNT(DISTINCT user_id) AS patients
                  FROM src GROUP BY b""", q, rs -> {
            int b = rs.getInt("b");
            byIndex.put(b, bin(lo + (b - 1) * width, lo + b * width, rs.getLong("n"), rs.getLong("patients"), k));
        });
        List<Bin> out = new ArrayList<>();
        for (int b = 1; b <= bins; b++) {
            out.add(byIndex.getOrDefault(b, new Bin(round(lo + (b - 1) * width), round(lo + b * width), 0L, false)));
        }
        return out;
    }

    private static Bin bin(double lo, double hi, long n, long patients, int k) {
        boolean hidden = patients > 0 && patients < k;
        return new Bin(round(lo), round(hi), hidden ? null : n, hidden);
    }

    // ---- trend -----------------------------------------------------------------------------

    public TrendResult trend(ResearchScope scope, TrendRequest req) {
        Metric m = MetricCatalog.get(req.metric());
        scope.require(m.dataset());
        Window w = scope.window(req.from(), req.to());
        List<NamedCohort> cohorts = req.cohorts() == null || req.cohorts().isEmpty()
                ? List.of(new NamedCohort("All patients", CohortDefinition.ALL))
                : req.cohorts();

        List<TrendSeries> series = new ArrayList<>();
        for (int i = 0; i < cohorts.size(); i++) {
            NamedCohort c = cohorts.get(i);
            MapSqlParameterSource p = windowParams(w).addValue("period", periodSql(req.period()));
            String sql = "WITH " + CohortSql.cte(c.definition(), scope, p) + ",\n" + valuesCte(m, "NULL") + """

                    SELECT CAST(DATE_TRUNC(CAST(:period AS text), ts) AS date) AS bucket,
                           AVG(value)::float8 AS mean, COUNT(*) AS n, COUNT(DISTINCT user_id) AS patients
                      FROM vals GROUP BY bucket ORDER BY bucket""";
            List<TrendPoint> points = jdbc.query(sql, p, (rs, idx) -> {
                long patients = rs.getLong("patients");
                boolean hidden = patients < scope.k();
                return new TrendPoint(rs.getObject("bucket", LocalDate.class), hidden,
                        hidden ? null : round(rs, "mean"), hidden ? null : rs.getLong("n"), hidden ? null : patients);
            });
            String label = c.label() == null || c.label().isBlank() ? "Cohort " + (i + 1) : c.label();
            series.add(new TrendSeries(label, points));
        }
        return new TrendResult(MetricView.of(m), req.period(), windowView(w), series, scope.k());
    }

    // ---- adherence vs outcomes -------------------------------------------------------------

    public AdherenceResult adherenceOutcomes(ResearchScope scope, AdherenceRequest req) {
        scope.require(Dataset.MEDICATIONS);
        scope.require(Dataset.VITALS);
        boolean withSymptoms = scope.has(Dataset.SYMPTOMS);
        Window w = scope.window(req.from(), req.to());
        MapSqlParameterSource p = windowParams(w);

        String symptomsCte = withSymptoms
                ? """
                  sym AS (
                    SELECT t.user_id, 100.0 * AVG(CASE WHEN t.overall_severity IN ('URGENT', 'EMERGENCY') THEN 1 ELSE 0 END) AS pct_urgent
                      FROM symptom_logs t JOIN cohort c ON c.user_id = t.user_id
                     WHERE t.measured_at >= :wFrom AND t.measured_at < :wTo
                     GROUP BY t.user_id)"""
                : "sym AS (SELECT NULL::uuid AS user_id, NULL::numeric AS pct_urgent WHERE FALSE)";

        String sql = "WITH " + CohortSql.cte(req.cohort(), scope, p) + """
                ,
                adh AS (
                    SELECT t.user_id, 100.0 * COUNT(*) FILTER (WHERE t.status = 'TAKEN') / COUNT(*) AS adherence
                      FROM dose_logs t JOIN cohort c ON c.user_id = t.user_id
                     WHERE t.scheduled_date BETWEEN :dFrom AND :dTo
                     GROUP BY t.user_id),
                bp AS (
                    SELECT t.user_id,
                           AVG((t.vital_values->>'systolic')::numeric) AS sys,
                           AVG((t.vital_values->>'diastolic')::numeric) AS dia,
                           100.0 * AVG(CASE WHEN t.flagged THEN 1 ELSE 0 END) AS pct_flag
                      FROM vitals_logs t JOIN cohort c ON c.user_id = t.user_id
                     WHERE t.type = 'BLOOD_PRESSURE' AND t.measured_at >= :wFrom AND t.measured_at < :wTo
                     GROUP BY t.user_id),
                """ + symptomsCte + """
                ,
                banded AS (
                    SELECT a.adherence,
                           CASE WHEN a.adherence < 50 THEN 1 WHEN a.adherence < 80 THEN 2 ELSE 3 END AS band,
                           bp.sys, bp.dia, bp.pct_flag, sym.pct_urgent
                      FROM adh a
                      LEFT JOIN bp ON bp.user_id = a.user_id
                      LEFT JOIN sym ON sym.user_id = a.user_id)
                SELECT band, COUNT(*) AS patients, AVG(adherence)::float8 AS adherence,
                       COUNT(sys) AS with_bp, AVG(sys)::float8 AS sys, AVG(dia)::float8 AS dia,
                       AVG(pct_flag)::float8 AS pct_flag, AVG(pct_urgent)::float8 AS pct_urgent,
                       COUNT(pct_urgent) AS with_sym
                  FROM banded GROUP BY band ORDER BY band""";

        Map<Integer, AdherenceBand> byBand = new java.util.HashMap<>();
        String[] labels = {"", "Under 50% taken", "50–79% taken", "80% or more taken"};
        jdbc.query(sql, p, rs -> {
            int band = rs.getInt("band");
            long patients = rs.getLong("patients");
            long withBp = rs.getLong("with_bp");
            long withSym = rs.getLong("with_sym");
            if (patients < scope.k()) {
                byBand.put(band, new AdherenceBand(labels[band], true, null, null, null, null, null, null, null));
                return;
            }
            boolean bpOk = withBp >= scope.k();
            byBand.put(band, new AdherenceBand(labels[band], false, patients, round(rs, "adherence"),
                    bpOk ? withBp : null, bpOk ? round(rs, "sys") : null, bpOk ? round(rs, "dia") : null,
                    bpOk ? round(rs, "pct_flag") : null,
                    withSymptoms && withSym >= scope.k() ? round(rs, "pct_urgent") : null));
        });
        List<AdherenceBand> bands = new ArrayList<>();
        for (int b = 1; b <= 3; b++) {
            bands.add(byBand.getOrDefault(b, new AdherenceBand(labels[b], false, 0L, null, null, null, null, null, null)));
        }
        return new AdherenceResult(windowView(w), bands, withSymptoms, scope.k());
    }

    // ---- correlation -----------------------------------------------------------------------

    public CorrelationResult correlation(ResearchScope scope, CorrelationRequest req) {
        Metric mx = MetricCatalog.get(req.metricX());
        Metric my = MetricCatalog.get(req.metricY());
        scope.require(mx.dataset());
        scope.require(my.dataset());
        Window w = scope.window(req.from(), req.to());
        MapSqlParameterSource p = windowParams(w);

        String base = "WITH " + CohortSql.cte(req.cohort(), scope, p) + ",\n"
                + perPatient("x", mx) + ",\n" + perPatient("y", my) + """
                ,
                xy AS (SELECT x.user_id, x.v AS xv, y.v AS yv FROM x JOIN y ON y.user_id = x.user_id)""";

        record Summary(long n, Double r, Double x5, Double x95, Double y5, Double y95) {
        }
        Summary s = jdbc.queryForObject(base + """

                SELECT COUNT(*) AS n, CORR(xv, yv) AS r,
                       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY xv) AS x5, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY xv) AS x95,
                       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY yv) AS y5, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY yv) AS y95
                  FROM xy""", p, (rs, i) -> new Summary(rs.getLong("n"), nullableDouble(rs, "r"),
                nullableDouble(rs, "x5"), nullableDouble(rs, "x95"), nullableDouble(rs, "y5"), nullableDouble(rs, "y95")));

        long n = s == null ? 0 : s.n();
        if (n < scope.k()) {
            return new CorrelationResult(MetricView.of(mx), MetricView.of(my), windowView(w), n > 0, n == 0 ? 0L : null,
                    null, null, null, null, null, scope.k());
        }
        Double r = s.r() == null ? null : round(s.r());
        Double ciLow = null;
        Double ciHigh = null;
        if (s.r() != null && n > 3 && Math.abs(s.r()) < 1) {
            // Fisher z-transform: z = atanh(r), SE = 1/sqrt(n-3), 95% CI = tanh(z ± 1.96·SE).
            double z = 0.5 * Math.log((1 + s.r()) / (1 - s.r()));
            double se = 1 / Math.sqrt(n - 3.0);
            ciLow = round(Math.tanh(z - 1.96 * se));
            ciHigh = round(Math.tanh(z + 1.96 * se));
        }

        List<ScatterPoint> points = null;
        Grid grid = null;
        if (scope.level() == AccessLevel.PSEUDONYMOUS) {
            points = jdbc.query(base + "\nSELECT user_id, xv::float8 AS xv, yv::float8 AS yv FROM xy", p,
                    (rs, i) -> new ScatterPoint(pseudonymizer.of(scope.researcherId(), rs.getObject("user_id", UUID.class)),
                            round(rs.getDouble("xv")), round(rs.getDouble("yv"))));
        } else {
            grid = grid(base, p, s.x5(), s.x95(), s.y5(), s.y95(), scope.k());
        }
        return new CorrelationResult(MetricView.of(mx), MetricView.of(my), windowView(w), false, n, r, ciLow, ciHigh,
                points, grid, scope.k());
    }

    /** A GRID x GRID count matrix over p5..p95 of each axis, with small cells hidden. */
    private Grid grid(String base, MapSqlParameterSource p, double x5, double x95, double y5, double y95, int k) {
        double xHi = x95 > x5 ? x95 : x5 + 1;
        double yHi = y95 > y5 ? y95 : y5 + 1;
        MapSqlParameterSource q = copy(p).addValue("x5", x5).addValue("x95", xHi).addValue("y5", y5).addValue("y95", yHi)
                .addValue("g", GRID);
        long[][] counts = new long[GRID][GRID];
        jdbc.query(base + """

                SELECT LEAST(GREATEST(WIDTH_BUCKET(xv::float8, CAST(:x5 AS float8), CAST(:x95 AS float8), CAST(:g AS int)), 1), CAST(:g AS int)) AS bx,
                       LEAST(GREATEST(WIDTH_BUCKET(yv::float8, CAST(:y5 AS float8), CAST(:y95 AS float8), CAST(:g AS int)), 1), CAST(:g AS int)) AS by,
                       COUNT(*) AS n
                  FROM xy GROUP BY bx, by""", q, rs -> {
            counts[rs.getInt("by") - 1][rs.getInt("bx") - 1] = rs.getLong("n");
        });
        List<List<Long>> rows = new ArrayList<>();
        for (long[] row : counts) {
            List<Long> cells = new ArrayList<>();
            for (long c : row) {
                cells.add(c > 0 && c < k ? null : c);
            }
            rows.add(cells);
        }
        return new Grid(edges(x5, xHi), edges(y5, yHi), rows);
    }

    private static List<Double> edges(double lo, double hi) {
        List<Double> out = new ArrayList<>();
        for (int i = 0; i <= GRID; i++) {
            out.add(round(lo + (hi - lo) * i / GRID));
        }
        return out;
    }

    // ---- severity mix ----------------------------------------------------------------------

    public SeverityResult severity(ResearchScope scope, SeverityRequest req) {
        scope.require(Dataset.SYMPTOMS);
        Window w = scope.window(req.from(), req.to());
        MapSqlParameterSource p = windowParams(w).addValue("period", periodSql(req.period()));
        String sql = "WITH " + CohortSql.cte(req.cohort(), scope, p) + """

                SELECT CAST(DATE_TRUNC(CAST(:period AS text), t.measured_at AT TIME ZONE 'UTC') AS date) AS bucket,
                       COUNT(*) AS checkins, COUNT(DISTINCT t.user_id) AS patients,
                       COUNT(*) FILTER (WHERE t.overall_severity = 'NONE') AS s_none,
                       COUNT(*) FILTER (WHERE t.overall_severity = 'MONITOR') AS s_monitor,
                       COUNT(*) FILTER (WHERE t.overall_severity = 'URGENT') AS s_urgent,
                       COUNT(*) FILTER (WHERE t.overall_severity = 'EMERGENCY') AS s_emergency
                  FROM symptom_logs t JOIN cohort c ON c.user_id = t.user_id
                 WHERE t.measured_at >= :wFrom AND t.measured_at < :wTo
                 GROUP BY bucket ORDER BY bucket""";
        List<SeverityBucket> buckets = jdbc.query(sql, p, (rs, i) -> {
            long patients = rs.getLong("patients");
            LocalDate bucket = rs.getObject("bucket", LocalDate.class);
            if (patients < scope.k()) {
                return new SeverityBucket(bucket, true, null, null, null);
            }
            Map<Severity, Long> counts = new EnumMap<>(Severity.class);
            counts.put(Severity.NONE, rs.getLong("s_none"));
            counts.put(Severity.MONITOR, rs.getLong("s_monitor"));
            counts.put(Severity.URGENT, rs.getLong("s_urgent"));
            counts.put(Severity.EMERGENCY, rs.getLong("s_emergency"));
            return new SeverityBucket(bucket, false, patients, rs.getLong("checkins"), counts);
        });
        return new SeverityResult(req.period(), windowView(w), buckets, scope.k());
    }

    // ---- SQL helpers -----------------------------------------------------------------------

    /** {@code vals(user_id, value, ts, grp)}: one row per record carrying the metric, in cohort and window. */
    static String valuesCte(Metric m, String groupSql) {
        String ts = m.dateTyped() ? m.timeSql() + "::timestamp" : m.timeSql() + " AT TIME ZONE 'UTC'";
        return """
                vals AS (
                    SELECT t.user_id, %s AS value, %s AS ts, %s AS grp
                      FROM %s t
                      JOIN cohort c ON c.user_id = t.user_id
                      LEFT JOIN patient_profiles p ON p.user_id = t.user_id
                      LEFT JOIN users gu ON gu.id = t.user_id
                     WHERE %s AND %s)""".formatted(m.value(), ts, groupSql, m.table(), m.filter(), windowSql(m));
    }

    private static String perPatient(String name, Metric m) {
        return """
                %s AS (
                    SELECT t.user_id, AVG(%s) AS v
                      FROM %s t JOIN cohort c ON c.user_id = t.user_id
                     WHERE %s AND %s
                     GROUP BY t.user_id)""".formatted(name, m.value(), m.table(), m.filter(), windowSql(m));
    }

    static String windowSql(Metric m) {
        return m.dateTyped()
                ? m.timeSql() + " BETWEEN :dFrom AND :dTo"
                : m.timeSql() + " >= :wFrom AND " + m.timeSql() + " < :wTo";
    }

    private static String groupSql(GroupBy g) {
        return switch (g) {
            case NONE -> "NULL::text";
            case AGE_BAND -> "(" + AgeBands.SQL + ")";
            case CHD_STAGE -> "p.chd_stage";
            case LANGUAGE -> "gu.preferred_language";
        };
    }

    static MapSqlParameterSource windowParams(Window w) {
        return new MapSqlParameterSource()
                .addValue("wFrom", w.startInstant())
                .addValue("wTo", w.endInstant())
                .addValue("dFrom", w.from())
                .addValue("dTo", w.to());
    }

    private static MapSqlParameterSource copy(MapSqlParameterSource p) {
        return new MapSqlParameterSource(p.getValues());
    }

    private static String periodSql(Period period) {
        return period == Period.WEEK ? "week" : "month";
    }

    static WindowView windowView(Window w) {
        return new WindowView(w.shownFrom(), w.shownTo());
    }

    private long count(String sql, MapSqlParameterSource p) {
        Long n = jdbc.queryForObject(sql, p, Long.class);
        return n == null ? 0 : n;
    }

    private static Double nullableDouble(ResultSet rs, String col) throws SQLException {
        double v = rs.getDouble(col);
        return rs.wasNull() ? null : v;
    }

    private static Double round(ResultSet rs, String col) throws SQLException {
        Double v = nullableDouble(rs, col);
        return v == null ? null : round(v);
    }

    static double round(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
