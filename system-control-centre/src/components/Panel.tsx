import type { ReactNode } from 'react'

/** A titled region of a page. The title says what the numbers inside are, in plain words. */
export function Panel({
  title,
  aside,
  children,
  className = '',
}: {
  title: string
  aside?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className={`min-w-0 rounded-lg border border-line bg-surface ${className}`}>
      <header className="flex flex-wrap items-baseline justify-between gap-2 border-b border-line px-4 py-3 sm:px-5">
        <h2 className="font-bold">{title}</h2>
        {aside && <div className="text-sm text-muted">{aside}</div>}
      </header>
      <div className="p-4 sm:p-5">{children}</div>
    </section>
  )
}

export function PageTitle({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="mb-6">
      <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
      {children && <p className="mt-1 max-w-[70ch] text-muted">{children}</p>}
    </div>
  )
}
