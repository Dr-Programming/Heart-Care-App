import type { ReactNode } from 'react'

export interface Column<T> {
  header: string
  cell: (row: T) => ReactNode
  align?: 'left' | 'right'
  className?: string
}

/** A plain, scrollable table. Numbers align right so magnitudes compare at a glance. */
export function DataTable<T>({
  rows,
  columns,
  rowKey,
  empty,
}: {
  rows: T[]
  columns: Column<T>[]
  rowKey: (row: T, index: number) => string
  empty: string
}) {
  if (rows.length === 0) {
    return <p className="text-sm text-faint">{empty}</p>
  }
  return (
    <div className="-mx-4 overflow-x-auto sm:mx-0">
      <table className="w-full min-w-[560px] border-collapse text-sm">
        <thead>
          <tr className="border-b border-line text-left text-muted">
            {columns.map((c) => (
              <th
                key={c.header}
                scope="col"
                className={`px-4 py-2 font-normal sm:px-3 ${c.align === 'right' ? 'text-right' : ''}`}
              >
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={rowKey(row, i)} className="border-b border-line/60 last:border-0">
              {columns.map((c) => (
                <td
                  key={c.header}
                  className={`px-4 py-2 align-top sm:px-3 ${c.align === 'right' ? 'text-right' : ''} ${c.className ?? ''}`}
                >
                  {c.cell(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
