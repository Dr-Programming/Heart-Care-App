import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router'
import { adminApi } from '../../api/admin'
import type { Researcher } from '../../api/types'
import { ErrorNote } from '../../components/Controls'
import { DataTable, type Column } from '../../components/DataTable'
import { PageHeader } from '../../components/Layout'
import { fmtDateTime } from '../../lib/format'

const columns: Column<Researcher>[] = [
  {
    id: 'name',
    header: 'Researcher',
    cell: ({ row }) => (
      <div>
        <Link to={`/researchers/${row.original.id}`} onClick={(e) => e.stopPropagation()}
          className="font-bold underline decoration-transparent underline-offset-2 hover:decoration-heart">
          {row.original.fullName}
        </Link>
        <div className="num text-[13px] text-muted">
          {row.original.username}
          {row.original.organisation && `, ${row.original.organisation}`}
        </div>
      </div>
    ),
  },
  {
    id: 'archived',
    header: 'Deleted',
    cell: ({ row }) => (
      <div className="whitespace-nowrap">
        <div className="num">{fmtDateTime(row.original.archivedAt)}</div>
        <div className="text-[13px] text-muted">by {row.original.archivedBy ?? 'an admin'}</div>
      </div>
    ),
  },
  {
    id: 'reason',
    header: 'Reason',
    cell: ({ row }) => <span className="block max-w-[40ch]">{row.original.archiveReason}</span>,
  },
  {
    id: 'active',
    header: 'Had access from',
    cell: ({ row }) => <span className="num whitespace-nowrap text-muted">{fmtDateTime(row.original.createdAt)}</span>,
  },
  {
    id: 'last',
    header: 'Last sign-in',
    cell: ({ row }) => <span className="num whitespace-nowrap text-muted">{row.original.lastLoginAt ? fmtDateTime(row.original.lastLoginAt) : 'Never'}</span>,
  },
]

/** Deleted researchers, kept so audits can still see who had access and everything they did. */
export function ResearcherArchive() {
  const navigate = useNavigate()
  const { data, error, isFetching } = useQuery({ queryKey: ['researchers-archive'], queryFn: adminApi.archivedResearchers })

  return (
    <>
      <Link to="/researchers" className="text-[14px] text-muted underline underline-offset-2 hover:text-ink">
        Current researchers
      </Link>
      <div className="mt-2">
        <PageHeader title="Researcher archive">
          Researchers you’ve deleted. They can’t sign in and their usernames can’t be reused, but their access settings, admin history and every
          request they made are kept here for audits. Open one to review it or restore it.
        </PageHeader>
      </div>
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <DataTable
          columns={columns}
          rows={data}
          loading={isFetching}
          onRowClick={(r) => navigate(`/researchers/${r.id}`)}
          empty="The archive is empty. Deleted researchers appear here."
        />
      )}
    </>
  )
}
