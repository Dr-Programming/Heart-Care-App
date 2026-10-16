type Status =
  | 'OPERATIONAL'
  | 'DEGRADED'
  | 'OFFLINE'
  | 'RUNNING'
  | 'DOWN'
  | 'UNKNOWN'
  | 'ONLINE'
  | 'UNREACHABLE'
  | 'NOT_ENABLED'

const STYLES: Record<Status, { dot: string; text: string; label: string }> = {
  OPERATIONAL: { dot: 'bg-ok', text: 'text-ok', label: 'Operational' },
  RUNNING: { dot: 'bg-ok', text: 'text-ok', label: 'Running' },
  ONLINE: { dot: 'bg-ok', text: 'text-ok', label: 'Online' },
  DEGRADED: { dot: 'bg-warn', text: 'text-warn', label: 'Degraded' },
  UNKNOWN: { dot: 'bg-faint', text: 'text-muted', label: 'Unknown' },
  // An optional source that is deliberately off: neutral, not an alarm.
  NOT_ENABLED: { dot: 'bg-faint', text: 'text-muted', label: 'Not enabled' },
  OFFLINE: { dot: 'bg-crit', text: 'text-crit', label: 'Offline' },
  DOWN: { dot: 'bg-crit', text: 'text-crit', label: 'Down' },
  UNREACHABLE: { dot: 'bg-crit', text: 'text-crit', label: 'Unreachable' },
}

/** Colour plus a word, never colour alone, so status reads for colour-blind viewers too. */
export function StatusIndicator({ status, size = 'md' }: { status: Status; size?: 'md' | 'lg' }) {
  const s = STYLES[status]
  const pulse = status === 'OPERATIONAL' || status === 'ONLINE'
  return (
    <span className={`inline-flex items-center gap-2 font-bold ${s.text} ${size === 'lg' ? 'text-xl' : 'text-sm'}`}>
      <span
        aria-hidden
        className={`inline-block rounded-full ${s.dot} ${pulse ? 'live-dot' : ''} ${size === 'lg' ? 'size-3.5' : 'size-2.5'}`}
      />
      {s.label}
    </span>
  )
}
