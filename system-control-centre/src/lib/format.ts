const DASH = '—'

const integer = new Intl.NumberFormat('en-GB', { maximumFractionDigits: 0 })
const oneDecimal = new Intl.NumberFormat('en-GB', { maximumFractionDigits: 1, minimumFractionDigits: 1 })

export const isNum = (v: number | null | undefined): v is number => typeof v === 'number' && Number.isFinite(v)

export function fmtInt(v: number | null | undefined): string {
  return isNum(v) ? integer.format(v) : DASH
}

export function fmtDecimal(v: number | null | undefined): string {
  return isNum(v) ? oneDecimal.format(v) : DASH
}

export function fmtPercent(v: number | null | undefined): string {
  return isNum(v) ? `${oneDecimal.format(v)}%` : DASH
}

export function fmtMs(v: number | null | undefined): string {
  if (!isNum(v)) return DASH
  return v >= 1000 ? `${oneDecimal.format(v / 1000)} s` : `${integer.format(v)} ms`
}

export function fmtRate(v: number | null | undefined): string {
  if (!isNum(v)) return DASH
  return v < 10 ? `${v.toFixed(2)}/s` : `${integer.format(v)}/s`
}

export function fmtBytes(v: number | null | undefined): string {
  if (!isNum(v)) return DASH
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let value = v
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit++
  }
  return `${unit === 0 ? integer.format(value) : oneDecimal.format(value)} ${units[unit]}`
}

export function fmtBytesPerSec(v: number | null | undefined): string {
  return isNum(v) ? `${fmtBytes(v)}/s` : DASH
}

export function fmtClock(iso: string | number | null | undefined): string {
  if (iso === null || iso === undefined) return DASH
  return new Date(iso).toLocaleTimeString('en-GB', { hour12: false })
}

export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return DASH
  return new Date(iso).toLocaleString('en-GB', { hour12: false, dateStyle: 'medium', timeStyle: 'medium' })
}

export function fmtDuration(seconds: number | null | undefined): string {
  if (!isNum(seconds)) return DASH
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) return `${h} h ${m} min`
  if (m > 0) return `${m} min ${s.toString().padStart(2, '0')} s`
  return `${s} s`
}

/** Human names for the backend's `client` tag. */
export const CLIENT_NAMES: Record<string, string> = {
  admin: 'Admin',
  researcher: 'Researcher',
  mobile: 'Mobile',
  public: 'Public',
  other: 'Other',
  total: 'All traffic',
}

export const clientName = (c: string) => CLIENT_NAMES[c] ?? c
