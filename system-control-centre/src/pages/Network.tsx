import { MetricCard } from '../components/MetricCard'
import { PageTitle, Panel } from '../components/Panel'
import { PerformanceChart } from '../components/PerformanceChart'
import { QueryState } from '../components/SourceUnavailable'
import { StatusIndicator } from '../components/StatusIndicator'
import { useNetwork } from '../hooks/useMonitoring'
import { clientName, fmtBytesPerSec, fmtInt, fmtRate } from '../lib/format'

export function Network() {
  const { data, isLoading, error } = useNetwork()
  if (!data) return <QueryState isLoading={isLoading} error={error} />
  const ngrok = data.ngrok

  return (
    <>
      <PageTitle title="Network">
        Web apps on the local network compared with the mobile app, which reaches the backend through the ngrok
        tunnel. Traffic is classified by which signed-in app made the request, not by request headers.
      </PageTitle>

      <div className="mb-6 grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        <div className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-5">
          <p className="text-sm text-muted">Ngrok tunnel</p>
          <StatusIndicator status={ngrok.status} size="lg" />
          {ngrok.publicUrl && <p className="break-all text-sm">{ngrok.publicUrl}</p>}
          <p className="text-sm text-faint">{ngrok.detail}</p>
          {ngrok.requestsThroughTunnel !== null && (
            <p className="text-sm">
              <span className="text-muted">Requests through the tunnel </span>
              <span className="font-bold">{fmtInt(ngrok.requestsThroughTunnel)}</span>
            </p>
          )}
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <MetricCard label="Local web requests (admin + researcher)" value={fmtRate(data.webRequestsPerSecond)} size="lead" />
          <MetricCard
            label="Mobile API requests"
            value={fmtRate(data.mobileRequestsPerSecond)}
            hint={`${fmtInt(data.mobileRequestsTotal)} since backend start`}
            size="lead"
          />
          <MetricCard
            label="Failed mobile requests"
            value={fmtInt(data.mobileFailedRequests)}
            hint={`Server errors; ${fmtInt(data.mobileClientErrors)} client errors separately`}
            tone={data.mobileFailedRequests ? 'crit' : 'neutral'}
            size="compact"
          />
          <MetricCard
            label="Failed web requests"
            value={fmtInt(data.webFailedRequests)}
            tone={data.webFailedRequests ? 'crit' : 'neutral'}
            size="compact"
          />
        </div>
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="Requests per second by app" aside="Last 15 minutes">
          <PerformanceChart series={data.requestsPerSecondByClient} format={(v) => fmtRate(v)} />
        </Panel>
        <Panel title="Server network traffic" aside="Incoming and outgoing, last 15 minutes">
          {data.hostSource === 'OK' ? (
            <>
              <p className="mb-3 text-sm">
                <span className="text-muted">Now </span>
                <span className="font-bold">{fmtBytesPerSec(data.hostReceiveBytesPerSec)}</span>
                <span className="text-muted"> in, </span>
                <span className="font-bold">{fmtBytesPerSec(data.hostTransmitBytesPerSec)}</span>
                <span className="text-muted"> out</span>
              </p>
              <PerformanceChart series={data.hostTrafficOverTime} format={(v) => fmtBytesPerSec(v)} label={(n) => n} />
            </>
          ) : (
            <p className="text-sm text-faint">Server traffic needs windows_exporter on the host.</p>
          )}
        </Panel>
        <Panel title="Requests by app since backend start" className="xl:col-span-2">
          <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {data.requestsByClient.map((b) => (
              <li key={b.name} className="rounded-md bg-night/50 px-4 py-3">
                <p className="text-sm text-muted">{clientName(b.name)}</p>
                <p className="text-2xl font-bold">{fmtInt(b.value)}</p>
              </li>
            ))}
          </ul>
        </Panel>
      </div>
    </>
  )
}
