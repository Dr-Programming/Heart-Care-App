import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { adminApi } from '../api/admin'
import type { UserSummary } from '../api/types'
import { Badge } from '../components/Badge'
import { ErrorNote, Pager, SearchInput } from '../components/Controls'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/Layout'
import { fmtDate, LANGUAGE_LABEL } from '../lib/format'
import { useUrlState } from '../lib/useUrlState'

const columns: Column<UserSummary>[] = [
  {
    id: 'name',
    header: 'Name',
    meta: { sortKey: 'fullName' },
    cell: ({ row }) => (
      <div>
        <Link
          to={`/patients/${row.original.id}`}
          onClick={(e) => e.stopPropagation()}
          className="font-bold underline decoration-transparent underline-offset-2 hover:decoration-heart focus-visible:decoration-heart"
        >
          {row.original.name}
        </Link>
        <div className="num text-[13px] text-muted">{row.original.phoneMasked}</div>
      </div>
    ),
  },
  {
    id: 'language',
    header: 'Language',
    cell: ({ row }) => LANGUAGE_LABEL[row.original.preferredLanguage] ?? row.original.preferredLanguage,
  },
  {
    id: 'createdAt',
    header: 'Joined',
    meta: { sortKey: 'createdAt' },
    cell: ({ row }) => <span className="num whitespace-nowrap">{fmtDate(row.original.createdAt)}</span>,
  },
  { id: 'meds', header: 'Medications', meta: { align: 'right' }, cell: ({ row }) => row.original.counts.medications },
  { id: 'vitals', header: 'Vitals', meta: { align: 'right' }, cell: ({ row }) => row.original.counts.vitals },
  { id: 'symptoms', header: 'Check-ins', meta: { align: 'right' }, cell: ({ row }) => row.original.counts.symptoms },
  { id: 'activities', header: 'Activities', meta: { align: 'right' }, cell: ({ row }) => row.original.counts.activities },
  {
    id: 'status',
    header: 'Account',
    cell: ({ row }) => (row.original.locked ? <Badge tone="amber">Locked</Badge> : <Badge>Active</Badge>),
  },
]

export function Patients() {
  const navigate = useNavigate()
  const url = useUrlState()
  const q = url.get('q')
  const sort = url.get('sort') || undefined
  const [search, setSearch] = useState(q)

  // Debounce typing into the URL (and therefore the query).
  useEffect(() => {
    const t = window.setTimeout(() => {
      if (search.trim() !== q) url.set({ q: search.trim() })
    }, 300)
    return () => window.clearTimeout(t)
  }, [search, q, url])

  const { data, error, isFetching } = useQuery({
    queryKey: ['users', q, url.page, sort],
    queryFn: () => adminApi.users({ q, page: url.page, size: 25, sort }),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader title="Patients">Everyone registered through the mobile app. Select a patient to see their full record.</PageHeader>
      <div className="mb-3">
        <SearchInput value={search} onChange={setSearch} placeholder="Search by name or phone number" />
      </div>
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <>
          <DataTable
            columns={columns}
            rows={data?.items}
            loading={isFetching}
            sort={sort}
            onSortChange={(s) => url.set({ sort: s })}
            onRowClick={(u) => navigate(`/patients/${u.id}`)}
            empty={q ? `No patients match “${q}”.` : 'No patients have registered yet. They appear here after signing up in the mobile app.'}
          />
          {data && (
            <Pager page={data.page} totalPages={data.totalPages} totalElements={data.totalElements} onPage={(p) => url.set({ page: p })} noun="patients" />
          )}
        </>
      )}
    </>
  )
}
