import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type ReactNode } from 'react'
import { researchApi } from '../api/research'
import { ApiError } from '../api/client'
import type { CohortDefinition, SavedCohort, Severity } from '../api/types'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtDate } from '../lib/format'
import { useCatalog, useCohorts } from '../lib/useCatalog'

const SEVERITY_LABEL: Record<Severity, string> = {
  NONE: 'Any check-in',
  MONITOR: 'Monitor or worse',
  URGENT: 'Urgent or worse',
  EMERGENCY: 'Emergency',
}

function Chips({ options, selected, onChange, format = (s) => s }: {
  options: string[]
  selected: string[]
  onChange: (next: string[]) => void
  format?: (s: string) => string
}) {
  if (options.length === 0) return <p className="text-[14px] text-faint">No values shared by enough patients yet.</p>
  return (
    <div className="flex flex-wrap gap-1.5">
      {options.map((o) => {
        const on = selected.includes(o)
        return (
          <button key={o} type="button" aria-pressed={on}
            onClick={() => onChange(on ? selected.filter((s) => s !== o) : [...selected, o])}
            className={`rounded-full px-3 py-1 text-[14px] ring-1 ${on ? 'bg-accent font-bold text-white ring-accent' : 'ring-line hover:ring-line-strong'}`}>
            {format(o)}
          </button>
        )
      })}
    </div>
  )
}

function Section({ title, hint, children }: { title: string; hint?: string; children: ReactNode }) {
  return (
    <fieldset className="border-b border-line py-4 last:border-0">
      <legend className="float-left mb-2 w-full font-bold">{title}</legend>
      {hint && <p className="clear-both mb-2 text-[13px] text-muted">{hint}</p>}
      <div className="clear-both">{children}</div>
    </fieldset>
  )
}

/** Human summary of a definition, for the saved list. */
export function describeCohort(d: CohortDefinition): string {
  const parts: string[] = []
  if (d.ageBands?.length) parts.push(`aged ${d.ageBands.join(', ')}`)
  if (d.chdStages?.length) parts.push(`CHD stage ${d.chdStages.join(' or ')}`)
  if (d.comorbidities?.length) parts.push(`${d.comorbidityMatch === 'ALL' ? 'all of' : 'any of'} ${d.comorbidities.join(', ')}`)
  if (d.languages?.length) parts.push(`language ${d.languages.join(' or ')}`)
  if (d.medicationName) parts.push(`on “${d.medicationName}”`)
  if (d.hadFlaggedVital) parts.push('had an out-of-range vital')
  if (d.minSymptomSeverity) parts.push(`check-in ${SEVERITY_LABEL[d.minSymptomSeverity].toLowerCase()}`)
  return parts.length ? parts.join('; ') : 'All patients'
}

function clean(d: CohortDefinition): CohortDefinition {
  const out: CohortDefinition = {}
  if (d.ageBands?.length) out.ageBands = d.ageBands
  if (d.chdStages?.length) out.chdStages = d.chdStages
  if (d.comorbidities?.length) {
    out.comorbidities = d.comorbidities
    out.comorbidityMatch = d.comorbidityMatch ?? 'ANY'
  }
  if (d.languages?.length) out.languages = d.languages
  if (d.medicationName?.trim()) out.medicationName = d.medicationName.trim()
  if (d.hadFlaggedVital) out.hadFlaggedVital = true
  if (d.minSymptomSeverity) out.minSymptomSeverity = d.minSymptomSeverity
  return out
}

function SizeReadout({ definition }: { definition: CohortDefinition }) {
  const [debounced, setDebounced] = useState(definition)
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(definition), 350)
    return () => window.clearTimeout(t)
  }, [definition])
  const { data, error, isFetching } = useQuery({
    queryKey: ['cohort-preview', debounced],
    queryFn: () => researchApi.previewCohort(debounced, {}),
  })
  return (
    <div className="graph-paper rounded-xl p-5 ring-1 ring-line" aria-live="polite">
      <div className="text-[14px] text-muted">Patients matching</div>
      {error ? (
        <p className="mt-2 text-alert">{error instanceof ApiError ? error.message : 'Couldn’t count.'}</p>
      ) : data?.suppressed ? (
        <div className="mt-1">
          <div className="text-[40px] leading-none font-bold text-faint">&lt; {data.k}</div>
          <p className="mt-2 text-[14px] text-muted">Too few to analyse. Results for this cohort will be hidden.</p>
        </div>
      ) : (
        <div className={`num mt-1 text-[40px] leading-none font-bold ${isFetching ? 'opacity-50' : ''}`}>{data?.size ?? '…'}</div>
      )}
    </div>
  )
}

export function Cohorts() {
  const qc = useQueryClient()
  const catalog = useCatalog()
  const cohorts = useCohorts()
  const [def, setDef] = useState<CohortDefinition>({})
  const [name, setName] = useState('')
  const set = (patch: Partial<CohortDefinition>) => setDef((d) => ({ ...d, ...patch }))

  const save = useMutation({
    mutationFn: () => researchApi.saveCohort(name.trim(), clean(def)),
    onSuccess: () => {
      setName('')
      qc.invalidateQueries({ queryKey: ['cohorts'] })
    },
  })
  const remove = useMutation({
    mutationFn: (id: string) => researchApi.deleteCohort(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['cohorts'] }),
  })

  const c = catalog.data
  if (catalog.error) return <ErrorNote error={catalog.error} />
  if (!c) return null
  const demo = c.datasets.includes('DEMOGRAPHICS')
  const f = c.cohortFields

  return (
    <>
      <PageHeader title="Cohorts">
        Describe a group of patients with filters, check how many match, and save it to use in any analysis. Filters only appear for data you have access to.
      </PageHeader>
      <div className="grid gap-8 lg:grid-cols-[1fr_20rem]">
        <div>
          <div className="rounded-xl bg-surface px-5 ring-1 ring-line">
            {demo && (
              <>
                <Section title="Age band">
                  <Chips options={f.ageBands} selected={def.ageBands ?? []} onChange={(v) => set({ ageBands: v })} />
                </Section>
                <Section title="CHD stage">
                  <Chips options={f.chdStages} selected={def.chdStages ?? []} onChange={(v) => set({ chdStages: v })} />
                </Section>
                <Section title="Other conditions" hint="Only conditions recorded for enough patients are listed.">
                  <Chips options={f.comorbidities} selected={def.comorbidities ?? []} onChange={(v) => set({ comorbidities: v })} />
                  {(def.comorbidities?.length ?? 0) > 1 && (
                    <div className="mt-2 flex gap-4 text-[14px]">
                      {(['ANY', 'ALL'] as const).map((m) => (
                        <label key={m} className="flex items-center gap-1.5">
                          <input type="radio" name="match" className="accent-[var(--accent)]" checked={(def.comorbidityMatch ?? 'ANY') === m}
                            onChange={() => set({ comorbidityMatch: m })} />
                          {m === 'ANY' ? 'Has any of these' : 'Has all of these'}
                        </label>
                      ))}
                    </div>
                  )}
                </Section>
                <Section title="App language">
                  <Chips options={f.languages} selected={def.languages ?? []} onChange={(v) => set({ languages: v })}
                    format={(l) => ({ en: 'English', am: 'Amharic' })[l] ?? l} />
                </Section>
              </>
            )}
            {c.datasets.includes('MEDICATIONS') && (
              <Section title="Medication" hint="Patients who have this medication (name contains the text).">
                <input list="meds" value={def.medicationName ?? ''} onChange={(e) => set({ medicationName: e.target.value })}
                  placeholder="e.g. atorvastatin" maxLength={100}
                  className="w-full max-w-sm rounded-md bg-surface px-3 py-2 ring-1 ring-line focus:ring-accent focus:outline-none" />
                <datalist id="meds">{f.medications.map((m) => <option key={m} value={m} />)}</datalist>
              </Section>
            )}
            {c.datasets.includes('VITALS') && (
              <Section title="Vitals">
                <label className="flex items-center gap-2">
                  <input type="checkbox" className="accent-[var(--accent)]" checked={def.hadFlaggedVital ?? false}
                    onChange={(e) => set({ hadFlaggedVital: e.target.checked || undefined })} />
                  Had at least one out-of-range reading
                </label>
              </Section>
            )}
            {c.datasets.includes('SYMPTOMS') && (
              <Section title="Symptom check-ins">
                <select value={def.minSymptomSeverity ?? ''} onChange={(e) => set({ minSymptomSeverity: (e.target.value || undefined) as Severity | undefined })}
                  className="rounded-md bg-surface px-2.5 py-1.5 ring-1 ring-line focus:ring-accent focus:outline-none">
                  <option value="">No filter</option>
                  {(['MONITOR', 'URGENT', 'EMERGENCY'] as Severity[]).map((s) => <option key={s} value={s}>At least one: {SEVERITY_LABEL[s].toLowerCase()}</option>)}
                </select>
              </Section>
            )}
          </div>
          <button type="button" onClick={() => setDef({})} className="mt-3 text-[14px] text-muted underline underline-offset-2 hover:text-ink">
            Clear all filters
          </button>
        </div>

        <aside className="space-y-5">
          <SizeReadout definition={clean(def)} />
          <form className="rounded-xl bg-surface p-4 ring-1 ring-line"
            onSubmit={(e) => { e.preventDefault(); save.mutate() }}>
            <label className="block">
              <span className="mb-1 block text-[14px] font-bold">Save as</span>
              <input value={name} onChange={(e) => setName(e.target.value)} required maxLength={120} placeholder="e.g. Stage C, over 60"
                className="w-full rounded-md bg-surface px-3 py-2 ring-1 ring-line focus:ring-accent focus:outline-none" />
            </label>
            <p className="mt-1 text-[13px] text-muted">{describeCohort(clean(def))}</p>
            <button type="submit" disabled={save.isPending || !name.trim()}
              className="mt-3 rounded-md bg-accent px-4 py-2 font-bold text-white hover:brightness-110 disabled:opacity-50">
              {save.isPending ? 'Saving…' : 'Save cohort'}
            </button>
            {save.error && <p className="mt-2 text-[14px] text-alert">{save.error instanceof ApiError ? save.error.message : 'Couldn’t save.'}</p>}
          </form>
        </aside>
      </div>

      <section className="mt-10">
        <h2 className="mb-3 text-[17px] font-bold">Saved cohorts</h2>
        {cohorts.data?.length ? (
          <ul className="divide-y divide-line rounded-xl bg-surface ring-1 ring-line">
            {cohorts.data.map((s: SavedCohort) => (
              <li key={s.id} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
                <div>
                  <div className="font-bold">{s.name}</div>
                  <div className="text-[14px] text-muted">{describeCohort(s.definition)}, saved {fmtDate(s.createdAt)}</div>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => setDef(s.definition)} className="rounded-md px-3 py-1.5 text-[14px] ring-1 ring-line hover:ring-line-strong">
                    Load filters
                  </button>
                  <button type="button" onClick={() => remove.mutate(s.id)} className="rounded-md px-3 py-1.5 text-[14px] text-alert ring-1 ring-line hover:ring-alert">
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-muted">No saved cohorts yet. Analyses use all patients until you save one.</p>
        )}
      </section>
    </>
  )
}
