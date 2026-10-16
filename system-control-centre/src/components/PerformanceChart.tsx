import { useMemo } from 'react'
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { clientName, fmtClock } from '../lib/format'
import { seriesColour } from '../lib/tone'
import type { ChartSeries } from '../services/types'

interface Props {
  series: ChartSeries[]
  format: (v: number) => string
  height?: number
  /** Map raw series names (e.g. "mobile") to legend labels. */
  label?: (name: string) => string
  /** Pin the y axis to 0–100 for percentages. */
  percent?: boolean
}

/** Time-series line chart. Merges every series onto one time axis. */
export function PerformanceChart({ series, format, height = 240, label = clientName, percent = false }: Props) {
  const rows = useMemo(() => {
    const byTime = new Map<number, Record<string, number | null>>()
    for (const s of series) {
      for (const p of s.points) {
        const row = byTime.get(p.t) ?? { t: p.t }
        row[s.name] = p.v
        byTime.set(p.t, row)
      }
    }
    return [...byTime.values()].sort((a, b) => (a.t as number) - (b.t as number))
  }, [series])

  if (rows.length === 0) {
    return (
      <div className="flex items-center justify-center rounded border border-dashed border-line text-sm text-faint" style={{ height }}>
        No data in this window yet. The chart fills in as traffic arrives.
      </div>
    )
  }

  return (
    <div style={{ height }} className="min-w-0">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: 0 }}>
          <CartesianGrid stroke="var(--line)" vertical={false} />
          <XAxis
            dataKey="t"
            type="number"
            scale="time"
            domain={['dataMin', 'dataMax']}
            tickFormatter={(t: number) => fmtClock(t).slice(0, 5)}
            stroke="var(--faint)"
            tick={{ fill: 'var(--muted)', fontSize: 12 }}
            minTickGap={40}
          />
          <YAxis
            width={64}
            domain={percent ? [0, 100] : [0, 'auto']}
            tickFormatter={(v: number) => format(v)}
            stroke="var(--faint)"
            tick={{ fill: 'var(--muted)', fontSize: 12 }}
          />
          <Tooltip
            contentStyle={{ background: 'var(--surface-raised)', border: '1px solid var(--line-strong)', borderRadius: 6 }}
            labelStyle={{ color: 'var(--muted)' }}
            labelFormatter={(t) => fmtClock(Number(t))}
            formatter={(v, name) => [typeof v === 'number' ? format(v) : '—', label(String(name))]}
          />
          {series.length > 1 && (
            <Legend formatter={(name: string) => <span className="text-sm text-muted">{label(name)}</span>} />
          )}
          {series.map((s, i) => (
            <Line
              key={s.name}
              dataKey={s.name}
              type="monotone"
              stroke={seriesColour(s.name, i)}
              strokeWidth={2}
              dot={false}
              connectNulls
              isAnimationActive={false}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
