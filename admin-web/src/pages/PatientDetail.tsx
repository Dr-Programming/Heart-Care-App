import { keepPreviousData, useQuery } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { Link, useParams } from 'react-router'
import { adminApi } from '../api/admin'
import type { DoseStatus, Medication, Severity, UserDetail, VitalType } from '../api/types'
import { Badge } from '../components/Badge'
import { DateRange, ErrorNote, FilterBar, Pager, Select } from '../components/Controls'
import { DataTable, type Column } from '../components/DataTable'
import { activityColumns, doseColumns, symptomColumns, vitalColumns } from '../components/recordColumns'
import { fmtDate, fmtDateTime, FREQUENCY_LABEL, humanize, LANGUAGE_LABEL, VITAL_LABEL } from '../lib/format'
import { useUrlState } from '../lib/useUrlState'

const TABS = [
  { id: 'profile', label: 'Profile' },
  { id: 'medications', label: 'Medications' },
  { id: 'doses', label: 'Dose history' },
  { id: 'vitals', label: 'Vitals' },
  { id: 'symptoms', label: 'Symptom check-ins' },
  { id: 'activity', label: 'Activity' },
] as const
type TabId = (typeof TABS)[number]['id']

const PAGE_SIZE = 20

function Header({ user }: { user: UserDetail }) {
  const locked = user.lockedUntil && new Date(user.lockedUntil) > new Date()
  return (
    <header className="mb-6">
      <Link to="/patients" className="text-[14px] text-muted underline underline-offset-2 hover:text-ink">
        All patients
      </Link>
      <div className="mt-2 flex flex-wrap items-center gap-3">
        <h1 className="text-[28px] leading-tight font-bold tracking-[-0.01em]">{user.name}</h1>
        {locked && <Badge tone="amber">Locked until {fmtDateTime(user.lockedUntil)}</Badge>}
      </div>
      <dl className="mt-3 flex flex-wrap gap-x-8 gap-y-2 text-[14px]">
        <Fact label="Phone">
          <span className="num">{user.phone}</span>
        </Fact>
        <Fact label="App language">{LANGUAGE_LABEL[user.preferredLanguage] ?? user.preferredLanguage}</Fact>
        <Fact label="Joined">{fmtDate(user.createdAt)}</Fact>
        {user.failedLoginAttempts > 0 && <Fact label="Failed PIN attempts">{user.failedLoginAttempts}</Fact>}
      </dl>
    </header>
  )
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-muted">{label}</dt>
      <dd className="font-bold">{children}</dd>
    </div>
  )
}

function Tabs({ user, active, onChange }: { user: UserDetail; active: TabId; onChange: (t: TabId) => void }) {
  const counts: Partial<Record<TabId, number>> = {
    medications: user.counts.medications,
    doses: user.counts.doseLogs,
    vitals: user.counts.vitals,
    symptoms: user.counts.symptoms,
    activity: user.counts.activities,
  }
  return (
    <div role="tablist" aria-label="Patient record" className="mb-5 flex gap-1 overflow-x-auto border-b border-line">
      {TABS.map((t) => (
        <button
          key={t.id}
          role="tab"
          type="button"
          aria-selected={active === t.id}
          onClick={() => onChange(t.id)}
          className={`-mb-px flex items-center gap-2 border-b-2 px-3 py-2.5 whitespace-nowrap ${
            active === t.id ? 'border-heart font-bold text-ink' : 'border-transparent text-muted hover:text-ink'
          }`}
        >
          {t.label}
          {counts[t.id] !== undefined && <span className="num text-[13px] text-faint">{counts[t.id]}</span>}
        </button>
      ))}
    </div>
  )
}

function ProfileTab({ user }: { user: UserDetail }) {
  const p = user.profile
  if (!p) {
    return <p className="rounded-lg bg-surface px-4 py-8 text-center text-muted ring-1 ring-line">This patient hasn’t filled in their health profile yet.</p>
  }
  const age = p.birthYear ? new Date().getFullYear() - p.birthYear : null
  const goals = p.goals
  const goalRows: [string, string | null][] = goals
    ? [
        ['Blood pressure', goals.bpSystolic && goals.bpDiastolic ? `${goals.bpSystolic}/${goals.bpDiastolic} mmHg` : null],
        ['Total cholesterol', goals.totalCholesterol != null ? `${goals.totalCholesterol} mmol/L` : null],
        ['Steps per day', goals.stepsPerDay != null ? goals.stepsPerDay.toLocaleString() : null],
        ['Target weight', goals.targetWeightKg != null ? `${goals.targetWeightKg} kg` : null],
        ['Diet', goals.dietNote],
      ]
    : []

  return (
    <div className="grid gap-8 lg:grid-cols-2">
      <section>
        <h2 className="mb-2 text-[17px] font-bold">Clinical background</h2>
        <dl className="rounded-lg bg-surface ring-1 ring-line">
          <Row label="Age">{age != null ? `${age} (born ${p.birthYear})` : null}</Row>
          <Row label="Height">{p.heightCm ? `${p.heightCm} cm` : null}</Row>
          <Row label="CHD stage">{p.chdStage}</Row>
          <Row label="Other conditions">
            {p.comorbidities.length ? (
              <span className="flex flex-wrap justify-end gap-1.5">
                {p.comorbidities.map((c) => (
                  <Badge key={c}>{humanize(c)}</Badge>
                ))}
              </span>
            ) : null}
          </Row>
          <Row label="Disease history" block>
            {p.diseaseHistory}
          </Row>
          <Row label="Management plan" block>
            {p.managementPlan}
          </Row>
        </dl>
      </section>
      <section>
        <h2 className="mb-2 text-[17px] font-bold">Goals</h2>
        <dl className="rounded-lg bg-surface ring-1 ring-line">
          {goalRows.length ? goalRows.map(([k, v]) => <Row key={k} label={k}>{v}</Row>) : <Row label="Goals">{null}</Row>}
        </dl>
        <p className="mt-2 text-[13px] text-muted">Profile last updated {fmtDateTime(p.updatedAt)}.</p>
      </section>
    </div>
  )
}

function Row({ label, children, block }: { label: string; children: ReactNode; block?: boolean }) {
  const empty = children === null || children === undefined || children === ''
  return (
    <div className={`border-b border-line px-4 py-2.5 last:border-0 ${block ? '' : 'flex justify-between gap-6'}`}>
      <dt className="text-muted">{label}</dt>
      <dd className={`${block ? 'mt-1 max-w-[70ch] whitespace-pre-line' : 'text-right font-bold'} ${empty ? 'font-normal text-faint' : ''}`}>
        {empty ? 'Not recorded' : children}
      </dd>
    </div>
  )
}

const medColumns: Column<Medication>[] = [
  {
    id: 'name',
    header: 'Medication',
    cell: ({ row }) => (
      <div>
        <div className="font-bold">{row.original.name}</div>
        <div className="num text-[13px] text-muted">{row.original.doseMg} mg</div>
      </div>
    ),
  },
  {
    id: 'schedule',
    header: 'Schedule',
    cell: ({ row }) => (
      <div>
        <div>{FREQUENCY_LABEL[row.original.frequency]}</div>
        <div className="num text-[13px] text-muted">{row.original.scheduleTimes.join(', ') || 'No set times'}</div>
      </div>
    ),
  },
  {
    id: 'adherence',
    header: 'Adherence',
    cell: ({ row }) => {
      const { taken, missed, skipped } = row.original
      const total = taken + missed + skipped
      if (!total) return <span className="text-faint">No doses logged</span>
      const pct = (n: number) => `${(n / total) * 100}%`
      return (
        <div className="min-w-44">
          <div className="flex h-2 overflow-hidden rounded-full bg-line" aria-hidden>
            <div className="bg-calm" style={{ width: pct(taken) }} />
            <div className="bg-amber" style={{ width: pct(skipped) }} />
            <div className="bg-heart" style={{ width: pct(missed) }} />
          </div>
          <div className="num mt-1 text-[13px] text-muted">
            <span className="font-bold text-ink">{Math.round((taken / total) * 100)}% taken</span>, {missed} missed, {skipped} skipped
          </div>
        </div>
      )
    },
  },
  {
    id: 'active',
    header: 'Status',
    cell: ({ row }) => (row.original.active ? <Badge tone="calm">Current</Badge> : <Badge>Stopped</Badge>),
  },
  { id: 'since', header: 'Added', cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDate(row.original.createdAt)}</span> },
]

function MedicationsTab({ userId }: { userId: string }) {
  const { data, error, isPending } = useQuery({ queryKey: ['meds', userId], queryFn: () => adminApi.medications(userId) })
  if (error) return <ErrorNote error={error} />
  return <DataTable columns={medColumns} rows={data} loading={isPending} empty="No medications added in the app." />
}

function useListQuery<T>(key: string, userId: string, fetcher: (page: number, sort?: string) => Promise<import('../api/types').Page<T>>, filters: unknown[]) {
  const url = useUrlState()
  const sort = url.get('sort') || undefined
  const query = useQuery({
    queryKey: [key, userId, url.page, sort, ...filters],
    queryFn: () => fetcher(url.page, sort),
    placeholderData: keepPreviousData,
  })
  return { ...query, url, sort }
}

function DosesTab({ userId }: { userId: string }) {
  const url = useUrlState()
  const status = url.get('status') as DoseStatus | ''
  const from = url.get('from')
  const to = url.get('to')
  const q = useListQuery('doses', userId, (page, sort) =>
    adminApi.doseLogs(userId, { page, size: PAGE_SIZE, sort, status: status || undefined, from, to }), [status, from, to])
  return (
    <>
      <FilterBar active={Boolean(status || from || to)} onReset={() => url.clear(['status', 'from', 'to'])}>
        <Select<DoseStatus>
          label="Status"
          value={status}
          onChange={(v) => url.set({ status: v })}
          options={[{ value: '', label: 'Any status' }, { value: 'TAKEN', label: 'Taken' }, { value: 'MISSED', label: 'Missed' }, { value: 'SKIPPED', label: 'Skipped' }]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      <RecordList q={q} columns={doseColumns()} noun="doses" empty="No doses logged for this selection." />
    </>
  )
}

function VitalsTab({ userId }: { userId: string }) {
  const url = useUrlState()
  const type = url.get('type') as VitalType | ''
  const range = url.get('range')
  const from = url.get('from')
  const to = url.get('to')
  const flagged = range === 'out' ? true : range === 'in' ? false : undefined
  const q = useListQuery('vitals', userId, (page, sort) =>
    adminApi.userVitals(userId, { page, size: PAGE_SIZE, sort, type: type || undefined, flagged, from, to }), [type, range, from, to])
  return (
    <>
      <FilterBar active={Boolean(type || range || from || to)} onReset={() => url.clear(['type', 'range', 'from', 'to'])}>
        <Select<VitalType>
          label="Vital"
          value={type}
          onChange={(v) => url.set({ type: v })}
          options={[{ value: '', label: 'All vitals' }, ...Object.entries(VITAL_LABEL).map(([value, label]) => ({ value: value as VitalType, label }))]}
        />
        <Select<'out' | 'in'>
          label="Range"
          value={range as 'out' | 'in' | ''}
          onChange={(v) => url.set({ range: v })}
          options={[{ value: '', label: 'Any' }, { value: 'out', label: 'Out of range' }, { value: 'in', label: 'In range' }]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      <RecordList q={q} columns={vitalColumns(false)} noun="readings" empty="No vital readings for this selection." alert={(v) => v.flagged} />
    </>
  )
}

function SymptomsTab({ userId }: { userId: string }) {
  const url = useUrlState()
  const min = url.get('minSeverity') as Severity | ''
  const from = url.get('from')
  const to = url.get('to')
  const q = useListQuery('symptoms', userId, (page, sort) =>
    adminApi.userSymptoms(userId, { page, size: PAGE_SIZE, sort, minSeverity: min || undefined, from, to }), [min, from, to])
  return (
    <>
      <FilterBar active={Boolean(min || from || to)} onReset={() => url.clear(['minSeverity', 'from', 'to'])}>
        <Select<Severity>
          label="Assessment"
          value={min}
          onChange={(v) => url.set({ minSeverity: v })}
          options={[{ value: '', label: 'Any' }, { value: 'MONITOR', label: 'Monitor or worse' }, { value: 'URGENT', label: 'Urgent or worse' }, { value: 'EMERGENCY', label: 'Emergency only' }]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      <RecordList
        q={q}
        columns={symptomColumns(false)}
        noun="check-ins"
        empty="No symptom check-ins for this selection."
        alert={(s) => s.overallSeverity === 'URGENT' || s.overallSeverity === 'EMERGENCY'}
      />
    </>
  )
}

function ActivityTab({ userId }: { userId: string }) {
  const url = useUrlState()
  const from = url.get('from')
  const to = url.get('to')
  const q = useListQuery('activities', userId, (page, sort) => adminApi.userActivities(userId, { page, size: PAGE_SIZE, sort, from, to }), [from, to])
  return (
    <>
      <FilterBar active={Boolean(from || to)} onReset={() => url.clear(['from', 'to'])}>
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      <RecordList q={q} columns={activityColumns()} noun="activities" empty="No activities logged for this selection." />
    </>
  )
}

function RecordList<T>({
  q,
  columns,
  noun,
  empty,
  alert,
}: {
  q: ReturnType<typeof useListQuery<T>>
  columns: Column<T>[]
  noun: string
  empty: string
  alert?: (row: T) => boolean
}) {
  if (q.error) return <ErrorNote error={q.error} />
  return (
    <>
      <DataTable
        columns={columns}
        rows={q.data?.items}
        loading={q.isFetching}
        sort={q.sort}
        onSortChange={(s) => q.url.set({ sort: s })}
        empty={empty}
        rowTone={alert ? (r) => (alert(r) ? 'alert' : undefined) : undefined}
      />
      {q.data && (
        <Pager page={q.data.page} totalPages={q.data.totalPages} totalElements={q.data.totalElements} onPage={(p) => q.url.set({ page: p })} noun={noun} />
      )}
    </>
  )
}

export function PatientDetail() {
  const { id = '' } = useParams()
  const url = useUrlState()
  const tab = (TABS.some((t) => t.id === url.get('tab')) ? url.get('tab') : 'profile') as TabId
  const { data: user, error, isPending } = useQuery({ queryKey: ['user', id], queryFn: () => adminApi.user(id) })

  if (error) {
    return (
      <>
        <Link to="/patients" className="mb-4 inline-block text-[14px] text-muted underline underline-offset-2 hover:text-ink">
          All patients
        </Link>
        <ErrorNote error={error} />
      </>
    )
  }
  if (isPending || !user) return <div className="h-40 animate-pulse rounded-lg bg-surface ring-1 ring-line" />

  // Switching tabs drops the previous tab's filters and paging: they don't apply across tabs.
  const switchTab = (t: TabId) => {
    const keys = ['sort', 'status', 'type', 'range', 'minSeverity', 'from', 'to']
    url.set({ tab: t === 'profile' ? undefined : t, ...Object.fromEntries(keys.map((k) => [k, undefined])) })
  }

  return (
    <>
      <Header user={user} />
      <Tabs user={user} active={tab} onChange={switchTab} />
      <div role="tabpanel">
        {tab === 'profile' && <ProfileTab user={user} />}
        {tab === 'medications' && <MedicationsTab userId={id} />}
        {tab === 'doses' && <DosesTab userId={id} />}
        {tab === 'vitals' && <VitalsTab userId={id} />}
        {tab === 'symptoms' && <SymptomsTab userId={id} />}
        {tab === 'activity' && <ActivityTab userId={id} />}
      </div>
    </>
  )
}
