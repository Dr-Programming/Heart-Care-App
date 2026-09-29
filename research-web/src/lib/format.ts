const dateTime = new Intl.DateTimeFormat(undefined, {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})
const dateOnly = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
const dayShort = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short' })

export const fmtDateTime = (iso: string | null | undefined) => (iso ? dateTime.format(new Date(iso)) : '—')
export const fmtDate = (iso: string | null | undefined) => (iso ? dateOnly.format(new Date(iso)) : '—')
/** For LocalDate strings ("2026-07-01"): parse as local midnight so the day never shifts. */
export const fmtLocalDate = (d: string | null | undefined) => (d ? dateOnly.format(new Date(`${d}T00:00`)) : '—')
export const fmtDayShort = (d: string) => dayShort.format(new Date(`${d}T00:00`))
export const fmtNumber = (n: number) => n.toLocaleString()

export function fmtRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.round(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours} h ago`
  const days = Math.round(hours / 24)
  if (days < 30) return `${days} d ago`
  return fmtDate(iso)
}

const KEY_LABEL: Record<string, string> = {
  ldl: 'LDL',
  hdl: 'HDL',
  bmi: 'BMI',
  total: 'Total',
}

export function humanize(key: string): string {
  if (KEY_LABEL[key]) return KEY_LABEL[key]
  const spaced = key.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/_/g, ' ').toLowerCase()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

export function humanizeEnum(value: string): string {
  return humanize(value.toLowerCase().replace(/_([a-z])/g, (_, c: string) => c.toUpperCase()))
}
