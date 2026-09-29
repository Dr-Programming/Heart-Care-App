import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'
import { researchApi } from '../api/research'
import { session, setAccessProblemHandler } from '../api/client'
import type { Me } from '../api/types'

interface AuthState {
  token: string | null
  me: Me | undefined
  signIn: (username: string, password: string) => Promise<Me>
  signOut: (reason?: string) => void
  notice: string | null
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => session.get())
  const [notice, setNotice] = useState<string | null>(null)
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const me = useQuery({ queryKey: ['me'], queryFn: researchApi.me, enabled: Boolean(token), staleTime: 60_000 })

  const signOut = useCallback(
    (reason?: string) => {
      session.clear()
      queryClient.clear()
      setToken(null)
      setNotice(reason ?? null)
    },
    [queryClient],
  )

  const signIn = useCallback(
    async (username: string, password: string) => {
      const result = await researchApi.login(username, password)
      session.set(result.token, result.expiresAt)
      queryClient.setQueryData(['me'], result.researcher)
      setNotice(null)
      setToken(result.token)
      return result.researcher
    },
    [queryClient],
  )

  // Revoked, expired or reset access ends the session with the server's own explanation;
  // an unreplaced admin-issued password sends the researcher to the change screen.
  useEffect(() => {
    setAccessProblemHandler((error) => {
      if (error.code === 'PASSWORD_CHANGE_REQUIRED') {
        queryClient.invalidateQueries({ queryKey: ['me'] })
        navigate('/change-password', { replace: true })
      } else {
        signOut(error.message || 'Your session ended. Sign in again to continue.')
      }
    })
  }, [signOut, navigate, queryClient])

  useEffect(() => {
    if (!token) return
    const expiresAt = session.expiresAt()
    if (!expiresAt) return
    const timer = window.setTimeout(
      () => signOut('Your session expired. Sign in again to continue.'),
      Math.max(0, expiresAt - Date.now()),
    )
    return () => window.clearTimeout(timer)
  }, [token, signOut])

  const value = useMemo(() => ({ token, me: me.data, signIn, signOut, notice }), [token, me.data, signIn, signOut, notice])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}

export function RequireAuth({ children }: { children: ReactNode }) {
  const { token, me } = useAuth()
  const location = useLocation()
  if (!token) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (me?.mustChangePassword && location.pathname !== '/change-password') return <Navigate to="/change-password" replace />
  return children
}
