import { MetricCard } from '../components/MetricCard'
import { PageTitle, Panel } from '../components/Panel'
import { PerformanceChart } from '../components/PerformanceChart'
import { QueryState, SourceUnavailable } from '../components/SourceUnavailable'
import { StatusIndicator } from '../components/StatusIndicator'
import { useInfrastructure } from '../hooks/useMonitoring'
import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../lib/format'
import { THRESHOLDS, toneFor } from '../lib/tone'

const STATUS_SOURCE: Record<string, string> = {
  prometheus: 'from its metrics endpoint',
  probe: 'from a health check',
  cadvisor: 'from cAdvisor',
  self: 'this service',
  none: 'no signal',
}

export function Infrastructure() {
  const { data, isLoading, error } = useInfrastructure()
  if (!data) return <QueryState isLoading={isLoading} error={error} />
  const host = data.host

  return (
    <>
      <PageTitle title="Infrastructure">The Windows server running the platform, and each container on it.</PageTitle>

      {host.source === 'UNAVAILABLE' && (
        <div className="mb-6">
          <SourceUnavailable title="Host metrics are not available">
            windows_exporter is not reachable, so CPU below is the Docker VM rather than the server. Install it with{' '}
            <code>monitoring\windows-exporter\install.ps1</code> from an Administrator PowerShell.
          </SourceUnavailable>
        </div>
      )}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label={host.cpuSource === 'docker-vm' ? 'CPU (Docker VM)' : 'CPU'}
          value={fmtPercent(host.cpuUsagePercent)}
          tone={toneFor(host.cpuUsagePercent, ...THRESHOLDS.cpu)}
          size="lead"
        />
        <MetricCard
          label="Memory"
          value={fmtPercent(host.memoryUsagePercent)}
          hint={host.memoryTotalBytes ? `${fmtBytes(host.memoryUsedBytes)} of ${fmtBytes(host.memoryTotalBytes)}` : undefined}
          tone={toneFor(host.memoryUsagePercent, ...THRESHOLDS.memory)}
          size="lead"
        />
        <MetricCard
          label="Disk"
          value={fmtPercent(host.diskUsagePercent)}
          hint={host.diskFreeBytes !== null ? `${fmtBytes(host.diskFreeBytes)} free` : undefined}
          tone={toneFor(host.diskUsagePercent, ...THRESHOLDS.disk)}
          size="lead"
        />
        <MetricCard
          label="Network"
          value={fmtBytesPerSec(host.networkReceiveBytesPerSec)}
          hint={`in, ${fmtBytesPerSec(host.networkTransmitBytesPerSec)} out`}
          size="lead"
        />
      </div>

      <Panel
        title="Containers"
        aside={
          data.containerMetricsSource === 'OK'
            ? 'CPU and memory from cAdvisor'
            : 'Status from health checks; per-container CPU and memory not enabled'
        }
        className="mb-6"
      >
        <ul className="divide-y divide-line">
          {data.containers.map((c) => (
            <li key={c.name} className="grid gap-2 py-3 sm:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)] sm:items-center">
              <div>
                <p className="font-bold">{c.displayName}</p>
                <p className="text-xs text-faint">{c.name}</p>
              </div>
              <div>
                <StatusIndicator status={c.status} />
                <p className="text-xs text-faint">{STATUS_SOURCE[c.statusSource] ?? c.statusSource}</p>
              </div>
              <p className="text-sm">
                <span className="text-muted">CPU </span>
                {fmtPercent(c.cpuPercent)}
              </p>
              <p className="text-sm">
                <span className="text-muted">Memory </span>
                {fmtBytes(c.memoryBytes)}
              </p>
            </li>
          ))}
        </ul>
      </Panel>

      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="CPU over time" aside="Last 15 minutes">
          <PerformanceChart
            series={data.cpuOverTime}
            format={(v) => `${Math.round(v)}%`}
            label={(n) => n.replace(/^heartcare-/, '')}
          />
        </Panel>
        <Panel title="Memory over time" aside="Last 15 minutes">
          {data.memoryOverTime.length ? (
            <PerformanceChart series={data.memoryOverTime} format={(v) => `${Math.round(v)}%`} percent label={(n) => n} />
          ) : (
            <p className="text-sm text-faint">Needs windows_exporter on the host.</p>
          )}
        </Panel>
        <Panel title="Server network traffic" aside="Last 15 minutes" className="xl:col-span-2">
          {data.networkOverTime.length ? (
            <PerformanceChart series={data.networkOverTime} format={(v) => fmtBytesPerSec(v)} label={(n) => n} />
          ) : (
            <p className="text-sm text-faint">Needs windows_exporter on the host.</p>
          )}
        </Panel>
      </div>
    </>
  )
}
