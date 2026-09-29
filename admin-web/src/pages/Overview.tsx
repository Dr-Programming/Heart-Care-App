import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { adminApi } from '../api/admin'
import type { DayCount, Stats } from '../api/types'
import { ErrorNote } from '../components/Controls'
import { PageHeader } from '../components/Layout'
import { fmtDayShort, fmtNumber } from '../lib/format'

/**
 * The page's one loud element: a month of logging activity drawn as a rhythm strip on ECG
 * paper. The line is stepped so each day reads as a beat, not a smoothed trend.
 */
function RhythmStrip({ data }: { data: DayCount[] }) {
  const total = data.reduce((sum, d) => sum + d.count, 0)
  const today = data.at(-1)?.count ?? 0
  return (
    <section aria-labelledby="strip-title" className="ecg-paper overflow-hidden rounded-xl ring-1 ring-line-strong">
      <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-1 px-5 pt-5">
        <h2 id="strip-title" className="text-[17px] font-bold">
          Records logged by patients, last 30 days
        </h2>
        <p className="num text-muted">
          <span className="text-[22px] font-bold text-ink">{fmtNumber(total)}</span> in total,{' '}
          <span className="font-bold text-ink">{fmtNumber(today)}</span> today
        </p>
      </div>
      <div className="trace-draw h-56 px-1 pb-2" role="img" aria-label={`Daily records logged over 30 days, ${total} in total`}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 20, right: 20, bottom: 0, left: 0 }}>
            <XAxis
              dataKey="day"
              tickFormatter={fmtDayShort}
              interval={6}
              tickLine={false}
              axisLine={false}
              tick={{ fill: 'var(--muted)', fontSize: 12 }}
            />
            <YAxis allowDecimals={false} width={36} tickLine={false} axisLine={false} tick={{ fill: 'var(--muted)', fontSize: 12 }} />
            <Tooltip
              cursor={{ stroke: 'var(--line-strong)' }}
              contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line-strong)', borderRadius: 8, color: 'var(--ink)' }}
              labelFormatter={(d) => fmtDayShort(String(d))}
              formatter={(v) => [`${v} records`, '']}
              separator=""
            />
            <Line
              type="step"
              dataKey="count"
              stroke="var(--heart)"
              strokeWidth={2.25}
              dot={false}
              activeDot={{ r: 4, fill: 'var(--heart)', stroke: 'var(--surface)', strokeWidth: 2 }}
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </section>
  )
}

function Figure({ value, label, to, alert }: { value: number; label: string; to?: string; alert?: boolean }) {
  const body = (
    <>
      <div className={`num text-[30px] leading-none font-bold ${alert && value > 0 ? 'text-heart' : ''}`}>{fmtNumber(value)}</div>
      <div className="mt-1.5 text-[14px] text-muted">{label}</div>
    </>
  )
  return to ? (
    <Link to={to} className="block rounded-md py-1 hover:[&>div:last-child]:text-ink">
      {body}
    </Link>
  ) : (
    <div className="py-1">{body}</div>
  )
}

function TableCounts({ totals }: { totals: Stats['totals'] }) {
  const rows: [string, number][] = [
    ['Patients', totals.users],
    ['Patient profiles', totals.patientProfiles],
    ['Medications', totals.medications],
    ['Dose logs', totals.doseLogs],
    ['Vital readings', totals.vitals],
    ['Symptom check-ins', totals.symptoms],
    ['Activities', totals.activities],
  ]
  return (
    <section aria-labelledby="tables-title">
      <h2 id="tables-title" className="mb-2 text-[17px] font-bold">
        What’s in the database
      </h2>
      <dl className="rounded-lg bg-surface ring-1 ring-line">
        {rows.map(([label, n]) => (
          <div key={label} className="flex justify-between border-b border-line px-4 py-2.5 last:border-0">
            <dt className="text-muted">{label}</dt>
            <dd className="num font-bold">{fmtNumber(n)}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}

function Signups({ data }: { data: DayCount[] }) {
  const max = Math.max(1, ...data.map((d) => d.count))
  return (
    <section aria-labelledby="signups-title">
      <h2 id="signups-title" className="mb-2 text-[17px] font-bold">
        New patients per day
      </h2>
      <div className="rounded-lg bg-surface p-4 ring-1 ring-line">
        <div className="flex h-32 items-end gap-[3px]" role="img" aria-label="New patient sign-ups per day for the last 30 days">
          {data.map((d) => (
            <div
              key={d.day}
              title={`${fmtDayShort(d.day)}: ${d.count}`}
              className={`flex-1 rounded-t-sm ${d.count ? 'bg-calm' : 'bg-line'}`}
              style={{ height: d.count ? `${(d.count / max) * 100}%` : '2px' }}
            />
          ))}
        </div>
        <div className="mt-2 flex justify-between text-[12px] text-muted">
          <span>{data[0] && fmtDayShort(data[0].day)}</span>
          <span>Today</span>
        </div>
      </div>
    </section>
  )
}

export function Overview() {
  const { data, error, isPending } = useQuery({ queryKey: ['stats'], queryFn: adminApi.stats, staleTime: 60_000 })

  return (
    <>
      <PageHeader title="Overview">How patients are using the app, and which readings need a second look.</PageHeader>
      {error && <ErrorNote error={error} />}
      {isPending && <div className="ecg-paper h-72 animate-pulse rounded-xl ring-1 ring-line" />}
      {data && (
        <div className="space-y-8">
          <RhythmStrip data={data.recordsPerDay} />

          <div className="grid grid-cols-2 gap-x-6 gap-y-4 border-y border-line py-5 sm:grid-cols-3 lg:grid-cols-5">
            <Figure value={data.totals.users} label="Patients registered" to="/patients" />
            <Figure value={data.newUsersLast7Days} label="Joined in the last 7 days" />
            <Figure value={data.flaggedVitals} label="Vitals out of range" to="/flagged-vitals" alert />
            <Figure value={data.urgentSymptoms} label="Urgent or emergency check-ins" to="/urgent-symptoms" alert />
            <Figure value={data.lockedAccounts} label="Accounts locked after failed PINs" />
          </div>

          <div className="grid gap-8 lg:grid-cols-2">
            <Signups data={data.signupsPerDay} />
            <TableCounts totals={data.totals} />
          </div>
        </div>
      )}
    </>
  )
}
