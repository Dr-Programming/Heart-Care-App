import type { ReactNode } from 'react'
import { ApiError } from '../api/client'

export function Pager({
  page,
  totalPages,
  totalElements,
  onPage,
  noun,
}: {
  page: number
  totalPages: number
  totalElements: number
  onPage: (page: number) => void
  /** Plural noun; singularized for a count of one. */
  noun: string
}) {
  if (totalElements === 0) return null
  return (
    <nav aria-label="Pagination" className="mt-3 flex items-center justify-between gap-4 text-[14px] text-muted">
      <span className="num">
        {totalElements.toLocaleString()} {totalElements === 1 ? noun.replace(/ies$/, 'y').replace(/s$/, '') : noun}
        {totalPages > 1 && `, page ${page + 1} of ${totalPages}`}
      </span>
      {totalPages > 1 && (
        <div className="flex gap-2">
          <PagerButton disabled={page === 0} onClick={() => onPage(page - 1)}>
            Previous
          </PagerButton>
          <PagerButton disabled={page + 1 >= totalPages} onClick={() => onPage(page + 1)}>
            Next
          </PagerButton>
        </div>
      )}
    </nav>
  )
}

function PagerButton({ disabled, onClick, children }: { disabled: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="rounded-md bg-surface px-3 py-1.5 font-bold text-ink ring-1 ring-line hover:ring-line-strong disabled:cursor-not-allowed disabled:opacity-40"
    >
      {children}
    </button>
  )
}

const fieldClass =
  'rounded-md bg-surface px-2.5 py-1.5 text-[14px] text-ink ring-1 ring-line hover:ring-line-strong focus:ring-heart focus:outline-none'

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-[13px] text-muted">
      {label}
      {children}
    </label>
  )
}

export function Select<T extends string>({
  label,
  value,
  onChange,
  options,
}: {
  label: string
  value: T | ''
  onChange: (value: T | '') => void
  options: { value: T | ''; label: string }[]
}) {
  return (
    <Field label={label}>
      <select className={fieldClass} value={value} onChange={(e) => onChange(e.target.value as T | '')}>
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </Field>
  )
}

export function DateRange({
  from,
  to,
  onChange,
}: {
  from: string
  to: string
  onChange: (range: { from: string; to: string }) => void
}) {
  return (
    <>
      <Field label="From">
        <input type="date" className={fieldClass} value={from} max={to || undefined} onChange={(e) => onChange({ from: e.target.value, to })} />
      </Field>
      <Field label="To">
        <input type="date" className={fieldClass} value={to} min={from || undefined} onChange={(e) => onChange({ from, to: e.target.value })} />
      </Field>
    </>
  )
}

export function FilterBar({ children, onReset, active }: { children: ReactNode; onReset: () => void; active: boolean }) {
  return (
    <div className="mb-3 flex flex-wrap items-end gap-3">
      {children}
      {active && (
        <button type="button" onClick={onReset} className="py-1.5 text-[14px] text-muted underline underline-offset-2 hover:text-ink">
          Clear filters
        </button>
      )}
    </div>
  )
}

export function ErrorNote({ error }: { error: unknown }) {
  const message =
    error instanceof ApiError ? error.message : 'Something went wrong loading this data. Reload the page to try again.'
  return (
    <div role="alert" className="rounded-lg bg-heart-soft px-4 py-3 text-heart">
      {message}
    </div>
  )
}

export function SearchInput({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  return (
    <input
      type="search"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      aria-label={placeholder}
      className={`${fieldClass} w-full max-w-sm py-2`}
    />
  )
}
