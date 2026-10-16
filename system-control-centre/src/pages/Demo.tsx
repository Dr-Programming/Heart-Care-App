import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent } from 'react'
import { PageTitle, Panel } from '../components/Panel'
import { QueryState } from '../components/SourceUnavailable'
import { useDemoCurrent, useDemoSessions } from '../hooks/useMonitoring'
import { fmtDateTime, fmtDuration, fmtInt, fmtMs, fmtPercent, fmtRate } from '../lib/format'
import { ApiError } from '../services/client'
import { monitoringApi } from '../services/monitoringApi'
import type { DemoSession } from '../services/types'

const RESULT_TEXT: Record<string, { text: string; className: string }> = {
  RUNNING: { text: 'In progress', className: 'text-ok' },
  COMPLETED: { text: 'Completed', className: 'text-ok' },
  COMPLETED_WITH_ERRORS: { text: 'Completed with server errors', className: 'text-warn' },
  NO_DATA: { text: 'No measurements recorded', className: 'text-crit' },
}

function useElapsed(startedAt: string | undefined) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (!startedAt) return
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [startedAt])
  return startedAt ? Math.max(0, (now - Date.parse(startedAt)) / 1000) : 0
}

/** The report, laid out to be read aloud: measured figures in one column, nothing decorative. */
function Summary({ session }: { session: DemoSession }) {
  const s = session.summary
  if (!s) return <p className="text-sm text-faint">No summary yet.</p>
  const result = RESULT_TEXT[s.result] ?? RESULT_TEXT.COMPLETED
  const rows: [string, string][] = [
    ['Duration', fmtDuration(s.durationSeconds)],
    ['Peak active users', fmtInt(s.peakActiveUsers)],
    ['Total API requests', fmtInt(s.totalRequests)],
    ['Successful requests', fmtInt(s.successfulRequests)],
    ['Failed requests (5xx)', fmtInt(s.failedRequests)],
    ['Client errors (4xx)', fmtInt(s.clientErrors)],
    ['Peak requests per second', fmtRate(s.peakRequestsPerSecond)],
    ['Average API latency', fmtMs(s.averageLatencyMs)],
    ['P95 API latency', fmtMs(s.p95LatencyMs)],
    [s.cpuSource === 'docker-vm' ? 'Peak CPU (Docker VM)' : 'Peak CPU usage', fmtPercent(s.peakCpuPercent)],
    ['Peak memory usage', fmtPercent(s.peakMemoryPercent)],
    ['Peak database sessions', fmtInt(s.peakDatabaseConnections)],
  ]
  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
      <div>
        <dl className="divide-y divide-line">
          {rows.map(([k, v]) => (
            <div key={k} className="flex items-baseline justify-between gap-4 py-2">
              <dt className="text-muted">{k}</dt>
              <dd className="text-xl font-bold">{v}</dd>
            </div>
          ))}
          <div className="flex items-baseline justify-between gap-4 py-3">
            <dt className="text-muted">Overall result</dt>
            <dd className={`text-xl font-bold ${result.className}`}>{result.text}</dd>
          </div>
        </dl>
      </div>
      <div className="space-y-4 text-sm">
        <div className="rounded-md border border-line bg-night/50 p-4">
          <p className="font-bold">Test conditions</p>
          <p className="mt-1 text-muted">{session.conditions || 'None entered.'}</p>
          <p className="mt-2 text-xs text-faint">As entered by the operator. Not a measurement.</p>
        </div>
        <div className="rounded-md border border-line bg-night/50 p-4">
          <p className="font-bold">Baseline at start</p>
          <p className="mt-1 text-muted">
            CPU {fmtPercent(session.baseline.cpuUsagePercent)}, memory {fmtPercent(session.baseline.memoryUsagePercent)},{' '}
            {fmtInt(session.baseline.activeUsers)} active users, {fmtInt(session.baseline.databaseConnections)} database
            sessions.
          </p>
        </div>
        <ul className="list-disc space-y-1 pl-5 text-faint">
          {s.notes.map((n) => (
            <li key={n}>{n}</li>
          ))}
        </ul>
      </div>
    </div>
  )
}

function StartForm({ onStart, busy, error }: { onStart: (label: string, conditions: string) => void; busy: boolean; error: string | null }) {
  const [label, setLabel] = useState('')
  const [conditions, setConditions] = useState('')
  function submit(e: FormEvent) {
    e.preventDefault()
    onStart(label, conditions)
  }
  return (
    <form onSubmit={submit} className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)_auto] lg:items-end">
      <label className="block">
        <span className="mb-1 block text-sm text-muted">Name</span>
        <input
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          maxLength={80}
          placeholder="Judging session"
          className="w-full rounded-md border border-line bg-night px-3 py-2 outline-none focus:border-mobile"
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-sm text-muted">Test conditions</span>
        <input
          value={conditions}
          onChange={(e) => setConditions(e.target.value)}
          maxLength={500}
          placeholder="e.g. 30 JMeter users for 10 minutes, plus judges on admin and mobile"
          className="w-full rounded-md border border-line bg-night px-3 py-2 outline-none focus:border-mobile"
        />
      </label>
      <button
        type="submit"
        disabled={busy}
        className="rounded-md bg-ok px-6 py-2.5 font-bold text-night hover:brightness-110 disabled:opacity-60"
      >
        {busy ? 'Starting…' : 'Start demonstration'}
      </button>
      {error && (
        <p role="alert" className="text-sm text-crit lg:col-span-3">
          {error}
        </p>
      )}
    </form>
  )
}

export function Demo() {
  const queryClient = useQueryClient()
  const current = useDemoCurrent()
  const sessions = useDemoSessions()
  const running = current.data ?? null
  const elapsed = useElapsed(running?.startedAt)
  const [selected, setSelected] = useState<string | null>(null)

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['demo'] })
  const start = useMutation({
    mutationFn: ({ label, conditions }: { label: string; conditions: string }) => monitoringApi.demoStart(label, conditions),
    onSuccess: refresh,
  })
  const stop = useMutation({
    mutationFn: monitoringApi.demoStop,
    onSuccess: (done) => {
      setSelected(done.id)
      refresh()
    },
  })
  const exportJson = useMutation({ mutationFn: monitoringApi.demoExport })

  if (current.isLoading) return <QueryState isLoading error={null} />

  const past = sessions.data ?? []
  const shown = past.find((s) => s.id === selected) ?? past[0]
  const errorText = (e: unknown) => (e instanceof ApiError ? e.message : e ? 'Something went wrong. Try again.' : null)

  return (
    <>
      <PageTitle title="Demonstration">
        Records a session from start to stop and produces a performance report computed from the stored metrics, so
        the result does not depend on what happened to be on screen.
      </PageTitle>

      {running ? (
        <Panel
          title={running.label}
          aside={`Started ${fmtDateTime(running.startedAt)}`}
          className="mb-6 border-ok/60"
        >
          <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-sm text-muted">Elapsed</p>
              <p className="text-5xl font-bold tracking-tight text-ok">{fmtDuration(elapsed)}</p>
            </div>
            <button
              type="button"
              onClick={() => stop.mutate()}
              disabled={stop.isPending}
              className="rounded-md bg-crit px-6 py-3 text-lg font-bold text-night hover:brightness-110 disabled:opacity-60"
            >
              {stop.isPending ? 'Stopping…' : 'Stop and generate report'}
            </button>
          </div>
          {errorText(stop.error) && <p className="mb-4 text-sm text-crit">{errorText(stop.error)}</p>}
          <p className="mb-3 text-sm text-faint">Live figures so far, refreshed every few seconds.</p>
          <Summary session={running} />
        </Panel>
      ) : (
        <Panel title="Start a demonstration" className="mb-6">
          <StartForm
            busy={start.isPending}
            error={errorText(start.error)}
            onStart={(label, conditions) => start.mutate({ label, conditions })}
          />
        </Panel>
      )}

      {shown && (
        <Panel
          title={`Report: ${shown.label}`}
          aside={
            <button
              type="button"
              onClick={() => exportJson.mutate(shown.id)}
              className="rounded-md border border-line-strong px-3 py-1.5 text-sm text-ink hover:bg-raised"
            >
              Export JSON
            </button>
          }
          className="mb-6"
        >
          <p className="mb-4 text-sm text-muted">
            {fmtDateTime(shown.startedAt)} to {fmtDateTime(shown.endedAt)}
          </p>
          <Summary session={shown} />
        </Panel>
      )}

      {past.length > 1 && (
        <Panel title="Earlier demonstrations" aside="Kept until the Monitoring API restarts; export to keep them">
          <ul className="divide-y divide-line">
            {past.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center justify-between gap-3 py-2">
                <button
                  type="button"
                  onClick={() => setSelected(s.id)}
                  className={`text-left hover:underline ${s.id === shown?.id ? 'font-bold' : ''}`}
                >
                  {s.label}
                  <span className="ml-2 text-sm text-muted">{fmtDateTime(s.startedAt)}</span>
                </button>
                <span className="text-sm text-muted">
                  {fmtDuration(s.summary?.durationSeconds)}, {fmtInt(s.summary?.totalRequests)} requests
                </span>
              </li>
            ))}
          </ul>
        </Panel>
      )}
    </>
  )
}
