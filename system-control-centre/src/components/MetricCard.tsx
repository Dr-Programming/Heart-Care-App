// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import type { ReactNode } from 'react'
import { toneText, type Tone } from '../lib/tone'

interface Props {
  label: string
  value: ReactNode
  hint?: ReactNode
  tone?: Tone
  /** "lead" cards carry the numbers judges should read first; "compact" fills supporting rows. */
  size?: 'lead' | 'standard' | 'compact'
}

const valueSize = {
  lead: 'text-5xl sm:text-6xl',
  standard: 'text-4xl',
  compact: 'text-2xl',
}

export function MetricCard({ label, value, hint, tone = 'neutral', size = 'standard' }: Props) {
  return (
    <div className="flex min-w-0 flex-col justify-between gap-3 rounded-lg border border-line bg-surface p-4 sm:p-5">
      <p className="text-sm text-muted">{label}</p>
      <p className={`font-bold leading-none tracking-tight ${valueSize[size]} ${toneText[tone]}`}>{value}</p>
      {hint && <p className="text-sm text-faint">{hint}</p>}
    </div>
  )
}
