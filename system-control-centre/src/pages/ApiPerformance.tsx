// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import { Bar, BarChart, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { DataTable } from '../components/DataTable'
import { MetricCard } from '../components/MetricCard'
import { PageTitle, Panel } from '../components/Panel'
import { PerformanceChart } from '../components/PerformanceChart'
import { QueryState } from '../components/SourceUnavailable'
import { useApiPerformance } from '../hooks/useMonitoring'
import { clientName, fmtInt, fmtMs, fmtPercent, fmtRate } from '../lib/format'
import { seriesColour, THRESHOLDS, toneFor } from '../lib/tone'
import type { Breakdown, EndpointStat } from '../services/types'

function statusColour(code: string) {
  if (code.startsWith('5')) return 'var(--crit)'
  if (code.startsWith('4')) return 'var(--warn)'
  if (code.startsWith('2')) return 'var(--ok)'
  return 'var(--faint)'
}

function BreakdownBars({ rows, colour, label }: { rows: Breakdown[]; colour: (name: string, i: number) => string; label?: (n: string) => string }) {
  if (rows.length === 0) return <p className="text-sm text-faint">No requests recorded yet.</p>
  return (
    <div style={{ height: Math.max(120, rows.length * 36) }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={rows} layout="vertical" margin={{ left: 8, right: 16 }}>
          <XAxis type="number" hide />
          <YAxis
            type="category"
            dataKey="name"
            width={96}
            tickFormatter={label}
            tick={{ fill: 'var(--muted)', fontSize: 13 }}
            stroke="var(--line)"
          />
          <Tooltip
            cursor={{ fill: 'var(--surface-raised)' }}
            contentStyle={{ background: 'var(--surface-raised)', border: '1px solid var(--line-strong)', borderRadius: 6 }}
            formatter={(v) => [fmtInt(Number(v)), 'Requests']}
            labelFormatter={(n) => (label ? label(String(n)) : String(n))}
          />
          <Bar dataKey="value" radius={[0, 3, 3, 0]} isAnimationActive={false}>
            {rows.map((r, i) => (
              <Cell key={r.name} fill={colour(r.name, i)} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

const columns = [
  {
    header: 'Endpoint',
    cell: (e: EndpointStat) => (
      <span className="break-all">
        <span className="mr-2 text-faint">{e.method}</span>
        {e.uri}
      </span>
    ),
  },
  { header: 'App', cell: (e: EndpointStat) => clientName(e.client) },
  { header: 'Requests', align: 'right' as const, cell: (e: EndpointStat) => fmtInt(e.requests) },
  { header: 'Avg. latency', align: 'right' as const, cell: (e: EndpointStat) => fmtMs(e.averageLatencyMs) },
  {
    header: 'Error rate',
    align: 'right' as const,
    cell: (e: EndpointStat) => (
      <span className={toneFor(e.errorRatePercent, ...THRESHOLDS.errorRate) === 'ok' ? '' : 'text-crit'}>
        {fmtPercent(e.errorRatePercent)}
      </span>
    ),
  },
]

export function ApiPerformance() {
  const { data, isLoading, error } = useApiPerformance()
  if (!data) return <QueryState isLoading={isLoading} error={error} />

  return (
    <>
      <PageTitle title="API performance">
        Every request the backend has served since it last started, split by endpoint, status and app.
      </PageTitle>

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <MetricCard label="Requests per second (1 min)" value={fmtRate(data.requestsPerSecond)} size="lead" />
        <MetricCard
          label="Average response time (1 min)"
          value={fmtMs(data.averageLatencyMs)}
          tone={toneFor(data.averageLatencyMs, ...THRESHOLDS.avgMs)}
          size="lead"
        />
        <MetricCard
          label="P95 response time (5 min)"
          value={fmtMs(data.p95LatencyMs)}
          hint="95% of requests finished within this"
          tone={toneFor(data.p95LatencyMs, ...THRESHOLDS.p95Ms)}
          size="lead"
        />
        <MetricCard label="Total requests" value={fmtInt(data.totalRequests)} size="compact" />
        <MetricCard
          label="Failed requests (server errors)"
          value={fmtInt(data.failedRequests)}
          hint={`${fmtInt(data.clientErrors)} client errors (4xx) counted separately`}
          tone={data.failedRequests ? 'crit' : 'neutral'}
          size="compact"
        />
        <MetricCard
          label="Success rate"
          value={fmtPercent(data.successRatePercent)}
          hint={`Server error rate, last 5 min: ${fmtPercent(data.errorRatePercent)}`}
          size="compact"
        />
      </div>

      <div className="mb-6 grid gap-4 xl:grid-cols-2">
        <Panel title="Requests over time" aside="Requests per second, last 15 minutes">
          <PerformanceChart series={data.requestsOverTime} format={(v) => fmtRate(v)} />
        </Panel>
        <Panel title="Response time over time" aside="Last 15 minutes">
          <PerformanceChart
            series={data.latencyOverTime}
            format={(v) => fmtMs(v)}
            label={(n) => (n === 'p95' ? 'P95' : 'Average')}
          />
        </Panel>
        <Panel title="Requests by app">
          <BreakdownBars rows={data.requestsByClient} colour={seriesColour} label={clientName} />
        </Panel>
        <Panel title="HTTP status codes">
          <BreakdownBars rows={data.statusCodes} colour={(n) => statusColour(n)} />
        </Panel>
      </div>

      <Panel title="Endpoint performance" aside="Top 25 endpoints by request count">
        <DataTable
          rows={data.endpoints}
          columns={columns}
          rowKey={(e) => `${e.method} ${e.uri}`}
          empty="No requests recorded yet. Use the admin, researcher or mobile app to generate traffic."
        />
      </Panel>
    </>
  )
}
