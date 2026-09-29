import { useState, type ReactNode } from 'react'
import type { ResearchActivity, Researcher } from '../../api/types'
import { fmtDateTime } from '../../lib/format'
import { Badge } from '../Badge'
import type { Column } from '../DataTable'

export function StatusBadge({ r }: { r: Researcher }) {
  if (r.status === 'ARCHIVED') return <Badge>Archived</Badge>
  if (r.status === 'REVOKED') return <Badge tone="heart">Revoked</Badge>
  if (r.expired) return <Badge tone="amber">Expired</Badge>
  if (r.mustChangePassword) return <Badge tone="amber">Awaiting first sign-in</Badge>
  return <Badge tone="calm">Active</Badge>
}

/** Two-step button for consequential actions: the first click asks, the second does. */
export function ConfirmAction({
  label,
  confirm,
  onConfirm,
  busy,
  tone = 'neutral',
}: {
  label: string
  confirm: ReactNode
  onConfirm: () => void
  busy?: boolean
  tone?: 'danger' | 'neutral'
}) {
  const [asking, setAsking] = useState(false)
  const base = 'rounded-md px-3 py-1.5 font-bold ring-1 disabled:opacity-50'
  const danger = tone === 'danger'
  if (!asking) {
    return (
      <button type="button" onClick={() => setAsking(true)} disabled={busy}
        className={`${base} ${danger ? 'text-heart ring-heart/40 hover:ring-heart' : 'ring-line hover:ring-line-strong'}`}>
        {label}
      </button>
    )
  }
  return (
    <div role="alertdialog" className="flex flex-wrap items-center gap-2 rounded-md bg-surface px-3 py-2 ring-1 ring-line-strong">
      <span className="text-[14px]">{confirm}</span>
      <button type="button" disabled={busy} onClick={() => { onConfirm(); setAsking(false) }}
        className={`${base} ${danger ? 'bg-heart text-white ring-heart' : 'bg-ink text-paper ring-ink'}`}>
        {busy ? 'Working…' : 'Yes, ' + label.toLowerCase()}
      </button>
      <button type="button" onClick={() => setAsking(false)} className={`${base} ring-line`}>
        Cancel
      </button>
    </div>
  )
}

/** "POST /api/v1/research/analytics/describe" reads better as "Describe". */
export function describePath(method: string, path: string): string {
  const rest = path.replace(/^\/api\/v1\/research\/?/, '')
  const known: Record<string, string> = {
    'auth/login': 'Sign in',
    'auth/me': 'Viewed account',
    'auth/change-password': 'Changed password',
    catalog: 'Opened catalogue',
    cohorts: method === 'POST' ? 'Saved cohort' : 'Listed cohorts',
    'cohorts/preview': 'Previewed cohort',
    'analytics/describe': 'Describe metric',
    'analytics/trend': 'Trend over time',
    'analytics/adherence-outcomes': 'Adherence vs outcomes',
    'analytics/correlation': 'Correlation',
    'analytics/severity': 'Symptom severity mix',
  }
  if (known[rest]) return known[rest]
  if (rest.startsWith('records/')) return `Browsed ${rest.slice(8)} records`
  if (rest.startsWith('cohorts/')) return method === 'DELETE' ? 'Deleted cohort' : 'Cohort'
  return `${method} ${rest}`
}

function outcome(a: ResearchActivity) {
  if (a.status < 300) return <Badge tone="calm">OK</Badge>
  if (a.status === 401 || a.status === 403 || a.status === 423) return <Badge tone="heart">Refused {a.status}</Badge>
  return <Badge tone="amber">Error {a.status}</Badge>
}

function params(json: string | null) {
  if (!json) return <span className="text-faint">—</span>
  const parsed = JSON.parse(json) as Record<string, unknown>
  const csv = parsed.format === 'csv'
  return (
    <details className="max-w-[40ch]">
      <summary className="cursor-pointer text-[13px] text-muted">
        {csv ? <span className="font-bold text-heart">CSV download</span> : 'Parameters'}
      </summary>
      <pre className="mt-1 max-h-48 overflow-auto rounded bg-paper p-2 text-[12px] whitespace-pre-wrap ring-1 ring-line">
        {JSON.stringify(parsed, null, 2)}
      </pre>
    </details>
  )
}

export function activityColumns(withResearcher: boolean): Column<ResearchActivity>[] {
  return [
    {
      id: 'when',
      header: 'When',
      meta: { width: '11rem' },
      cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDateTime(row.original.occurredAt)}</span>,
    },
    ...(withResearcher
      ? [
          {
            id: 'who',
            header: 'Researcher',
            cell: ({ row }: { row: { original: ResearchActivity } }) =>
              row.original.researcherUsername ? (
                <span className="inline-flex flex-wrap items-center gap-1.5">
                  <span className="font-bold">{row.original.researcherUsername}</span>
                  {row.original.researcherStatus === 'ARCHIVED' && <Badge>Archived</Badge>}
                </span>
              ) : (
                <span className="text-muted">
                  Unknown: <span className="num">{row.original.usernameAttempted ?? '—'}</span>
                </span>
              ),
          } as Column<ResearchActivity>,
        ]
      : []),
    { id: 'what', header: 'Action', cell: ({ row }) => describePath(row.original.method, row.original.path) },
    { id: 'outcome', header: 'Outcome', cell: ({ row }) => outcome(row.original) },
    {
      id: 'rows',
      header: 'Rows',
      meta: { align: 'right' },
      cell: ({ row }) => (row.original.rowsReturned == null ? '—' : row.original.rowsReturned.toLocaleString()),
    },
    { id: 'params', header: 'Details', cell: ({ row }) => params(row.original.paramsJson) },
    { id: 'ip', header: 'IP', cell: ({ row }) => <span className="num text-[13px] text-muted">{row.original.ip ?? '—'}</span> },
  ]
}
