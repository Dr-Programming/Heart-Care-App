import { PageTitle, Panel } from '../components/Panel'
import { QueryState, SourceUnavailable } from '../components/SourceUnavailable'
import { useActivity } from '../hooks/useMonitoring'
import { clientName, fmtClock, fmtInt, fmtMs } from '../lib/format'
import { SERIES_COLOURS } from '../lib/tone'
import type { ActivityEvent } from '../services/types'

const OUTCOME: Record<ActivityEvent['outcome'], { text: string; className: string }> = {
  success: { text: 'Completed', className: 'text-muted' },
  client_error: { text: 'Rejected', className: 'text-warn' },
  server_error: { text: 'Failed', className: 'text-crit' },
}

export function Activity() {
  const { data, isLoading, error } = useActivity()
  if (!data) return <QueryState isLoading={isLoading} error={error} />

  return (
    <>
      <PageTitle title="Activity">
        What people are doing in the platform, newest first. Events are anonymised by the backend: no names, ids
        or record contents are ever sent here.
      </PageTitle>

      {data.source === 'UNAVAILABLE' ? (
        <SourceUnavailable title="The backend's activity feed is not reachable">
          The Monitoring API reads it from the backend's internal management port (9081). Check that the backend is
          running on the same Docker network.
        </SourceUnavailable>
      ) : (
        <div className="grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <Panel title="Timeline" aside={`Last ${data.events.length} events`}>
            {data.events.length === 0 ? (
              <p className="text-sm text-faint">No activity yet. Sign in to the admin, researcher or mobile app and it appears here.</p>
            ) : (
              <ol className="space-y-0">
                {data.events.map((e, i) => (
                  <li
                    key={`${e.at}-${i}`}
                    className="grid grid-cols-[5.5rem_minmax(0,1fr)] gap-3 border-l-2 py-2 pl-3 sm:grid-cols-[5.5rem_minmax(0,1fr)_auto]"
                    style={{ borderColor: SERIES_COLOURS[e.client] ?? 'var(--line-strong)' }}
                  >
                    <time dateTime={e.at} className="text-sm text-muted">
                      {fmtClock(e.at)}
                    </time>
                    <span>{e.label}</span>
                    <span className={`col-start-2 text-sm sm:col-start-auto ${OUTCOME[e.outcome].className}`}>
                      {OUTCOME[e.outcome].text} in {fmtMs(e.durationMs)}
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </Panel>
          <Panel title="Last 5 minutes by app">
            <ul className="space-y-3">
              {['admin', 'researcher', 'mobile'].map((c) => (
                <li key={c} className="flex items-center justify-between gap-3">
                  <span className="flex items-center gap-2">
                    <span aria-hidden className="inline-block size-3 rounded-sm" style={{ background: SERIES_COLOURS[c] }} />
                    {clientName(c)}
                  </span>
                  <span className="text-2xl font-bold">{fmtInt(data.lastFiveMinutesByClient[c] ?? 0)}</span>
                </li>
              ))}
            </ul>
          </Panel>
        </div>
      )}
    </>
  )
}
