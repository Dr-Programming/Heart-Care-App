import type { ReactNode } from 'react'
import type { DoseStatus, Severity } from '../api/types'

type Tone = 'heart' | 'calm' | 'amber' | 'neutral'

const TONES: Record<Tone, string> = {
  heart: 'bg-heart-soft text-heart',
  calm: 'bg-calm-soft text-calm',
  amber: 'bg-amber-soft text-amber',
  neutral: 'bg-paper text-muted ring-1 ring-inset ring-line',
}

export function Badge({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[13px] font-bold whitespace-nowrap ${TONES[tone]}`}>
      {children}
    </span>
  )
}

const SEVERITY: Record<Severity, { tone: Tone; label: string }> = {
  NONE: { tone: 'neutral', label: 'No concern' },
  MONITOR: { tone: 'amber', label: 'Monitor' },
  URGENT: { tone: 'heart', label: 'Urgent' },
  EMERGENCY: { tone: 'heart', label: 'Emergency' },
}

export function SeverityBadge({ value }: { value: Severity }) {
  const s = SEVERITY[value] ?? SEVERITY.NONE
  return (
    <Badge tone={s.tone}>
      {value === 'EMERGENCY' && <span aria-hidden className="size-1.5 rounded-full bg-heart" />}
      {s.label}
    </Badge>
  )
}

const DOSE: Record<DoseStatus, { tone: Tone; label: string }> = {
  TAKEN: { tone: 'calm', label: 'Taken' },
  MISSED: { tone: 'heart', label: 'Missed' },
  SKIPPED: { tone: 'amber', label: 'Skipped' },
}

export function DoseBadge({ value }: { value: DoseStatus }) {
  return <Badge tone={DOSE[value].tone}>{DOSE[value].label}</Badge>
}

export function FlagBadge({ flagged }: { flagged: boolean }) {
  return flagged ? <Badge tone="heart">Out of range</Badge> : <Badge tone="calm">In range</Badge>
}
