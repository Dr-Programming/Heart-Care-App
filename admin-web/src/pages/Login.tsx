import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'
import { ApiError } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import { HeartMark } from '../components/Layout'

const inputClass =
  'w-full rounded-md bg-surface px-3 py-2.5 text-ink ring-1 ring-line hover:ring-line-strong focus:ring-2 focus:ring-heart focus:outline-none'

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

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(username, password)
      navigate(from, { replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Sign-in failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="ecg-paper grid min-h-screen place-items-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-xl bg-surface p-7 ring-1 ring-line-strong">
        <HeartMark className="mb-4 size-10" />
        <h1 className="text-[24px] leading-tight font-bold">Sign in to Libu Care Admin</h1>
        <p className="mt-1 mb-6 text-muted">A read-only view of patient records. Use the admin account set up for your deployment.</p>

        {notice && !error && <p className="mb-4 rounded-md bg-amber-soft px-3 py-2 text-[14px] text-amber">{notice}</p>}
        {error && (
          <p role="alert" className="mb-4 rounded-md bg-heart-soft px-3 py-2 text-[14px] text-heart">
            {error}
          </p>
        )}

        <label className="mb-4 block">
          <span className="mb-1 block text-[14px] font-bold">Username</span>
          <input
            className={inputClass}
            autoComplete="username"
            autoFocus
            required
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
        </label>
        <label className="mb-6 block">
          <span className="mb-1 block text-[14px] font-bold">Password</span>
          <input
            className={inputClass}
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-md bg-heart px-4 py-2.5 font-bold text-white hover:brightness-110 disabled:opacity-60"
        >
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
