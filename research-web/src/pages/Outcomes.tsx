import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { Bar, BarChart, Legend, ResponsiveContainer, Scatter, ScatterChart, Tooltip, XAxis, YAxis, ZAxis } from 'recharts'
import { researchApi, type CorrelationBody } from '../api/research'
import type { CorrelationResult, Period, Severity } from '../api/types'
import {
  ChoiceSelect, CohortSelect, cohortDefinition, Controls, ExportButton, fmt, MetricSelect, Panel, WindowFields, windowHint, Withheld,
} from '../components/Analysis'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtDayShort } from '../lib/format'
import { useCatalog, useCohorts } from '../lib/useCatalog'
import { useUrlState } from '../lib/useUrlState'

const TABS = [
  { id: 'adherence', label: 'Adherence and blood pressure', needs: ['MEDICATIONS', 'VITALS'] },
  { id: 'correlation', label: 'Correlation', needs: [] },
  { id: 'severity', label: 'Symptom severity', needs: ['SYMPTOMS'] },
] as const

const tooltipStyle = { background: 'var(--surface)', border: '1px solid var(--line-strong)', borderRadius: 8, color: 'var(--ink)' }

function useSharedControls() {
  const cohorts = useCohorts()
  const [cohortId, setCohortId] = useState('')
  const [range, setRange] = useState({ from: '', to: '' })
  return {
    cohortId, setCohortId, range, setRange,
    cohort: cohortDefinition(cohorts.data, cohortId),
    from: range.from || undefined, to: range.to || undefined,
  }
}

function Adherence() {
  const c = useSharedControls()
  const body = { cohort: c.cohort, from: c.from, to: c.to }
  const { data, error, isFetching } = useQuery({
    queryKey: ['adherence', body], queryFn: () => researchApi.adherence(body), placeholderData: keepPreviousData,
  })
  return (
    <>
      <Controls>
        <CohortSelect value={c.cohortId} onChange={c.setCohortId} />
        <WindowFields from={c.range.from} to={c.range.to} onChange={c.setRange} />
      </Controls>
      {error && <ErrorNote error={error} />}
      {data && (
        <div className={isFetching ? 'opacity-60' : ''}>
          <Panel title="Blood pressure by medication adherence" aside={<ExportButton path="analytics/adherence-outcomes" body={body} />}>
            <p className="mb-4 max-w-[72ch] text-[14px] text-muted">
              Patients are grouped by the share of their logged doses marked taken. Each group shows the average of each patient’s mean blood pressure
              {data.symptomsIncluded ? ', and how often their check-ins were assessed urgent or worse' : ''}.
            </p>
            <div className="overflow-x-auto">
              <table className="num w-full text-left">
                <thead>
                  <tr className="border-b border-line text-[13px] text-muted">
                    {['Adherence', 'Patients', 'Avg adherence', 'Systolic', 'Diastolic', 'BP readings out of range',
                      ...(data.symptomsIncluded ? ['Urgent check-ins'] : [])].map((h) => <th key={h} className="px-3 py-2 font-bold">{h}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {data.bands.map((b) => (
                    <tr key={b.band} className="border-b border-line last:border-0">
                      <td className="px-3 py-2.5 font-bold">{b.band}</td>
                      {b.suppressed ? (
                        <td colSpan={data.symptomsIncluded ? 6 : 5} className="withheld px-3 py-2.5"><Withheld k={data.k} inline /></td>
                      ) : b.patients === 0 ? (
                        <td colSpan={data.symptomsIncluded ? 6 : 5} className="px-3 py-2.5 text-faint">No patients</td>
                      ) : (
                        <>
                          <td className="px-3 py-2.5">{fmt(b.patients, 0)}</td>
                          <td className="px-3 py-2.5">{fmt(b.meanAdherence)}%</td>
                          <td className="px-3 py-2.5">{b.meanSystolic == null ? <Withheld k={data.k} inline /> : `${fmt(b.meanSystolic)} mmHg`}</td>
                          <td className="px-3 py-2.5">{b.meanDiastolic == null ? <Withheld k={data.k} inline /> : `${fmt(b.meanDiastolic)} mmHg`}</td>
                          <td className="px-3 py-2.5">{b.pctBpOutOfRange == null ? <Withheld k={data.k} inline /> : `${fmt(b.pctBpOutOfRange)}%`}</td>
                          {data.symptomsIncluded && (
                            <td className="px-3 py-2.5">{b.pctUrgentCheckins == null ? <Withheld k={data.k} inline /> : `${fmt(b.pctUrgentCheckins)}%`}</td>
                          )}
                        </>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Panel>
        </div>
      )}
    </>
  )
}

function strength(r: number) {
  const a = Math.abs(r)
  const s = a < 0.1 ? 'No meaningful' : a < 0.3 ? 'A weak' : a < 0.5 ? 'A moderate' : 'A strong'
  return `${s}${a >= 0.1 ? (r > 0 ? ' positive' : ' negative') : ''} relationship`
}

function HeatGrid({ result }: { result: CorrelationResult }) {
  const g = result.grid!
  const max = Math.max(1, ...g.counts.flat().map((c) => c ?? 0))
  return (
    <figure>
      <div className="flex gap-2">
        <div className="flex w-12 flex-col-reverse justify-between text-right text-[12px] text-muted">
          {g.yEdges.map((e, i) => <span key={i}>{fmt(e)}</span>)}
        </div>
        <div className="grid flex-1 grid-cols-5 grid-rows-5 gap-1" style={{ aspectRatio: '5 / 3' }}>
          {[...g.counts].reverse().map((row, yi) =>
            row.map((c, xi) => (
              <div key={`${yi}-${xi}`}
                title={c == null ? `Hidden: fewer than ${result.k} patients` : `${c} patients`}
                className={`num grid place-items-center rounded text-[13px] font-bold ${c == null ? 'withheld text-faint' : ''}`}
                style={c == null ? undefined : { background: `color-mix(in oklab, var(--accent) ${Math.round((c / max) * 85)}%, var(--surface))`, color: c / max > 0.5 ? '#fff' : 'var(--ink)' }}>
                {c == null ? '' : c}
              </div>
            )),
          )}
        </div>
      </div>
      <div className="mt-1 ml-14 flex justify-between text-[12px] text-muted">
        {g.xEdges.map((e, i) => <span key={i}>{fmt(e)}</span>)}
      </div>
      <figcaption className="mt-2 ml-14 text-[13px] text-muted">
        Patients per cell. Your access is aggregates-only, so individual points aren’t shown; the outer cells also hold values beyond the 5th–95th percentile.
      </figcaption>
    </figure>
  )
}

function Correlation() {
  const catalog = useCatalog()
  const metrics = catalog.data?.metrics ?? []
  const c = useSharedControls()
  const [x, setX] = useState('')
  const [y, setY] = useState('')
  const xId = x || metrics[0]?.id || ''
  const yId = y || metrics[1]?.id || metrics[0]?.id || ''
  const body: CorrelationBody = { metricX: xId, metricY: yId, cohort: c.cohort, from: c.from, to: c.to }
  const { data, error, isFetching } = useQuery({
    queryKey: ['correlation', body], queryFn: () => researchApi.correlation(body),
    enabled: Boolean(xId && yId), placeholderData: keepPreviousData,
  })

  return (
    <>
      <Controls>
        <MetricSelect label="Across (x)" metrics={metrics} value={xId} onChange={setX} />
        <MetricSelect label="Up (y)" metrics={metrics} value={yId} onChange={setY} />
        <CohortSelect value={c.cohortId} onChange={c.setCohortId} />
        <WindowFields from={c.range.from} to={c.range.to} onChange={c.setRange} />
      </Controls>
      {error && <ErrorNote error={error} />}
      {data && (
        <div className={isFetching ? 'opacity-60' : ''}>
          <Panel title={`${data.x.label} and ${data.y.label}`} aside={<ExportButton path="analytics/correlation" body={body} />}>
            <p className="mb-4 max-w-[72ch] text-[14px] text-muted">
              Each patient’s average of both measures over the period, for patients who have both.
            </p>
            {data.suppressed ? (
              <Withheld k={data.k} />
            ) : data.patients === 0 ? (
              <p className="text-muted">No patients have both measures in this period.</p>
            ) : (
              <div className="space-y-5">
                <div className="flex flex-wrap items-baseline gap-x-8 gap-y-2">
                  <div>
                    <div className="text-[13px] text-muted">Pearson r</div>
                    <div className="num text-[32px] leading-none font-bold">{data.r == null ? '—' : fmt(data.r, 2)}</div>
                  </div>
                  {data.ciLow != null && (
                    <div>
                      <div className="text-[13px] text-muted">95% confidence interval</div>
                      <div className="num text-[20px] font-bold">{fmt(data.ciLow, 2)} to {fmt(data.ciHigh, 2)}</div>
                    </div>
                  )}
                  <div>
                    <div className="text-[13px] text-muted">Patients</div>
                    <div className="num text-[20px] font-bold">{fmt(data.patients, 0)}</div>
                  </div>
                  {data.r != null && <p className="basis-full text-muted">{strength(data.r)}. Correlation doesn’t show that one causes the other.</p>}
                </div>
                {data.points && (
                  <div className="graph-paper h-80 rounded-lg p-2 ring-1 ring-line">
                    <ResponsiveContainer width="100%" height="100%">
                      <ScatterChart margin={{ top: 16, right: 24, bottom: 16, left: 8 }}>
                        <XAxis type="number" dataKey="x" name={data.x.label} unit={` ${data.x.unit}`} tick={{ fill: 'var(--muted)', fontSize: 12 }} domain={['auto', 'auto']} />
                        <YAxis type="number" dataKey="y" name={data.y.label} unit={` ${data.y.unit}`} tick={{ fill: 'var(--muted)', fontSize: 12 }} domain={['auto', 'auto']} width={70} />
                        <ZAxis dataKey="patient" name="Patient" />
                        <Tooltip contentStyle={tooltipStyle} />
                        <Scatter data={data.points} fill="var(--accent)" isAnimationActive={false} />
                      </ScatterChart>
                    </ResponsiveContainer>
                  </div>
                )}
                {data.grid && <HeatGrid result={data} />}
              </div>
            )}
          </Panel>
        </div>
      )}
    </>
  )
}

const SEVERITY_COLORS: Record<Severity, string> = {
  NONE: 'var(--line-strong)', MONITOR: 'var(--amber)', URGENT: 'var(--series-2)', EMERGENCY: 'var(--alert)',
}
const SEVERITY_LABEL: Record<Severity, string> = { NONE: 'No concern', MONITOR: 'Monitor', URGENT: 'Urgent', EMERGENCY: 'Emergency' }

function SeverityMix() {
  const c = useSharedControls()
  const [period, setPeriod] = useState<Period>('MONTH')
  const body = { period, cohort: c.cohort, from: c.from, to: c.to }
  const { data, error, isFetching } = useQuery({
    queryKey: ['severity', body], queryFn: () => researchApi.severity(body), placeholderData: keepPreviousData,
  })
  const rows = (data?.buckets ?? []).map((b) => {
    const row: Record<string, string | number | null> = { period: b.period, hidden: b.suppressed ? 1 : 0 }
    if (b.counts && b.checkins) {
      for (const s of Object.keys(SEVERITY_LABEL) as Severity[]) row[s] = Math.round((b.counts[s] / b.checkins) * 1000) / 10
    }
    return row
  })

  return (
    <>
      <Controls>
        <ChoiceSelect<Period> label="Per" value={period} onChange={setPeriod}
          options={[{ value: 'MONTH', label: 'Month' }, { value: 'WEEK', label: 'Week' }]} />
        <CohortSelect value={c.cohortId} onChange={c.setCohortId} />
        <WindowFields from={c.range.from} to={c.range.to} onChange={c.setRange} />
      </Controls>
      {error && <ErrorNote error={error} />}
      {data && (
        <div className={isFetching ? 'opacity-60' : ''}>
          <Panel title="Share of check-ins at each severity" aside={<ExportButton path="analytics/severity" body={body} />}>
            {rows.length === 0 ? (
              <p className="text-muted">No check-ins in this period.</p>
            ) : rows.every((r) => r.hidden) ? (
              <Withheld k={data.k} />
            ) : (
              <>
                <div className="graph-paper h-80 rounded-lg p-2 ring-1 ring-line">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={rows} margin={{ top: 16, right: 24, bottom: 4, left: 0 }}>
                      <XAxis dataKey="period" tickFormatter={(p) => fmtDayShort(String(p))} tick={{ fill: 'var(--muted)', fontSize: 12 }} tickLine={false} axisLine={false} />
                      <YAxis unit="%" domain={[0, 100]} tick={{ fill: 'var(--muted)', fontSize: 12 }} tickLine={false} axisLine={false} width={48} />
                      <Tooltip contentStyle={tooltipStyle} labelFormatter={(p) => fmtDayShort(String(p))} formatter={(v, n) => [`${v}%`, SEVERITY_LABEL[n as Severity] ?? n]} />
                      <Legend formatter={(n) => SEVERITY_LABEL[n as Severity] ?? n} />
                      {(Object.keys(SEVERITY_LABEL) as Severity[]).map((s) => (
                        <Bar key={s} dataKey={s} stackId="a" fill={SEVERITY_COLORS[s]} isAnimationActive={false} />
                      ))}
                    </BarChart>
                  </ResponsiveContainer>
                </div>
                {rows.some((r) => r.hidden) && <p className="mt-2 text-[13px] text-muted">Empty periods had fewer than {data.k} patients and are hidden.</p>}
              </>
            )}
          </Panel>
        </div>
      )}
    </>
  )
}

export function Outcomes() {
  const catalog = useCatalog()
  const url = useUrlState()
  const granted = catalog.data?.datasets ?? []
  const tabs = TABS.filter((t) => t.needs.every((d) => granted.includes(d)))
  const tab = tabs.find((t) => t.id === url.get('tab'))?.id ?? tabs[0]?.id

  return (
    <>
      <PageHeader title="Outcomes">
        Relationships between behaviour and health: whether taking medication tracks with blood pressure, how two measures move together, and how serious symptoms are over time.
      </PageHeader>
      {windowHint(catalog.data)}
      <div role="tablist" aria-label="Outcome analyses" className="mb-5 flex gap-1 overflow-x-auto border-b border-line">
        {tabs.map((t) => (
          <button key={t.id} role="tab" type="button" aria-selected={tab === t.id} onClick={() => url.set({ tab: t.id })}
            className={`-mb-px border-b-2 px-3 py-2.5 whitespace-nowrap ${tab === t.id ? 'border-accent font-bold text-ink' : 'border-transparent text-muted hover:text-ink'}`}>
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel">
        {tab === 'adherence' && <Adherence />}
        {tab === 'correlation' && <Correlation />}
        {tab === 'severity' && <SeverityMix />}
        {!tab && catalog.data && <p className="text-muted">Your access doesn’t include the data these analyses need.</p>}
      </div>
    </>
  )
}
