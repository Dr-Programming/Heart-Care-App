import { useState } from 'react'
import { humanize, humanizeEnum } from '../lib/format'

function renderValue(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  if (typeof value === 'number') return value.toLocaleString()
  if (typeof value === 'string') return /^[A-Z_]+$/.test(value) ? humanizeEnum(value) : value
  if (Array.isArray(value)) return value.map(renderValue).join(', ')
  if (typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>)
      .map(([k, v]) => `${humanize(k)} ${renderValue(v)}`)
      .join(', ')
  }
  return String(value)
}

/**
 * A JSONB column shown as readable pairs ("Chest pain: present yes, severity 8"), with the raw
 * JSON one click away for when the exact payload matters.
 */
export function KeyValues({ data, highlight }: { data: Record<string, unknown>; highlight?: (key: string) => boolean }) {
  const [raw, setRaw] = useState(false)
  const entries = Object.entries(data ?? {})
  if (entries.length === 0) return <span className="text-faint">Nothing recorded</span>

  return (
    <div className="min-w-0">
      {raw ? (
        <pre className="max-w-md overflow-x-auto rounded-md bg-paper p-2 text-[12px] leading-snug text-ink ring-1 ring-line">
          {JSON.stringify(data, null, 2)}
        </pre>
      ) : (
        <ul className="flex flex-wrap gap-1.5">
          {entries.map(([k, v]) => (
            <li
              key={k}
              className={`rounded-md px-2 py-0.5 text-[13px] ring-1 ring-inset ${
                highlight?.(k) ? 'bg-heart-soft text-heart ring-transparent' : 'ring-line'
              }`}
            >
              <span className="text-muted">{humanize(k)}</span> <span className="num font-bold">{renderValue(v)}</span>
            </li>
          ))}
        </ul>
      )}
      <button
        type="button"
        onClick={() => setRaw((r) => !r)}
        className="mt-1 text-[12px] text-faint underline decoration-line-strong underline-offset-2 hover:text-ink"
      >
        {raw ? 'Show as fields' : 'Show raw JSON'}
      </button>
    </div>
  )
}
