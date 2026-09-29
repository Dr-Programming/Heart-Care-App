import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { Navigate } from 'react-router'
import { researchApi } from '../api/research'
import type { Dataset } from '../api/types'
import { ChoiceSelect, CohortSelect, cohortDefinition, Controls, ExportButton, Panel, WindowFields, windowHint } from '../components/Analysis'
import { ErrorNote, Pager } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtLocalDate, humanize, humanizeEnum } from '../lib/format'
import { useCatalog, useCohorts } from '../lib/useCatalog'

const DATASET_LABEL: Record<Dataset, string> = {
  VITALS: 'Vitals',
  SYMPTOMS: 'Symptom check-ins',
  ACTIVITY: 'Activity',
  MEDICATIONS: 'Doses',
  DEMOGRAPHICS: 'Demographics',
}

function render(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  if (Array.isArray(value)) return value.length ? value.map(render).join(', ') : '—'
  if (typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>).map(([k, v]) => `${humanize(k)} ${render(v)}`).join(', ')
  }
  const s = String(value)
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return fmtLocalDate(s)
  return /^[A-Z][A-Z_]+$/.test(s) ? humanizeEnum(s) : s
}

export function Records() {
  const catalog = useCatalog()
  const cohorts = useCohorts()
  const granted = catalog.data?.datasets ?? []
  const [dataset, setDataset] = useState<Dataset | ''>('')
  const [cohortId, setCohortId] = useState('')
  const [range, setRange] = useState({ from: '', to: '' })
  const [page, setPage] = useState(0)
  const ds = (dataset || granted[0]) as Dataset | undefined

  const body = { cohort: cohortDefinition(cohorts.data, cohortId), from: range.from || undefined, to: range.to || undefined }
  const { data, error, isFetching } = useQuery({
    queryKey: ['records', ds, body, page],
    queryFn: () => researchApi.records(ds!, { ...body, page, size: 25 }),
    enabled: Boolean(ds),
    placeholderData: keepPreviousData,
  })

  if (catalog.data && catalog.data.accessLevel !== 'PSEUDONYMOUS') return <Navigate to="/" replace />

  return (
    <>
      <PageHeader title="Records">
        Individual records, with each patient shown as a code only you see. Codes stay the same across your sessions, so you can follow one patient over time without knowing who they are.
      </PageHeader>
      {windowHint(catalog.data)}
      <Controls>
        <ChoiceSelect<Dataset> label="Dataset" value={ds ?? 'VITALS'}
          onChange={(v) => { setDataset(v); setPage(0) }}
          options={granted.map((d) => ({ value: d, label: DATASET_LABEL[d] }))} />
        <CohortSelect value={cohortId} onChange={(v) => { setCohortId(v); setPage(0) }} />
        {ds !== 'DEMOGRAPHICS' && <WindowFields from={range.from} to={range.to} onChange={(r) => { setRange(r); setPage(0) }} />}
      </Controls>
      {error && <ErrorNote error={error} />}
      {data && ds && (
        <div className={isFetching ? 'opacity-60' : ''}>
          <Panel title={DATASET_LABEL[ds]} aside={<ExportButton path={`records/${ds.toLowerCase()}`} body={body} />}>
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-line text-[13px] text-muted">
                    {data.columns.map((c) => <th key={c} className="px-3 py-2 font-bold whitespace-nowrap">{humanize(c)}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {data.rows.map((row, i) => (
                    <tr key={i} className="border-b border-line align-top last:border-0">
                      {data.columns.map((c) => (
                        <td key={c} className={`px-3 py-2 ${c === 'patient' ? 'num font-bold whitespace-nowrap text-accent' : ''}`}>
                          {render(row[c])}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
              {data.rows.length === 0 && <p className="py-8 text-center text-muted">No records for this selection.</p>}
            </div>
          </Panel>
          <Pager page={data.page} totalPages={data.totalPages} totalElements={data.totalElements} onPage={setPage} noun="records" />
        </div>
      )}
    </>
  )
}
