// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import { Outlet } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { Sidebar } from '../components/Sidebar'
import { StatusIndicator } from '../components/StatusIndicator'
import { useDemoCurrent, useOverview } from '../hooks/useMonitoring'
import { fmtClock } from '../lib/format'

/** The status strip stays on every page, so system health is never more than a glance away. */
function StatusStrip() {
  const { data, dataUpdatedAt, isError } = useOverview()
  const { data: demo } = useDemoCurrent()
  const status = isError ? 'OFFLINE' : data?.systemStatus
  return (
    <div className="flex flex-wrap items-center gap-x-8 gap-y-2 text-sm">
      <span className="flex items-center gap-2">
        <span className="text-muted">System</span>
        {status ? <StatusIndicator status={status} /> : <span className="text-faint">Checking…</span>}
      </span>
      <span>
        <span className="text-muted">Environment </span>
        <span className="font-bold">{demo ? `Demonstration running: ${demo.label}` : 'Demonstration'}</span>
      </span>
      <span>
        <span className="text-muted">Last updated </span>
        <span className="font-bold">{dataUpdatedAt ? fmtClock(dataUpdatedAt) : '—'}</span>
      </span>
    </div>
  )
}

export function ConsoleLayout() {
  const { signOut } = useAuth()
  return (
    <div className="min-h-screen">
      <header className="border-b border-line bg-night/95 px-4 py-4 sm:px-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <img src="/favicon.svg" alt="" className="size-8" />
            <p className="text-xl font-bold tracking-tight">System Control Centre</p>
          </div>
          <StatusStrip />
          <button
            type="button"
            onClick={() => signOut()}
            className="rounded-md border border-line px-3 py-1.5 text-sm text-muted hover:border-line-strong hover:text-ink"
          >
            Sign out
          </button>
        </div>
      </header>
      <div className="lg:grid lg:grid-cols-[220px_minmax(0,1fr)]">
        <aside className="border-b border-line px-4 py-3 sm:px-6 lg:min-h-[calc(100vh-73px)] lg:border-r lg:border-b-0 lg:px-3 lg:py-6">
          <Sidebar />
        </aside>
        <main className="min-w-0 px-4 py-6 sm:px-6 lg:px-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
