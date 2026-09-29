import type { Frequency, VitalType } from '../api/types'

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

export const VITAL_LABEL: Record<VitalType, string> = {
  BLOOD_PRESSURE: 'Blood pressure',
  GLUCOSE: 'Glucose',
  HEART_RATE: 'Heart rate',
  WEIGHT: 'Weight',
  CHOLESTEROL: 'Cholesterol',
}

const UNITS: Record<string, string> = {
  systolic: 'mmHg',
  diastolic: 'mmHg',
  glucose: 'mmol/L',
  ldl: 'mmol/L',
  hdl: 'mmol/L',
  total: 'mmol/L',
  weight: 'kg',
  heartRate: 'bpm',
  bpm: 'bpm',
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

/** Reading as a clinician would say it: "190/100 mmHg", "5.5 mmol/L", "72 kg · BMI 24.9". */
export function vitalReading(type: VitalType, values: Record<string, number>): { main: string; extra?: string } {
  if (type === 'BLOOD_PRESSURE' && values.systolic != null && values.diastolic != null) {
    return { main: `${values.systolic}/${values.diastolic} mmHg` }
  }
  if (type === 'WEIGHT' && values.weight != null) {
    return { main: `${values.weight} kg`, extra: values.bmi != null ? `BMI ${values.bmi}` : undefined }
  }
  const entries = Object.entries(values)
  if (entries.length === 1) {
    const [k, v] = entries[0]
    return { main: `${v} ${UNITS[k] ?? ''}`.trim() }
  }
  return {
    main: entries.map(([k, v]) => `${humanize(k)} ${v}${UNITS[k] ? ` ${UNITS[k]}` : ''}`).join(', '),
  }
}

export const FREQUENCY_LABEL: Record<Frequency, string> = {
  ONCE_DAILY: 'Once daily',
  BID: 'Twice daily',
  TID: 'Three times daily',
  CUSTOM: 'Custom schedule',
}

export const LANGUAGE_LABEL: Record<string, string> = { en: 'English', am: 'Amharic' }
