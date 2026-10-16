import { MetricCard } from '../components/MetricCard'
import { Panel, PageTitle } from '../components/Panel'
import { PulseTrace } from '../components/PulseTrace'
import { QueryState, SourceUnavailable } from '../components/SourceUnavailable'
import { StatusIndicator } from '../components/StatusIndicator'
import { useHistory, useOverview } from '../hooks/useMonitoring'
import { clientName, fmtInt, fmtMs, fmtPercent, fmtRate } from '../lib/format'
import { THRESHOLDS, toneFor } from '../lib/tone'

const SOURCE_NAMES: Record<string, string> = {
  prometheus: 'Metrics store',
  backend: 'Backend API',
  database: 'Database',
  host: 'Host metrics',
  containers: 'Per-container metrics',
}

/** Optional add-ons: when absent they are "not enabled", not "down". The system works without them. */
const OPTIONAL_SOURCES = new Set(['host', 'containers'])

function sourceStatus(name: string, status: string) {
  if (status === 'OK') return 'RUNNING' as const
  return OPTIONAL_SOURCES.has(name) ? ('NOT_ENABLED' as const) : ('DOWN' as const)
}

export function Overview() {
  const { data, isLoading, error } = useOverview()
  const { data: rps } = useHistory('rps', '15m')

  if (!data) return <QueryState isLoading={isLoading} error={error} />

  const users = Object.entries(data.activeUsersByClient)
    .filter(([, n]) => n > 0)
    .map(([c, n]) => `${clientName(c)} ${n}`)
    .join(', ')

  return (
    <>
      <PageTitle title="Overview">What the system is doing right now, across the admin, researcher and mobile apps.</PageTitle>

      <div className="mb-4 grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        <div className="flex flex-col justify-between gap-4 rounded-lg border border-line bg-surface p-5">
          <div>
            <p className="text-sm text-muted">System health</p>
            <div className="mt-2">
              <StatusIndicator status={data.systemStatus} size="lg" />
            </div>
          </div>
          {data.statusReasons.length > 0 ? (
            <ul className="list-disc space-y-1 pl-5 text-sm text-muted">
              {data.statusReasons.map((r) => (
                <li key={r}>{r}</li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-muted">Backend and database responding; error rate and latency within limits.</p>
          )}
        </div>
        <PulseTrace series={rps?.[0]} current={data.requestsPerSecond} />
      </div>

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <MetricCard
          label="Active users (last 5 minutes)"
          value={fmtInt(data.activeUsers)}
          hint={users || 'No signed-in users seen recently'}
          size="lead"
        />
        <MetricCard
          label="API requests since backend start"
          value={fmtInt(data.totalRequests)}
          hint={`Now ${fmtRate(data.requestsPerSecond)}`}
          size="lead"
        />
        <MetricCard
          label="Average response time (1 min)"
          value={fmtMs(data.averageLatencyMs)}
          hint={`95% of requests within ${fmtMs(data.p95LatencyMs)}`}
          tone={toneFor(data.averageLatencyMs, ...THRESHOLDS.avgMs)}
          size="lead"
        />
        <MetricCard
          label={data.cpuSource === 'docker-vm' ? 'CPU usage (Docker VM)' : 'CPU usage (server)'}
          value={fmtPercent(data.cpuUsagePercent)}
          hint={data.cpuSource === 'docker-vm' ? 'Install windows_exporter for host CPU' : undefined}
          tone={toneFor(data.cpuUsagePercent, ...THRESHOLDS.cpu)}
        />
        <MetricCard
          label="Memory usage (server)"
          value={fmtPercent(data.memoryUsagePercent)}
          hint={data.memoryUsagePercent === null ? 'Host memory needs windows_exporter' : undefined}
          tone={toneFor(data.memoryUsagePercent, ...THRESHOLDS.memory)}
        />
        <MetricCard
          label="Server error rate (5 min)"
          value={fmtPercent(data.errorRatePercent)}
          tone={toneFor(data.errorRatePercent, ...THRESHOLDS.errorRate)}
        />
      </div>

      <Panel title="Metrics sources">
        <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          {Object.entries(data.sources).map(([name, status]) => (
            <li key={name} className="flex items-center justify-between gap-3 rounded-md bg-night/50 px-3 py-2">
              <span className="text-sm">{SOURCE_NAMES[name] ?? name}</span>
              <StatusIndicator status={sourceStatus(name, status)} />
            </li>
          ))}
        </ul>
        {data.sources.prometheus === 'UNAVAILABLE' && (
          <div className="mt-4">
            <SourceUnavailable title="Prometheus is not answering">
              Start the monitoring stack with <code>docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d</code>.
            </SourceUnavailable>
          </div>
        )}
      </Panel>
    </>
  )
}
