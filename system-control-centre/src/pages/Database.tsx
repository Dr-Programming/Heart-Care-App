import { DataTable } from '../components/DataTable'
import { MetricCard } from '../components/MetricCard'
import { PageTitle, Panel } from '../components/Panel'
import { PerformanceChart } from '../components/PerformanceChart'
import { QueryState, SourceUnavailable } from '../components/SourceUnavailable'
import { useDatabase } from '../hooks/useMonitoring'
import { fmtBytes, fmtDecimal, fmtInt, fmtMs, fmtPercent } from '../lib/format'
import { THRESHOLDS, toneFor } from '../lib/tone'
import type { QueryStat } from '../services/types'

const queryColumns = [
  {
    header: 'Statement',
    cell: (q: QueryStat) => <code className="block max-w-[60ch] break-words text-xs text-muted">{q.query}</code>,
  },
  { header: 'Calls', align: 'right' as const, cell: (q: QueryStat) => fmtInt(q.calls) },
  { header: 'Total time', align: 'right' as const, cell: (q: QueryStat) => fmtMs(q.totalTimeMs) },
  { header: 'Mean time', align: 'right' as const, cell: (q: QueryStat) => fmtMs(q.meanTimeMs) },
]

export function Database() {
  const { data, isLoading, error } = useDatabase()
  if (!data) return <QueryState isLoading={isLoading} error={error} />
  const pool = data.pool

  return (
    <>
      <PageTitle title="Database">
        PostgreSQL as the database sees it, next to the connection pool as the backend sees it. Statistics are
        sampled every few seconds, so read them as trends.
      </PageTitle>

      {data.source === 'UNAVAILABLE' && (
        <div className="mb-6">
          <SourceUnavailable title="PostgreSQL exporter is not reporting">
            Check that <code>postgres-exporter</code> is running and that <code>MONITORING_DB_PASSWORD</code> is set in
            .env. Connection pool figures below still come from the backend.
          </SourceUnavailable>
        </div>
      )}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label="Active connections"
          value={fmtInt(data.activeConnections)}
          hint={`of ${fmtInt(data.maxConnections)} allowed`}
          size="lead"
        />
        <MetricCard label="Transactions per second" value={fmtDecimal(data.transactionsPerSecond)} size="lead" />
        <MetricCard
          label="Cache hit ratio"
          value={fmtPercent(data.cacheHitRatioPercent)}
          hint="Reads served from memory rather than disk"
          tone={data.cacheHitRatioPercent === null ? 'neutral' : data.cacheHitRatioPercent < 90 ? 'warn' : 'ok'}
          size="lead"
        />
        <MetricCard label="Database size" value={fmtBytes(data.databaseSizeBytes)} size="lead" />
        <MetricCard
          label="Idle connections"
          value={fmtInt(data.idleConnections)}
          hint={`${fmtInt(data.idleInTransaction)} idle inside a transaction`}
          size="compact"
        />
        <MetricCard
          label="Slow statements"
          value={fmtInt(data.slowQueries)}
          hint={`Mean time above ${fmtMs(data.slowQueryThresholdMs)}`}
          tone={data.slowQueries ? 'warn' : 'neutral'}
          size="compact"
        />
        <MetricCard
          label="Deadlocks"
          value={fmtInt(data.deadlocks)}
          tone={data.deadlocks ? 'crit' : 'neutral'}
          size="compact"
        />
        <MetricCard
          label="Total sessions"
          value={fmtInt(data.totalConnections)}
          hint={`Database: ${data.databaseName}`}
          size="compact"
        />
      </div>

      <div className="mb-6 grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        <Panel title="Connection pool (backend)">
          <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            <dt className="text-muted">In use</dt>
            <dd className="text-right font-bold">
              {fmtInt(pool.active)} of {fmtInt(pool.max)}
            </dd>
            <dt className="text-muted">Utilisation</dt>
            <dd className={`text-right font-bold ${toneFor(pool.utilisationPercent, ...THRESHOLDS.poolUtilisation) === 'crit' ? 'text-crit' : ''}`}>
              {fmtPercent(pool.utilisationPercent)}
            </dd>
            <dt className="text-muted">Idle in pool</dt>
            <dd className="text-right font-bold">{fmtInt(pool.idle)}</dd>
            <dt className="text-muted">Requests waiting</dt>
            <dd className={`text-right font-bold ${pool.pending ? 'text-warn' : ''}`}>{fmtInt(pool.pending)}</dd>
            <dt className="text-muted">Average wait for a connection</dt>
            <dd className="text-right font-bold">{fmtMs(pool.averageAcquireMs)}</dd>
          </dl>
          <p className="mt-4 text-sm text-faint">
            Idle connections are normal. Watch requests waiting: that is when the pool, not the database, is the
            bottleneck.
          </p>
        </Panel>
        <Panel title="Database activity over time" aside="Last 15 minutes">
          <PerformanceChart series={data.activityOverTime} format={(v) => fmtDecimal(v)} label={(n) => n} />
        </Panel>
      </div>

      <Panel title="Top 10 statements by total execution time" aside="From pg_stat_statements">
        <DataTable
          rows={data.topQueries}
          columns={queryColumns}
          rowKey={(q) => q.queryId}
          empty="No statement statistics yet. pg_stat_statements fills in as the backend runs queries."
        />
      </Panel>
    </>
  )
}
