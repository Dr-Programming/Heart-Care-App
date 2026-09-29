import { useQueryClient } from '@tanstack/react-query'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router'
import { adminApi } from '../api/admin'
import { session, setUnauthorizedHandler } from '../api/client'

interface AuthState {
  token: string | null
  signIn: (username: string, password: string) => Promise<void>
  signOut: (reason?: string) => void
  notice: string | null
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => session.get())
  const [notice, setNotice] = useState<string | null>(null)
  const queryClient = useQueryClient()

  const signOut = useCallback(
    (reason?: string) => {
      session.clear()
      queryClient.clear()
      setToken(null)
      setNotice(reason ?? null)
    },
    [queryClient],
  )

  const signIn = useCallback(async (username: string, password: string) => {
    const result = await adminApi.login(username, password)
    session.set(result.token, result.expiresAt)
    setNotice(null)
    setToken(result.token)
  }, [])

  useEffect(() => {
    setUnauthorizedHandler(() => signOut('Your session ended. Sign in again to continue.'))
  }, [signOut])

  // Sign out on the dot when the token expires, rather than on the next failed request.
  useEffect(() => {
    if (!token) return
    const expiresAt = session.expiresAt()
    if (!expiresAt) return
    const timer = window.setTimeout(
      () => signOut('Your session expired after 8 hours. Sign in again to continue.'),
      Math.max(0, expiresAt - Date.now()),
    )
    return () => window.clearTimeout(timer)
  }, [token, signOut])

  const value = useMemo(() => ({ token, signIn, signOut, notice }), [token, signIn, signOut, notice])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}

export function RequireAuth({ children }: { children: ReactNode }) {
  const { token } = useAuth()
  const location = useLocation()
  if (!token) return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />
  return children
}
