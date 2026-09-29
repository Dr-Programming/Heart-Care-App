import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { researchApi, type TrendBody } from '../api/research'
import type { Period } from '../api/types'
import {
  ChoiceSelect, CohortSelect, cohortDefinition, cohortName, Controls, ExportButton, fmt, MetricSelect, Panel,
  WindowFields, windowHint, Withheld,
} from '../components/Analysis'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtDayShort } from '../lib/format'
import { useCatalog, useCohorts } from '../lib/useCatalog'

const COLORS = ['var(--series-1)', 'var(--series-2)', 'var(--series-3)']
const month = new Intl.DateTimeFormat(undefined, { month: 'short', year: 'numeric' })

export function Trends() {
  const catalog = useCatalog()
  const cohorts = useCohorts()
  const metrics = catalog.data?.metrics ?? []
  const [metric, setMetric] = useState('')
  const [period, setPeriod] = useState<Period>('MONTH')
  const [picked, setPicked] = useState<string[]>([''])
  const [range, setRange] = useState({ from: '', to: '' })
  const metricId = metric || metrics[0]?.id || ''

  const body: TrendBody = {
    metric: metricId, period, from: range.from || undefined, to: range.to || undefined,
    cohorts: picked.map((id) => ({ label: cohortName(cohorts.data, id), definition: cohortDefinition(cohorts.data, id) ?? {} })),
  }
  const { data, error, isFetching } = useQuery({
    queryKey: ['trend', body],
    queryFn: () => researchApi.trend(body),
    enabled: Boolean(metricId),
    placeholderData: keepPreviousData,
  })

  // One row per period, one column per series; suppressed points become gaps in the line.
  const periods = [...new Set(data?.series.flatMap((s) => s.points.map((p) => p.period)) ?? [])].sort()
  const rows = periods.map((p) => {
    const row: Record<string, string | number | null> = { period: p }
    data?.series.forEach((s, i) => {
      const pt = s.points.find((x) => x.period === p)
      row[`s${i}`] = pt && !pt.suppressed ? pt.mean : null
    })
    return row
  })
  const label = (p: string) => (period === 'MONTH' ? month.format(new Date(`${p}T00:00`)) : `Week of ${fmtDayShort(p)}`)
  const anyHidden = data?.series.some((s) => s.points.some((p) => p.suppressed))

  return (
    <>
      <PageHeader title="Trends">
        Average of a measure per week or month, or a rate such as the share of readings out of range. Compare up to three cohorts on one chart.
      </PageHeader>
      {windowHint(catalog.data)}
      <Controls>
        <MetricSelect metrics={metrics} value={metricId} onChange={setMetric} />
        <ChoiceSelect<Period> label="Per" value={period} onChange={setPeriod}
          options={[{ value: 'MONTH', label: 'Month' }, { value: 'WEEK', label: 'Week' }]} />
        <WindowFields from={range.from} to={range.to} onChange={setRange} />
      </Controls>
      <div className="mb-5 flex flex-wrap items-end gap-3">
        {picked.map((id, i) => (
          <div key={i} className="flex items-end gap-1">
            <span aria-hidden className="mb-2.5 size-3 rounded-full" style={{ background: COLORS[i] }} />
            <CohortSelect label={`Series ${i + 1}`} value={id} onChange={(v) => setPicked(picked.map((x, j) => (j === i ? v : x)))} />
            {picked.length > 1 && (
              <button type="button" onClick={() => setPicked(picked.filter((_, j) => j !== i))} aria-label={`Remove series ${i + 1}`}
                className="mb-0.5 rounded-md px-2 py-1.5 text-muted ring-1 ring-line hover:text-ink">Remove</button>
            )}
          </div>
        ))}
        {picked.length < 3 && (
          <button type="button" onClick={() => setPicked([...picked, ''])} className="rounded-md px-3 py-1.5 text-[14px] font-bold text-accent ring-1 ring-line hover:ring-accent">
            Compare another cohort
          </button>
        )}
      </div>
      {error && <ErrorNote error={error} />}
      {data && (
        <div className={isFetching ? 'opacity-60' : ''}>
          <Panel title={`${data.metric.label} (${data.metric.unit})`} aside={<ExportButton path="analytics/trend" body={body} />}>
            {rows.length === 0 ? (
              <p className="text-muted">No readings in this period.</p>
            ) : rows.every((r) => data.series.every((_, i) => r[`s${i}`] == null)) ? (
              <Withheld k={data.k} />
            ) : (
              <>
                <div className="graph-paper h-80 rounded-lg p-2 ring-1 ring-line">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={rows} margin={{ top: 16, right: 24, bottom: 4, left: 0 }}>
                      <CartesianGrid stroke="transparent" />
                      <XAxis dataKey="period" tickFormatter={label} tick={{ fill: 'var(--muted)', fontSize: 12 }} tickLine={false} axisLine={false} />
                      <YAxis tick={{ fill: 'var(--muted)', fontSize: 12 }} tickLine={false} axisLine={false} width={44} />
                      <Tooltip labelFormatter={(p) => label(String(p))}
                        contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line-strong)', borderRadius: 8, color: 'var(--ink)' }}
                        formatter={(v) => (v == null ? 'Hidden' : `${fmt(Number(v))} ${data.metric.unit}`)} />
                      <Legend />
                      {data.series.map((s, i) => (
                        <Line key={i} type="monotone" dataKey={`s${i}`} name={s.label} stroke={COLORS[i]} strokeWidth={2.25}
                          dot={{ r: 3.5, fill: COLORS[i] }} connectNulls={false} isAnimationActive={false} />
                      ))}
                    </LineChart>
                  </ResponsiveContainer>
                </div>
                {anyHidden && <p className="mt-2 text-[13px] text-muted">Gaps are periods with fewer than {data.k} patients, hidden to protect privacy.</p>}
              </>
            )}
          </Panel>
        </div>
      )}
    </>
  )
}
