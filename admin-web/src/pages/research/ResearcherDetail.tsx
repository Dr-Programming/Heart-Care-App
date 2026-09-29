import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { adminApi } from '../../api/admin'
import { ApiError } from '../../api/client'
import type { Grant, IssuedPassword, Researcher, ResearcherEvent } from '../../api/types'
import { ErrorNote } from '../../components/Controls'
import { GrantForm } from '../../components/research/GrantForm'
import { PasswordReveal } from '../../components/research/PasswordReveal'
import { ConfirmAction, StatusBadge } from '../../components/research/ResearcherBits'
import { fmtDateTime } from '../../lib/format'
import { useUrlState } from '../../lib/useUrlState'
import { ActivityLog } from './ResearchActivity'

const TABS = [
  { id: 'access', label: 'Access' },
  { id: 'activity', label: 'Activity' },
  { id: 'history', label: 'Admin history' },
] as const
type TabId = (typeof TABS)[number]['id']

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-muted">{label}</dt>
      <dd className="font-bold">{children}</dd>
    </div>
  )
}

function passwordStatus(r: Researcher) {
  if (r.mustChangePassword) return 'Temporary, not yet replaced'
  if (r.passwordChangedAt) return `Set by researcher ${fmtDateTime(r.passwordChangedAt)}`
  return 'Set'
}

function AccessTab({ r }: { r: Researcher }) {
  const qc = useQueryClient()
  const [draft, setDraft] = useState<Grant | null>(r.grant)
  const [saved, setSaved] = useState(false)
  useEffect(() => setDraft(r.grant), [r.grant])

  const save = useMutation({
    mutationFn: (g: Grant) => adminApi.updateGrant(r.id, g),
    onSuccess: (updated) => {
      qc.setQueryData(['researcher', r.id], updated)
      qc.invalidateQueries({ queryKey: ['researchers'] })
      qc.invalidateQueries({ queryKey: ['researcher-events', r.id] })
      setSaved(true)
    },
  })
  if (!draft) return null
  if (r.status === 'ARCHIVED') {
    return (
      <div className="max-w-3xl">
        <p className="mb-4 text-[14px] text-muted">The access this researcher had when they were deleted. Restore them from the archive to change it.</p>
        <GrantForm value={draft} onChange={() => {}} disabled />
      </div>
    )
  }
  const dirty = JSON.stringify({ ...draft, updatedAt: undefined }) !== JSON.stringify({ ...r.grant, updatedAt: undefined })

  return (
    <form
      className="max-w-3xl space-y-6"
      onSubmit={(e) => {
        e.preventDefault()
        setSaved(false)
        save.mutate(draft)
      }}
    >
      <GrantForm value={draft} onChange={(g) => { setDraft(g); setSaved(false) }} />
      {save.error && (
        <p role="alert" className="rounded-md bg-heart-soft px-3 py-2 text-heart">
          {save.error instanceof ApiError ? save.error.message : 'Couldn’t save access.'}
        </p>
      )}
      <div className="flex items-center gap-3">
        <button type="submit" disabled={!dirty || save.isPending || draft.datasets.length === 0}
          className="rounded-md bg-heart px-4 py-2 font-bold text-white hover:brightness-110 disabled:opacity-40">
          {save.isPending ? 'Saving…' : 'Save access'}
        </button>
        {dirty && <button type="button" onClick={() => setDraft(r.grant)} className="rounded-md px-4 py-2 ring-1 ring-line">Discard changes</button>}
        {saved && !dirty && <span className="text-calm">Saved. Applies to their next request.</span>}
      </div>
    </form>
  )
}

const ACTION_LABEL: Record<ResearcherEvent['action'], string> = {
  CREATED: 'Created the account',
  ARCHIVED: 'Deleted the researcher (archived)',
  UNARCHIVED: 'Restored the researcher from the archive',
  GRANT_UPDATED: 'Changed access',
  REVOKED: 'Revoked access',
  RESTORED: 'Restored access',
  PASSWORD_RESET: 'Reset the password',
}

function HistoryTab({ id }: { id: string }) {
  const { data, error } = useQuery({ queryKey: ['researcher-events', id], queryFn: () => adminApi.researcherEvents(id) })
  if (error) return <ErrorNote error={error} />
  return (
    <ol className="max-w-3xl space-y-0 rounded-lg bg-surface ring-1 ring-line">
      {(data ?? []).map((e) => (
        <li key={e.id} className="flex flex-wrap items-baseline justify-between gap-2 border-b border-line px-4 py-3 last:border-0">
          <span>
            <span className="font-bold">{e.adminUsername ?? 'An admin'}</span> {ACTION_LABEL[e.action].toLowerCase()}
          </span>
          <span className="num text-[14px] text-muted">{fmtDateTime(e.occurredAt)}</span>
          {e.action === 'ARCHIVED' && e.detailsJson && (
            <p className="w-full text-[14px] text-muted">Reason: {(JSON.parse(e.detailsJson) as { reason?: string }).reason}</p>
          )}
          {e.action === 'GRANT_UPDATED' && e.detailsJson && (
            <details className="w-full">
              <summary className="cursor-pointer text-[13px] text-muted">Before and after</summary>
              <pre className="mt-1 overflow-auto rounded bg-paper p-2 text-[12px] ring-1 ring-line">
                {JSON.stringify(JSON.parse(e.detailsJson), null, 2)}
              </pre>
            </details>
          )}
        </li>
      ))}
    </ol>
  )
}

/**
 * "Delete" archives: the reason is required because it's what an auditor reads later, and the
 * copy says plainly that history is kept rather than destroyed.
 */
function DeleteResearcher({ id, name }: { id: string; name: string }) {
  const qc = useQueryClient()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const [reason, setReason] = useState('')
  const remove = useMutation({
    mutationFn: () => adminApi.archiveResearcher(id, reason.trim()),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['researchers'] })
      qc.invalidateQueries({ queryKey: ['researchers-archive'] })
      qc.removeQueries({ queryKey: ['researcher', id] })
      navigate('/researchers', { replace: true, state: { deleted: name } })
    },
  })
  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)}
        className="rounded-md px-3 py-1.5 font-bold text-heart ring-1 ring-heart/40 hover:ring-heart">
        Delete researcher
      </button>
    )
  }
  return (
    <form role="alertdialog" aria-label="Delete researcher"
      className="w-full max-w-xl rounded-lg bg-surface p-4 ring-1 ring-heart/50"
      onSubmit={(e) => { e.preventDefault(); remove.mutate() }}>
      <p className="font-bold">Delete {name}?</p>
      <p className="mt-1 text-[14px] text-muted">
        They’ll be signed out and blocked immediately, and removed from the researchers list. Their access settings, history and activity log
        move to the archive, where you can still review or restore them.
      </p>
      <label className="mt-3 block">
        <span className="mb-1 block text-[14px] font-bold">Reason</span>
        <textarea required minLength={3} maxLength={500} rows={2} value={reason} onChange={(e) => setReason(e.target.value)}
          placeholder="e.g. Study ended, left the university"
          className="w-full rounded-md bg-surface px-3 py-2 ring-1 ring-line focus:ring-heart focus:outline-none" />
        <span className="mt-1 block text-[13px] text-muted">Kept with the archive record for audits.</span>
      </label>
      {remove.error && <p className="mt-2 text-[14px] text-heart">{remove.error instanceof ApiError ? remove.error.message : 'Couldn’t delete.'}</p>}
      <div className="mt-3 flex gap-2">
        <button type="submit" disabled={remove.isPending || reason.trim().length < 3}
          className="rounded-md bg-heart px-3 py-1.5 font-bold text-white disabled:opacity-50">
          {remove.isPending ? 'Deleting…' : 'Delete and archive'}
        </button>
        <button type="button" onClick={() => setOpen(false)} className="rounded-md px-3 py-1.5 ring-1 ring-line">Cancel</button>
      </div>
    </form>
  )
}

export function ResearcherDetail() {
  const { id = '' } = useParams()
  const qc = useQueryClient()
  const url = useUrlState()
  const tab = (TABS.some((t) => t.id === url.get('tab')) ? url.get('tab') : 'access') as TabId
  const [issued, setIssued] = useState<IssuedPassword | null>(null)

  const { data: r, error } = useQuery({
    queryKey: ['researcher', id],
    queryFn: () => adminApi.researcher(id),
    placeholderData: keepPreviousData,
  })

  const after = (updated: Researcher) => {
    qc.setQueryData(['researcher', id], updated)
    qc.invalidateQueries({ queryKey: ['researchers'] })
    qc.invalidateQueries({ queryKey: ['researcher-events', id] })
  }
  const revoke = useMutation({ mutationFn: () => adminApi.revokeResearcher(id), onSuccess: after })
  const restore = useMutation({ mutationFn: () => adminApi.restoreResearcher(id), onSuccess: after })
  const reset = useMutation({
    mutationFn: () => adminApi.resetResearcherPassword(id),
    onSuccess: (res) => {
      after(res.researcher)
      setIssued(res)
    },
  })
  const unarchive = useMutation({
    mutationFn: () => adminApi.unarchiveResearcher(id),
    onSuccess: (updated) => {
      after(updated)
      qc.invalidateQueries({ queryKey: ['researchers-archive'] })
    },
  })
  const actionError = revoke.error ?? restore.error ?? reset.error ?? unarchive.error

  if (error) return <ErrorNote error={error} />
  if (!r) return <div className="h-40 animate-pulse rounded-lg bg-surface ring-1 ring-line" />
  const archived = r.status === 'ARCHIVED'

  return (
    <>
      <Link to={archived ? '/researchers/archive' : '/researchers'}
        className="text-[14px] text-muted underline underline-offset-2 hover:text-ink">
        {archived ? 'Researcher archive' : 'All researchers'}
      </Link>
      <header className="mt-2 mb-6">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-[28px] leading-tight font-bold tracking-[-0.01em]">{r.fullName}</h1>
          <StatusBadge r={r} />
        </div>
        <dl className="mt-3 flex flex-wrap gap-x-8 gap-y-2 text-[14px]">
          <Fact label="Username"><span className="num">{r.username}</span></Fact>
          <Fact label="Organisation">{r.organisation ?? '—'}</Fact>
          <Fact label="Added">{fmtDateTime(r.createdAt)}{r.createdBy && ` by ${r.createdBy}`}</Fact>
          <Fact label="Last sign-in">{r.lastLoginAt ? fmtDateTime(r.lastLoginAt) : 'Never'}</Fact>
          <Fact label="Password">{passwordStatus(r)}</Fact>
        </dl>
        {archived && (
          <div className="mt-4 max-w-3xl rounded-lg bg-paper px-4 py-3 ring-1 ring-line-strong">
            <p className="font-bold">Deleted {fmtDateTime(r.archivedAt)} by {r.archivedBy ?? 'an admin'}</p>
            <p className="mt-0.5 text-muted">Reason: {r.archiveReason}</p>
            <p className="mt-2 text-[14px] text-muted">
              This account is archived: it can’t sign in, and its username stays reserved. Its access, history and activity are kept below for audits.
            </p>
          </div>
        )}
        <div className="mt-4 flex flex-wrap items-start gap-2">
          {archived ? (
            <ConfirmAction label="Restore from archive" busy={unarchive.isPending} onConfirm={() => unarchive.mutate()}
              confirm="They’ll return to the researchers list with access revoked. Restore access and reset the password to let them sign in." />
          ) : r.status === 'ACTIVE' ? (
            <ConfirmAction label="Revoke access" tone="danger" busy={revoke.isPending} onConfirm={() => revoke.mutate()}
              confirm="They’ll be signed out immediately and can’t sign in again until you restore access." />
          ) : (
            <ConfirmAction label="Restore access" busy={restore.isPending} onConfirm={() => restore.mutate()}
              confirm="They’ll be able to sign in again with their current password." />
          )}
          {!archived && (
            <ConfirmAction label="Reset password" busy={reset.isPending} onConfirm={() => reset.mutate()}
              confirm="Issues a new temporary password and signs them out. They’ll change it once at next sign-in." />
          )}
          {!archived && <DeleteResearcher id={id} name={r.fullName} />}
        </div>
        {actionError && <p role="alert" className="mt-2 text-heart">{actionError instanceof ApiError ? actionError.message : 'That didn’t work.'}</p>}
      </header>

      <div role="tablist" aria-label="Researcher" className="mb-5 flex gap-1 overflow-x-auto border-b border-line">
        {TABS.map((t) => (
          <button key={t.id} role="tab" type="button" aria-selected={tab === t.id}
            onClick={() => url.set({ tab: t.id === 'access' ? undefined : t.id, from: undefined, to: undefined, path: undefined, failures: undefined })}
            className={`-mb-px border-b-2 px-3 py-2.5 whitespace-nowrap ${tab === t.id ? 'border-heart font-bold text-ink' : 'border-transparent text-muted hover:text-ink'}`}>
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel">
        {tab === 'access' && <AccessTab r={r} />}
        {tab === 'activity' && <ActivityLog researcherId={id} />}
        {tab === 'history' && <HistoryTab id={id} />}
      </div>

      {issued && (
        <PasswordReveal title="New temporary password" username={issued.researcher.username} password={issued.password}
          onClose={() => setIssued(null)} />
      )}
    </>
  )
}
