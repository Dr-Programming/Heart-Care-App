import type { ReactNode } from 'react'
import { useAuth } from '../auth/AuthContext'
import { PageHeader } from '../components/Layout'
import { fmtDateTime } from '../lib/format'

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap justify-between gap-4 border-b border-line px-4 py-3 last:border-0">
      <dt className="text-muted">{label}</dt>
      <dd className="font-bold">{children}</dd>
    </div>
  )
}

/** Read-only: account details belong to the administrator. */
export function Account() {
  const { me } = useAuth()
  if (!me) return null
  return (
    <>
      <PageHeader title="Account">
        Your administrator manages these details. To change your name, organisation or username, or to reset your password, contact them.
      </PageHeader>
      <dl className="max-w-2xl rounded-xl bg-surface ring-1 ring-line">
        <Row label="Name">{me.fullName}</Row>
        <Row label="Username"><span className="num">{me.username}</span></Row>
        <Row label="Organisation">{me.organisation ?? '—'}</Row>
        <Row label="Last sign-in">{me.lastLoginAt ? fmtDateTime(me.lastLoginAt) : '—'}</Row>
        <Row label="Password">
          {me.passwordChangedAt ? `Changed by you ${fmtDateTime(me.passwordChangedAt)}` : 'Set by your administrator'}
        </Row>
      </dl>
      <p className="mt-4 max-w-2xl text-[14px] text-muted">
        {me.canChangePassword
          ? 'You can still change your password once.'
          : 'You’ve used your one password change. If you need a new password, ask your administrator to reset it; you’ll then choose a new one at your next sign-in.'}
      </p>
    </>
  )
}
