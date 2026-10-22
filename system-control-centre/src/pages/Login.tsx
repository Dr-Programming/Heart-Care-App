// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { ApiError } from '../services/client'

export function Login() {
  const { token, signIn, notice } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const from = (location.state as { from?: string } | null)?.from ?? '/'
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  if (token) return <Navigate to={from} replace />

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(username.trim(), password)
      navigate(from, { replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Sign-in failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="trace-paper flex min-h-screen items-center justify-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-lg border border-line-strong bg-night p-6 shadow-2xl">
        <div className="mb-6 flex items-center gap-3">
          <img src="/favicon.svg" alt="" className="size-9" />
          <div>
            <h1 className="text-xl font-bold">System Control Centre</h1>
            <p className="text-sm text-muted">Live monitoring for the Heart Care platform</p>
          </div>
        </div>
        {notice && <p className="mb-4 rounded-md bg-warn-soft px-3 py-2 text-sm text-warn">{notice}</p>}
        <label className="mb-4 block">
          <span className="mb-1 block text-sm text-muted">Username</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
            className="w-full rounded-md border border-line bg-surface px-3 py-2 text-ink outline-none focus:border-mobile"
          />
        </label>
        <label className="mb-5 block">
          <span className="mb-1 block text-sm text-muted">Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
            className="w-full rounded-md border border-line bg-surface px-3 py-2 text-ink outline-none focus:border-mobile"
          />
        </label>
        {error && (
          <p role="alert" className="mb-4 text-sm text-crit">
            {error}
          </p>
        )}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-md bg-ok px-4 py-2.5 font-bold text-night hover:brightness-110 disabled:opacity-60"
        >
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="mt-4 text-xs text-faint">
          This is the SCC account set in SCC_ADMIN_USERNAME, not the admin panel login.
        </p>
      </form>
    </main>
  )
}
