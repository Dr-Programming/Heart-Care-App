import type { ReactNode } from 'react'
import { NavLink, Outlet } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { useCatalog } from '../lib/useCatalog'
import { useTheme } from '../lib/theme'

/** A heart drawn as a scatter of points: the same patients, seen as data. */
export function ResearchMark({ className = 'size-7' }: { className?: string }) {
  const dots = [
    [9, 9], [13, 7.5], [16, 11], [19, 7.5], [23, 9], [7, 13], [25, 13], [9, 17.5], [23, 17.5], [12, 21], [20, 21], [16, 24.5],
  ]
  return (
    <svg viewBox="0 0 32 32" className={className} aria-hidden>
      <rect width="32" height="32" rx="7" fill="var(--accent)" />
      {dots.map(([x, y]) => (
        <circle key={`${x}-${y}`} cx={x} cy={y} r="1.7" fill="#fff" />
      ))}
      <circle cx="16" cy="15.5" r="2.3" fill="#fff" />
    </svg>
  )
}

function NavItem({ to, children }: { to: string; children: ReactNode }) {
  return (
    <NavLink
      to={to}
      end={to === '/'}
      className={({ isActive }) =>
        `block rounded-md px-3 py-2 text-[15px] ${isActive ? 'bg-surface font-bold text-ink ring-1 ring-line' : 'text-muted hover:text-ink'}`
      }
    >
      {children}
    </NavLink>
  )
}

export function Layout() {
  const { signOut, me } = useAuth()
  const { theme, toggle } = useTheme()
  const catalog = useCatalog()

  return (
    <div className="min-h-screen md:grid md:grid-cols-[232px_1fr]">
      <aside className="border-b border-line px-4 py-4 md:sticky md:top-0 md:flex md:h-screen md:flex-col md:border-r md:border-b-0 md:py-6">
        <div className="mb-6 flex items-center gap-2.5 px-1">
          <ResearchMark />
          <div className="leading-tight">
            <div className="text-[17px] font-bold">Libu Care Research</div>
            <div className="text-[13px] text-muted">Anonymised patient data</div>
          </div>
        </div>
        <nav aria-label="Main" className="flex flex-wrap gap-1 md:flex-col">
          <NavItem to="/">Your access</NavItem>
          <NavItem to="/cohorts">Cohorts</NavItem>
          <NavItem to="/explore">Explore a measure</NavItem>
          <NavItem to="/trends">Trends</NavItem>
          <NavItem to="/outcomes">Outcomes</NavItem>
          {catalog.data?.accessLevel === 'PSEUDONYMOUS' && <NavItem to="/records">Records</NavItem>}
          <NavItem to="/account">Account</NavItem>
        </nav>
        <div className="mt-4 flex items-center justify-between gap-2 border-t border-line pt-4 text-[14px] md:mt-auto md:flex-col md:items-stretch">
          <div className="px-1 text-muted">
            Signed in as <span className="font-bold text-ink">{me?.username ?? '…'}</span>
          </div>
          <div className="flex gap-2">
            <button type="button" onClick={toggle} className="rounded-md px-3 py-1.5 text-muted ring-1 ring-line hover:text-ink"
              aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`}>
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
      {children && <p className="mt-1 max-w-[72ch] text-muted">{children}</p>}
    </header>
  )
}
