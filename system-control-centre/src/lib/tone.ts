// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import { isNum } from './format'

export type Tone = 'ok' | 'warn' | 'crit' | 'neutral'

/** Classify a value against warn/critical thresholds (higher is worse). */
export function toneFor(v: number | null | undefined, warn: number, crit: number): Tone {
  if (!isNum(v)) return 'neutral'
  if (v >= crit) return 'crit'
  if (v >= warn) return 'warn'
  return 'ok'
}

// Initial thresholds for the demonstration; they colour cards, they are not SLAs.
export const THRESHOLDS = {
  cpu: [70, 90],
  memory: [75, 90],
  disk: [80, 92],
  p95Ms: [800, 2000],
  avgMs: [400, 1000],
  errorRate: [1, 5],
  poolUtilisation: [70, 90],
} as const

export const toneText: Record<Tone, string> = {
  ok: 'text-ok',
  warn: 'text-warn',
  crit: 'text-crit',
  neutral: 'text-ink',
}

/** Chart colours by series name: one hue per app, neutral for totals. */
export const SERIES_COLOURS: Record<string, string> = {
  admin: 'var(--admin)',
  researcher: 'var(--researcher)',
  mobile: 'var(--mobile)',
  public: 'var(--faint)',
  other: 'var(--faint)',
}

const FALLBACK = ['var(--neutral-series)', 'var(--admin)', 'var(--mobile)', 'var(--researcher)', 'var(--warn)']

export function seriesColour(name: string, index: number): string {
  return SERIES_COLOURS[name] ?? FALLBACK[index % FALLBACK.length]
}
