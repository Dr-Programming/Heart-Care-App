import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate } from 'react-router'
import { ApiError } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import { ResearchMark } from '../components/Layout'

export const inputClass =
  'w-full rounded-md bg-surface px-3 py-2.5 text-ink ring-1 ring-line hover:ring-line-strong focus:ring-2 focus:ring-accent focus:outline-none'

export function Login() {
  const { token, signIn, notice } = useAuth()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  if (token) return <Navigate to="/" replace />

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const me = await signIn(username, password)
      navigate(me.mustChangePassword ? '/change-password' : '/', { replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Sign-in failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="graph-paper grid min-h-screen place-items-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-xl bg-surface p-7 ring-1 ring-line-strong">
        <ResearchMark className="mb-4 size-10" />
        <h1 className="text-[24px] leading-tight font-bold">Sign in to Libu Care Research</h1>
        <p className="mt-1 mb-6 text-muted">Anonymised data from the Libu Care app. Use the account your administrator created for you.</p>
        {notice && !error && <p className="mb-4 rounded-md bg-amber-soft px-3 py-2 text-[14px] text-amber">{notice}</p>}
        {error && <p role="alert" className="mb-4 rounded-md bg-alert-soft px-3 py-2 text-[14px] text-alert">{error}</p>}
        <label className="mb-4 block">
          <span className="mb-1 block text-[14px] font-bold">Username</span>
          <input className={inputClass} autoComplete="username" autoFocus required value={username}
            onChange={(e) => setUsername(e.target.value)} />
        </label>
        <label className="mb-6 block">
          <span className="mb-1 block text-[14px] font-bold">Password</span>
          <input className={inputClass} type="password" autoComplete="current-password" required value={password}
            onChange={(e) => setPassword(e.target.value)} />
        </label>
        <button type="submit" disabled={busy} className="w-full rounded-md bg-accent px-4 py-2.5 font-bold text-white hover:brightness-110 disabled:opacity-60">
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="mt-5 text-[13px] text-muted">Everything you do here is recorded and visible to your administrator.</p>
      </form>
    </div>
  )
}
