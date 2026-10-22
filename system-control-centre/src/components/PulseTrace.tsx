// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

import { useMemo } from 'react'
import { fmtRate, isNum } from '../lib/format'
import type { ChartSeries } from '../services/types'

/**
 * The console's signature: requests per second drawn as a monitor trace on ECG paper. It is the
 * one thing on screen that moves on its own, so the room can see the system is alive at a glance.
 */
export function PulseTrace({ series, current }: { series: ChartSeries | undefined; current: number | null }) {
  const width = 1000
  const height = 120
  const path = useMemo(() => {
    const points = (series?.points ?? []).filter((p) => isNum(p.v))
    if (points.length < 2) return null
    const t0 = points[0].t
    const t1 = points[points.length - 1].t
    const max = Math.max(...points.map((p) => p.v as number), 0.5)
    return points
      .map((p, i) => {
        const x = ((p.t - t0) / Math.max(1, t1 - t0)) * width
        const y = height - 10 - ((p.v as number) / max) * (height - 24)
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`
      })
      .join(' ')
  }, [series])

  return (
    <div className="trace-paper relative overflow-hidden rounded-lg border border-line">
      <div className="absolute top-3 left-4 z-10">
        <p className="text-sm text-muted">Requests per second, last 15 minutes</p>
        <p className="text-3xl font-bold text-ok">{fmtRate(current)}</p>
      </div>
      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="block h-32 w-full sm:h-36" role="img"
        aria-label="Live trace of requests per second over the last 15 minutes">
        {path ? (
          <path
            d={path}
            fill="none"
            stroke="var(--ok)"
            strokeWidth={2.5}
            strokeLinejoin="round"
            vectorEffect="non-scaling-stroke"
            className="trace-line"
            pathLength={4000}
          />
        ) : (
          <line x1={0} x2={width} y1={height - 10} y2={height - 10} stroke="var(--ok)" strokeWidth={2} vectorEffect="non-scaling-stroke" opacity={0.6} />
        )}
      </svg>
    </div>
  )
}
