import { useQuery } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { NavLink, Outlet } from 'react-router'
import { adminApi } from '../api/admin'
import { useAuth } from '../auth/AuthContext'
import { useTheme } from '../lib/theme'

export function HeartMark({ className = 'size-7' }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" className={className} aria-hidden>
      <path
        fill="var(--heart)"
        d="M16 28s-11-6.6-11-14.2C5 9.4 8.1 6.5 11.6 6.5c2 0 3.5 1 4.4 2.5.9-1.5 2.4-2.5 4.4-2.5 3.5 0 6.6 2.9 6.6 7.3C27 21.4 16 28 16 28z"
      />
      <path fill="none" stroke="#fff" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" d="M7 15h5l2-4 3 8 2-4h6" />
    </svg>
  )
}

function NavItem({ to, children, count }: { to: string; children: ReactNode; count?: number }) {
  return (
    <NavLink
      to={to}
      end={to === '/'}
      className={({ isActive }) =>
        `flex items-center justify-between gap-2 rounded-md px-3 py-2 text-[15px] ${
          isActive ? 'bg-surface font-bold text-ink ring-1 ring-line' : 'text-muted hover:text-ink'
        }`
      }
    >
      {children}
      {count !== undefined && count > 0 && (
        <span className="num rounded-full bg-heart px-2 text-[12px] leading-5 font-bold text-white">{count}</span>
      )}
    </NavLink>
  )
}

export function Layout() {
  const { signOut } = useAuth()
  const { theme, toggle } = useTheme()
  const me = useQuery({ queryKey: ['me'], queryFn: adminApi.me, staleTime: Infinity })
  // Shares the dashboard's cache entry, so the triage counts in the sidebar cost nothing extra.
  const stats = useQuery({ queryKey: ['stats'], queryFn: adminApi.stats, staleTime: 60_000 })

  return (
    <div className="min-h-screen md:grid md:grid-cols-[232px_1fr]">
      <aside className="border-b border-line px-4 py-4 md:sticky md:top-0 md:flex md:h-screen md:flex-col md:border-r md:border-b-0 md:py-6">
        <div className="mb-6 flex items-center gap-2.5 px-1">
          <HeartMark />
          <div className="leading-tight">
            <div className="text-[17px] font-bold">Libu Care</div>
            <div className="text-[13px] text-muted">Patient records, read-only</div>
          </div>
        </div>

        <nav aria-label="Main" className="flex flex-wrap gap-1 md:flex-col">
          <NavItem to="/">Overview</NavItem>
          <NavItem to="/patients">Patients</NavItem>
          <NavItem to="/flagged-vitals" count={stats.data?.flaggedVitals}>
            Out-of-range vitals
          </NavItem>
          <NavItem to="/urgent-symptoms" count={stats.data?.urgentSymptoms}>
            Urgent symptoms
          </NavItem>
        </nav>

        <div className="mt-4 flex items-center justify-between gap-2 border-t border-line pt-4 text-[14px] md:mt-auto md:flex-col md:items-stretch">
          <div className="px-1 text-muted">
            Signed in as <span className="font-bold text-ink">{me.data?.username ?? '…'}</span>
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={toggle}
              className="rounded-md px-3 py-1.5 text-muted ring-1 ring-line hover:text-ink"
              aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`}
            >
              {theme === 'dark' ? 'Light theme' : 'Dark theme'}
            </button>
            <button type="button" onClick={() => signOut()} className="rounded-md px-3 py-1.5 text-muted ring-1 ring-line hover:text-ink">
              Sign out
            </button>
          </div>
        </div>
      </aside>

      <main className="min-w-0 px-4 py-6 md:px-10 md:py-8">
        <Outlet />
      </main>
    </div>
  )
}

export function PageHeader({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <header className="mb-6">
      <h1 className="text-[28px] leading-tight font-bold tracking-[-0.01em]">{title}</h1>
      {children && <p className="mt-1 max-w-[70ch] text-muted">{children}</p>}
    </header>
  )
}
