import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { researchApi, type DescribeBody } from '../api/research'
import type { Bin, GroupBy, Stats, Unit } from '../api/types'
import {
  ChoiceSelect, CohortSelect, cohortDefinition, cohortName, Controls, ExportButton, fmt, MetricSelect, Panel,
  WindowFields, windowHint, Withheld,
} from '../components/Analysis'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { useCatalog, useCohorts } from '../lib/useCatalog'

function StatStrip({ s, unit }: { s: Stats; unit: string }) {
  const items: [string, string][] = [
    ['Patients', fmt(s.patients, 0)],
    ['Readings', fmt(s.readings, 0)],
    ['Mean', `${fmt(s.mean)} ${unit}`],
    ['Median', `${fmt(s.median)} ${unit}`],
    ['Standard deviation', fmt(s.sd)],
    ['Middle half (p25–p75)', `${fmt(s.p25)} – ${fmt(s.p75)}`],
    ['Central 90% (p5–p95)', `${fmt(s.p5)} – ${fmt(s.p95)}`],
  ]
  return (
    <dl className="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-4 lg:grid-cols-7">
      {items.map(([label, value]) => (
        <div key={label}>
          <dt className="text-[13px] text-muted">{label}</dt>
          <dd className="num mt-0.5 text-[20px] leading-tight font-bold">{value}</dd>
        </div>
      ))}
    </dl>
  )
}

/**
 * Drawn by hand rather than with a chart library so withheld bins can be shown as what they
 * are (hatched, "hidden") rather than as zero-height bars that would read as "none".
 */
function Histogram({ bins, k, unit }: { bins: Bin[]; k: number; unit: string }) {
  const max = Math.max(1, ...bins.map((b) => b.count ?? 0))
  return (
    <figure>
      <div className="graph-paper flex h-56 items-end gap-1 rounded-lg p-3 ring-1 ring-line" role="img"
        aria-label={`Distribution across ${bins.length} bins`}>
        {bins.map((b, i) => {
          const label = `${i === 0 ? '≤ ' : ''}${fmt(b.lo)}–${i === bins.length - 1 ? '≥ ' : ''}${fmt(b.hi)} ${unit}`
          return b.suppressed ? (
            <div key={i} title={`${label}: hidden, fewer than ${k} patients`} className="withheld h-full flex-1 rounded-t-sm opacity-70" />
          ) : (
            <div key={i} title={`${label}: ${b.count}`} className="flex-1 rounded-t-sm bg-accent"
              style={{ height: b.count ? `${(b.count / max) * 100}%` : '2px', opacity: b.count ? 1 : 0.25 }} />
          )
        })}
      </div>
      <figcaption className="num mt-2 flex justify-between text-[12px] text-muted">
        <span>≤ {fmt(bins[0]?.lo)}</span>
        <span>{unit}</span>
        <span>≥ {fmt(bins.at(-1)?.hi)}</span>
      </figcaption>
    </figure>
  )
}

export function Explore() {
  const catalog = useCatalog()
  const cohorts = useCohorts()
  const metrics = catalog.data?.metrics ?? []
  const [metric, setMetric] = useState('')
  const [cohortId, setCohortId] = useState('')
  const [unit, setUnit] = useState<Unit>('READING')
  const [groupBy, setGroupBy] = useState<GroupBy>('NONE')
  const [range, setRange] = useState({ from: '', to: '' })
  const metricId = metric || metrics[0]?.id || ''

  const body: DescribeBody = {
    metric: metricId, cohort: cohortDefinition(cohorts.data, cohortId), unit, groupBy,
    from: range.from || undefined, to: range.to || undefined,
  }
  const { data, error, isFetching } = useQuery({
    queryKey: ['describe', body],
    queryFn: () => researchApi.describe(body),
    enabled: Boolean(metricId),
    placeholderData: keepPreviousData,
  })
  const demo = catalog.data?.datasets.includes('DEMOGRAPHICS')

  return (
    <>
      <PageHeader title="Explore a measure">
        How a measure is distributed: its average, spread and shape. Count every reading, or average each patient first so frequent loggers don’t dominate.
      </PageHeader>
      {windowHint(catalog.data)}
      <Controls>
        <MetricSelect metrics={metrics} value={metricId} onChange={setMetric} />
        <CohortSelect value={cohortId} onChange={setCohortId} />
        <ChoiceSelect<Unit> label="Count" value={unit} onChange={setUnit}
          options={[{ value: 'READING', label: 'Every reading' }, { value: 'PATIENT', label: 'One average per patient' }]} />
        {demo && (
          <ChoiceSelect<GroupBy> label="Split by" value={groupBy} onChange={setGroupBy}
            options={[{ value: 'NONE', label: 'No split' }, { value: 'AGE_BAND', label: 'Age band' },
              { value: 'CHD_STAGE', label: 'CHD stage' }, { value: 'LANGUAGE', label: 'Language' }]} />
        )}
        <WindowFields from={range.from} to={range.to} onChange={setRange} />
      </Controls>
      {metrics.length === 0 && catalog.data && <p className="text-muted">Your access doesn’t include any measurable data yet.</p>}
      {error && <ErrorNote error={error} />}
      {data && (
        <div className={`space-y-6 ${isFetching ? 'opacity-60' : ''}`}>
          <Panel title={`${data.metric.label}, ${cohortId ? cohortName(cohorts.data, cohortId) : 'all patients'}`}
            aside={<ExportButton path="analytics/describe" body={body} />}>
            {data.overall.suppressed ? (
              <Withheld k={data.k} />
            ) : data.overall.patients === 0 ? (
              <p className="text-muted">No readings match. Try a wider cohort or date range.</p>
            ) : (
              <div className="space-y-6">
                <StatStrip s={data.overall} unit={data.metric.unit} />
                {data.histogram.length > 0 && <Histogram bins={data.histogram} k={data.k} unit={data.metric.unit} />}
              </div>
            )}
          </Panel>
          {data.groups.length > 0 && (
            <Panel title="By group">
              <div className="overflow-x-auto">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-line text-[13px] text-muted">
                      {['Group', 'Patients', 'Readings', 'Mean', 'Median', 'SD', 'p25–p75'].map((h) => <th key={h} className="px-3 py-2 font-bold">{h}</th>)}
                    </tr>
                  </thead>
                  <tbody>
                    {data.groups.map((g) => (
                      <tr key={g.group} className="num border-b border-line last:border-0">
                        <td className="px-3 py-2 font-bold">{g.group}</td>
                        {g.stats.suppressed ? (
                          <td colSpan={6} className="px-3 py-2"><Withheld k={data.k} inline /></td>
                        ) : (
                          <>
                            <td className="px-3 py-2">{fmt(g.stats.patients, 0)}</td>
                            <td className="px-3 py-2">{fmt(g.stats.readings, 0)}</td>
                            <td className="px-3 py-2">{fmt(g.stats.mean)}</td>
                            <td className="px-3 py-2">{fmt(g.stats.median)}</td>
                            <td className="px-3 py-2">{fmt(g.stats.sd)}</td>
                            <td className="px-3 py-2">{fmt(g.stats.p25)}–{fmt(g.stats.p75)}</td>
                          </>
                        )}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>
          )}
        </div>
      )}
    </>
  )
}
