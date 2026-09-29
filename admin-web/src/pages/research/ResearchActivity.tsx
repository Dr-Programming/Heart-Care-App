import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { adminApi, type ActivityQuery } from '../../api/admin'
import { DateRange, ErrorNote, FilterBar, Pager, Select } from '../../components/Controls'
import { DataTable } from '../../components/DataTable'
import { PageHeader } from '../../components/Layout'
import { activityColumns } from '../../components/research/ResearcherBits'
import { useUrlState } from '../../lib/useUrlState'

/** The research access log with filters and CSV download; used globally and per researcher. */
export function ActivityLog({ researcherId }: { researcherId?: string }) {
  const url = useUrlState()
  const from = url.get('from')
  const to = url.get('to')
  const failures = url.get('failures') === '1'
  const who = researcherId ?? (url.get('researcher') || undefined)
  const [downloading, setDownloading] = useState(false)
  const [downloadError, setDownloadError] = useState<string | null>(null)

  const researchers = useQuery({ queryKey: ['researchers'], queryFn: adminApi.researchers, enabled: !researcherId })
  const archived = useQuery({ queryKey: ['researchers-archive'], queryFn: adminApi.archivedResearchers, enabled: !researcherId })
  const query: ActivityQuery = { researcherId: who, from, to, failuresOnly: failures || undefined, page: url.page, size: 50 }
  const { data, error, isFetching } = useQuery({
    queryKey: ['research-activity', query],
    queryFn: () => adminApi.researchActivity(query),
    placeholderData: keepPreviousData,
  })

  const download = async () => {
    setDownloading(true)
    setDownloadError(null)
    try {
      await adminApi.downloadResearchActivity(query)
    } catch {
      setDownloadError('Download failed. Try again.')
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <FilterBar active={Boolean(from || to || failures || (!researcherId && who))}
        onReset={() => url.clear(['from', 'to', 'failures', 'researcher'])}>
        {!researcherId && (
          <label className="flex flex-col gap-1 text-[13px] text-muted">
            Researcher
            <select
              className="rounded-md bg-surface px-2.5 py-1.5 text-[14px] text-ink ring-1 ring-line hover:ring-line-strong focus:ring-heart focus:outline-none"
              value={who ?? ''}
              onChange={(e) => url.set({ researcher: e.target.value })}
            >
              <option value="">Everyone</option>
              <optgroup label="Current">
                {(researchers.data ?? []).map((r) => <option key={r.id} value={r.id}>{r.fullName}</option>)}
              </optgroup>
              {(archived.data?.length ?? 0) > 0 && (
                <optgroup label="Archived">
                  {archived.data!.map((r) => <option key={r.id} value={r.id}>{r.fullName} (archived)</option>)}
                </optgroup>
              )}
            </select>
          </label>
        )}
        <Select<'1'>
          label="Outcome"
          value={failures ? '1' : ''}
          onChange={(v) => url.set({ failures: v })}
          options={[{ value: '', label: 'Everything' }, { value: '1', label: 'Refused or failed only' }]}
        />
        <DateRange from={from} to={to} onChange={(r) => url.set(r)} />
        <button type="button" onClick={download} disabled={downloading}
          className="ml-auto rounded-md px-3 py-1.5 font-bold ring-1 ring-line hover:ring-line-strong disabled:opacity-50">
          {downloading ? 'Preparing…' : 'Download CSV'}
        </button>
      </FilterBar>
      {downloadError && <p className="mb-2 text-heart">{downloadError}</p>}
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <>
          <DataTable
            columns={activityColumns(!researcherId)}
            rows={data?.items}
            loading={isFetching}
            empty="No research activity for this selection."
            rowTone={(a) => (a.status >= 400 ? 'alert' : undefined)}
          />
          {data && (
            <Pager page={data.page} totalPages={data.totalPages} totalElements={data.totalElements}
              onPage={(p) => url.set({ page: p })} noun="requests" />
          )}
        </>
      )}
    </>
  )
}

export function ResearchActivity() {
  return (
    <>
      <PageHeader title="Research activity">
        Every request any researcher has made: sign-ins (including failed ones), analyses with their parameters, record views and downloads.
      </PageHeader>
      <ActivityLog />
    </>
  )
}
