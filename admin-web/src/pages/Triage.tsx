import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router'
import { adminApi } from '../api/admin'
import type { Severity, VitalType } from '../api/types'
import { DateRange, ErrorNote, FilterBar, Pager, Select } from '../components/Controls'
import { DataTable } from '../components/DataTable'
import { PageHeader } from '../components/Layout'
import { symptomColumns, vitalColumns } from '../components/recordColumns'
import { VITAL_LABEL } from '../lib/format'
import { useUrlState } from '../lib/useUrlState'

const PAGE_SIZE = 25

export function FlaggedVitals() {
  const navigate = useNavigate()
  const url = useUrlState()
  const type = url.get('type') as VitalType | ''
  const from = url.get('from')
  const to = url.get('to')
  const sort = url.get('sort') || undefined

  const { data, error, isFetching } = useQuery({
    queryKey: ['flagged-vitals', url.page, sort, type, from, to],
    queryFn: () => adminApi.flaggedVitals({ page: url.page, size: PAGE_SIZE, sort, type: type || undefined, from, to }),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader title="Out-of-range vitals">
        Readings from every patient that fell outside the app’s safe range when they were logged. Newest first.
      </PageHeader>
      <FilterBar active={Boolean(type || from || to)} onReset={() => url.clear(['type', 'from', 'to'])}>
        <Select<VitalType>
          label="Vital"
          value={type}
          onChange={(v) => url.set({ type: v })}
          options={[{ value: '', label: 'All vitals' }, ...Object.entries(VITAL_LABEL).map(([value, label]) => ({ value: value as VitalType, label }))]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <>
          <DataTable
            columns={vitalColumns(true)}
            rows={data?.items}
            loading={isFetching}
            sort={sort}
            onSortChange={(s) => url.set({ sort: s })}
            onRowClick={(v) => navigate(`/patients/${v.userId}?tab=vitals&range=out`)}
            empty="No out-of-range readings for this selection."
          />
          {data && (
            <Pager page={data.page} totalPages={data.totalPages} totalElements={data.totalElements} onPage={(p) => url.set({ page: p })} noun="readings" />
          )}
        </>
      )}
    </>
  )
}

export function UrgentSymptoms() {
  const navigate = useNavigate()
  const url = useUrlState()
  const min = (url.get('minSeverity') || 'URGENT') as Severity
  const from = url.get('from')
  const to = url.get('to')
  const sort = url.get('sort') || undefined

  const { data, error, isFetching } = useQuery({
    queryKey: ['urgent-symptoms', url.page, sort, min, from, to],
    queryFn: () => adminApi.urgentSymptoms({ page: url.page, size: PAGE_SIZE, sort, minSeverity: min, from, to }),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader title="Urgent symptoms">
        Check-ins the app assessed as urgent or an emergency, across every patient. Highlighted fields drove the assessment.
      </PageHeader>
      <FilterBar active={Boolean(url.get('minSeverity') || from || to)} onReset={() => url.clear(['minSeverity', 'from', 'to'])}>
        <Select<Severity>
          label="Assessment"
          value={min}
          onChange={(v) => url.set({ minSeverity: v === 'URGENT' ? undefined : v })}
          options={[
            { value: 'URGENT', label: 'Urgent or emergency' },
            { value: 'EMERGENCY', label: 'Emergency only' },
            { value: 'MONITOR', label: 'Monitor or worse' },
          ]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
      </FilterBar>
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <>
          <DataTable
            columns={symptomColumns(true)}
            rows={data?.items}
            loading={isFetching}
            sort={sort}
            onSortChange={(s) => url.set({ sort: s })}
            onRowClick={(s) => navigate(`/patients/${s.userId}?tab=symptoms`)}
            empty="No check-ins at this level for this selection."
          />
          {data && (
            <Pager page={data.page} totalPages={data.totalPages} totalElements={data.totalElements} onPage={(p) => url.set({ page: p })} noun="check-ins" />
          )}
        </>
      )}
    </>
  )
}
