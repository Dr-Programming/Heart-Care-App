import { useState, type ReactNode } from 'react'
import { researchApi } from '../api/research'
import { ApiError } from '../api/client'
import type { Catalog, CohortDefinition, MetricView, SavedCohort } from '../api/types'
import { useCatalog, useCohorts } from '../lib/useCatalog'
import { DateRange, Field } from './Controls'

export const ALL_PATIENTS = ''

const selectClass =
  'rounded-md bg-surface px-2.5 py-1.5 text-[14px] text-ink ring-1 ring-line hover:ring-line-strong focus:ring-accent focus:outline-none'

/** Saved cohorts plus "All patients". Returns the saved id; resolve with {@link cohortDefinition}. */
export function CohortSelect({ label = 'Cohort', value, onChange }: { label?: string; value: string; onChange: (id: string) => void }) {
  const cohorts = useCohorts()
  return (
    <Field label={label}>
      <select className={selectClass} value={value} onChange={(e) => onChange(e.target.value)}>
        <option value={ALL_PATIENTS}>All patients</option>
        {(cohorts.data ?? []).map((c) => (
          <option key={c.id} value={c.id}>
            {c.name}
          </option>
        ))}
      </select>
    </Field>
  )
}

export function cohortDefinition(cohorts: SavedCohort[] | undefined, id: string): CohortDefinition | undefined {
  return id ? cohorts?.find((c) => c.id === id)?.definition : undefined
}

export function cohortName(cohorts: SavedCohort[] | undefined, id: string): string {
  return id ? (cohorts?.find((c) => c.id === id)?.name ?? 'Cohort') : 'All patients'
}

export function MetricSelect({
  label = 'Measure',
  metrics,
  value,
  onChange,
}: {
  label?: string
  metrics: MetricView[]
  value: string
  onChange: (id: string) => void
}) {
  const groups = [...new Set(metrics.map((m) => m.group))]
  return (
    <Field label={label}>
      <select className={`${selectClass} max-w-xs`} value={value} onChange={(e) => onChange(e.target.value)}>
        {groups.map((g) => (
          <optgroup key={g} label={g}>
            {metrics.filter((m) => m.group === g).map((m) => (
              <option key={m.id} value={m.id}>
                {m.label} ({m.unit})
              </option>
            ))}
          </optgroup>
        ))}
      </select>
    </Field>
  )
}

export function ChoiceSelect<T extends string>({
  label,
  value,
  onChange,
  options,
}: {
  label: string
  value: T
  onChange: (v: T) => void
  options: { value: T; label: string }[]
}) {
  return (
    <Field label={label}>
      <select className={selectClass} value={value} onChange={(e) => onChange(e.target.value as T)}>
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </Field>
  )
}

/** The date window, pre-bounded to the researcher's grant. */
export function WindowFields({ from, to, onChange }: { from: string; to: string; onChange: (r: { from: string; to: string }) => void }) {
  return <DateRange from={from} to={to} onChange={onChange} />
}

export function Controls({ children }: { children: ReactNode }) {
  return <div className="mb-5 flex flex-wrap items-end gap-3">{children}</div>
}

export function Withheld({ k, inline }: { k: number; inline?: boolean }) {
  return inline ? (
    <span className="text-faint" title={`Fewer than ${k} patients`}>
      Hidden
    </span>
  ) : (
    <p className="withheld rounded-lg px-4 py-6 text-center text-muted ring-1 ring-line">
      Hidden: fewer than {k} patients match, so showing this could identify someone. Widen the cohort or the dates.
    </p>
  )
}

export function Panel({ title, children, aside }: { title: string; children: ReactNode; aside?: ReactNode }) {
  return (
    <section className="rounded-xl bg-surface ring-1 ring-line">
      <div className="flex flex-wrap items-baseline justify-between gap-2 border-b border-line px-5 py-3">
        <h2 className="text-[17px] font-bold">{title}</h2>
        {aside}
      </div>
      <div className="p-5">{children}</div>
    </section>
  )
}

/** Shown only when the grant allows exports; the server enforces it regardless. */
export function ExportButton({ path, body }: { path: string; body: unknown }) {
  const catalog = useCatalog()
  const [state, setState] = useState<'idle' | 'busy' | 'error'>('idle')
  const [message, setMessage] = useState('')
  if (!catalog.data?.exportAllowed) return null
  const run = async () => {
    setState('busy')
    try {
      await researchApi.exportCsv(path, body)
      setState('idle')
    } catch (e) {
      setState('error')
      setMessage(e instanceof ApiError ? e.message : 'Download failed.')
    }
  }
  return (
    <span className="inline-flex items-center gap-2">
      <button type="button" onClick={run} disabled={state === 'busy'}
        className="rounded-md px-3 py-1.5 text-[14px] font-bold text-accent ring-1 ring-line hover:ring-accent disabled:opacity-50">
        {state === 'busy' ? 'Preparing…' : 'Download CSV'}
      </button>
      {state === 'error' && <span className="text-[13px] text-alert">{message}</span>}
    </span>
  )
}

export function windowHint(c: Catalog | undefined) {
  if (!c || (!c.dataFrom && !c.dataTo)) return null
  return (
    <p className="mb-4 text-[14px] text-muted">
      Your access covers records {c.dataFrom ? `from ${c.dataFrom}` : ''}{c.dataFrom && c.dataTo ? ' ' : ''}{c.dataTo ? `to ${c.dataTo}` : ''}; dates outside that are ignored.
    </p>
  )
}

export const fmt = (n: number | null | undefined, digits = 1) =>
  n == null ? '—' : n.toLocaleString(undefined, { maximumFractionDigits: digits, minimumFractionDigits: 0 })
