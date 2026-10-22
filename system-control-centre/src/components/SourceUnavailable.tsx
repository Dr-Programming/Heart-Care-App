// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import type { ReactNode } from 'react'
import { ApiError } from '../services/client'

/** Shown in place of a section whose metrics source is not reporting. Says what to do about it. */
export function SourceUnavailable({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-lg border border-dashed border-line-strong bg-night/40 p-4 text-sm">
      <p className="font-bold text-warn">{title}</p>
      <div className="mt-1 max-w-[70ch] text-muted">{children}</div>
    </div>
  )
}

/** Loading and error handling shared by every page. */
export function QueryState({ isLoading, error }: { isLoading: boolean; error: unknown }) {
  if (isLoading) {
    return (
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3" aria-busy="true" aria-label="Loading metrics">
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} className="h-32 animate-pulse rounded-lg border border-line bg-surface" />
        ))}
      </div>
    )
  }
  if (error) {
    const message = error instanceof ApiError ? error.message : 'The metrics could not be loaded.'
    return (
      <SourceUnavailable title="Metrics unavailable">
        {message} The page retries automatically every few seconds.
      </SourceUnavailable>
    )
  }
  return null
}
