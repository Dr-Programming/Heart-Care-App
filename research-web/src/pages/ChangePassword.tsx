import { useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate } from 'react-router'
import { researchApi } from '../api/research'
import { ApiError } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import { ResearchMark } from '../components/Layout'
import { inputClass } from './Login'

/**
 * The forced first-sign-in change. The one-change rule is stated before they choose, because
 * the consequence (only an admin can change it after this) is permanent from their side.
 */
export function ChangePassword() {
  const { me, signOut } = useAuth()
  const qc = useQueryClient()
  const navigate = useNavigate()
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  if (me && !me.mustChangePassword) return <Navigate to="/" replace />

  const mismatch = confirm.length > 0 && next !== confirm
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (next !== confirm) return
    setBusy(true)
    setError(null)
    try {
      const updated = await researchApi.changePassword(current, next)
      qc.setQueryData(['me'], updated)
      navigate('/', { replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Couldn’t change the password.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="graph-paper grid min-h-screen place-items-center px-4 py-8">
      <form onSubmit={submit} className="w-full max-w-md rounded-xl bg-surface p-7 ring-1 ring-line-strong">
        <ResearchMark className="mb-4 size-10" />
        <h1 className="text-[24px] leading-tight font-bold">Choose your own password</h1>
        <p className="mt-2 text-muted">
          Your administrator gave you a temporary password. Replace it now to continue.
        </p>
        <p className="mt-3 mb-6 rounded-md bg-amber-soft px-3 py-2 text-[14px] text-amber">
          You can only do this once. If you need to change it again later, your administrator will have to reset it for you.
        </p>
        {error && <p role="alert" className="mb-4 rounded-md bg-alert-soft px-3 py-2 text-[14px] text-alert">{error}</p>}
        <label className="mb-4 block">
          <span className="mb-1 block text-[14px] font-bold">Temporary password</span>
          <input className={inputClass} type="password" autoComplete="current-password" required value={current}
            onChange={(e) => setCurrent(e.target.value)} />
        </label>
        <label className="mb-4 block">
          <span className="mb-1 block text-[14px] font-bold">New password</span>
          <input className={inputClass} type="password" autoComplete="new-password" required minLength={12} maxLength={128}
            value={next} onChange={(e) => setNext(e.target.value)} aria-describedby="pw-hint" />
          <span id="pw-hint" className="mt-1 block text-[13px] text-muted">At least 12 characters, different from the temporary one.</span>
        </label>
        <label className="mb-6 block">
          <span className="mb-1 block text-[14px] font-bold">Type it again</span>
          <input className={inputClass} type="password" autoComplete="new-password" required value={confirm}
            onChange={(e) => setConfirm(e.target.value)} aria-invalid={mismatch} />
          {mismatch && <span className="mt-1 block text-[13px] text-alert">The two passwords don’t match.</span>}
        </label>
        <button type="submit" disabled={busy || mismatch} className="w-full rounded-md bg-accent px-4 py-2.5 font-bold text-white hover:brightness-110 disabled:opacity-60">
          {busy ? 'Saving…' : 'Save password and continue'}
        </button>
        <button type="button" onClick={() => signOut()} className="mt-3 w-full text-[14px] text-muted underline underline-offset-2 hover:text-ink">
          Sign out
        </button>
      </form>
    </div>
  )
}
