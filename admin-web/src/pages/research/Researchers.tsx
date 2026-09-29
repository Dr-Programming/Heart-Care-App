import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router'
import { adminApi } from '../../api/admin'
import { ApiError } from '../../api/client'
import type { Researcher } from '../../api/types'
import { ErrorNote } from '../../components/Controls'
import { DataTable, type Column } from '../../components/DataTable'
import { PageHeader } from '../../components/Layout'
import { DATASET_LABEL, LEVEL_LABEL } from '../../components/research/GrantForm'
import { StatusBadge } from '../../components/research/ResearcherBits'
import { fmtDate, fmtRelative } from '../../lib/format'

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
    id: 'access',
    header: 'Access',
    cell: ({ row }) => {
      const g = row.original.grant
      if (!g) return <span className="text-faint">None</span>
      return (
        <div>
          <div>{LEVEL_LABEL[g.accessLevel].label}{g.exportAllowed && ', can download'}</div>
          <div className="text-[13px] text-muted">{g.datasets.map((d) => DATASET_LABEL[d].label).join(', ')}</div>
        </div>
      )
    },
  },
  { id: 'status', header: 'Status', cell: ({ row }) => <StatusBadge r={row.original} /> },
  {
    id: 'expires',
    header: 'Access ends',
    cell: ({ row }) => <span className="num whitespace-nowrap">{row.original.grant?.expiresAt ? fmtDate(row.original.grant.expiresAt) : 'No end date'}</span>,
  },
  {
    id: 'last',
    header: 'Last sign-in',
    cell: ({ row }) => <span className="whitespace-nowrap text-muted">{row.original.lastLoginAt ? fmtRelative(row.original.lastLoginAt) : 'Never'}</span>,
  },
]

function MinGroupSize() {
  const qc = useQueryClient()
  const { data } = useQuery({ queryKey: ['research-settings'], queryFn: adminApi.researchSettings })
  const [editing, setEditing] = useState<string | null>(null)
  const save = useMutation({
    mutationFn: (k: number) => adminApi.updateResearchSettings(k),
    onSuccess: () => {
      setEditing(null)
      qc.invalidateQueries({ queryKey: ['research-settings'] })
    },
  })
  const k = data?.minGroupSize

  return (
    <section aria-labelledby="k-title" className="mb-8 rounded-lg bg-surface p-4 ring-1 ring-line">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="max-w-[60ch]">
          <h2 id="k-title" className="font-bold">Minimum group size</h2>
          <p className="text-[14px] text-muted">
            Any result describing fewer patients than this is hidden from every researcher, so no one can be singled out. Applies immediately.
          </p>
        </div>
        {editing === null ? (
          <div className="flex items-center gap-3">
            <span className="num text-[28px] leading-none font-bold">{k ?? '…'}</span>
            <button type="button" onClick={() => setEditing(String(k ?? 5))} className="rounded-md px-3 py-1.5 font-bold ring-1 ring-line hover:ring-line-strong">
              Change
            </button>
          </div>
        ) : (
          <form
            className="flex items-center gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              save.mutate(Number(editing))
            }}
          >
            <input type="number" min={2} max={50} required value={editing} onChange={(e) => setEditing(e.target.value)}
              aria-label="Minimum group size"
              className="num w-20 rounded-md bg-surface px-2.5 py-1.5 ring-1 ring-line focus:ring-heart focus:outline-none" />
            <button type="submit" disabled={save.isPending} className="rounded-md bg-heart px-3 py-1.5 font-bold text-white">Save</button>
            <button type="button" onClick={() => setEditing(null)} className="rounded-md px-3 py-1.5 ring-1 ring-line">Cancel</button>
          </form>
        )}
      </div>
      {save.error && <p className="mt-2 text-[14px] text-heart">{save.error instanceof ApiError ? save.error.message : 'Couldn’t save.'}</p>}
    </section>
  )
}

export function Researchers() {
  const navigate = useNavigate()
  const deleted = (useLocation().state as { deleted?: string } | null)?.deleted
  const { data, error, isFetching } = useQuery({ queryKey: ['researchers'], queryFn: adminApi.researchers })
  const archived = useQuery({ queryKey: ['researchers-archive'], queryFn: adminApi.archivedResearchers })

  return (
    <>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <PageHeader title="Researchers">
          People you’ve given access to anonymised data. You decide what each one can see, for how long, and whether they can download it.
        </PageHeader>
        <div className="flex items-center gap-3">
          <Link to="/researchers/archive" className="rounded-md px-4 py-2 ring-1 ring-line hover:ring-line-strong">
            View archive{archived.data ? ` (${archived.data.length})` : ''}
          </Link>
          <Link to="/researchers/new" className="rounded-md bg-heart px-4 py-2 font-bold text-white hover:brightness-110">
            Add researcher
          </Link>
        </div>
      </div>
      {deleted && (
        <p role="status" className="mb-4 rounded-md bg-calm-soft px-3 py-2 text-calm">
          {deleted} was deleted and moved to the <Link to="/researchers/archive" className="font-bold underline">archive</Link>.
        </p>
      )}
      <MinGroupSize />
      {error ? (
        <ErrorNote error={error} />
      ) : (
        <DataTable
          columns={columns}
          rows={data}
          loading={isFetching}
          onRowClick={(r) => navigate(`/researchers/${r.id}`)}
          empty="No researchers yet. Add one to give them access to anonymised data."
        />
      )}
    </>
  )
}
