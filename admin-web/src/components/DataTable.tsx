import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
  type RowData,
  type SortingState,
} from '@tanstack/react-table'
import type { ReactNode } from 'react'

declare module '@tanstack/react-table' {
  interface ColumnMeta<TData extends RowData, TValue> {
    /** Backend field this column sorts by; absent means not sortable. */
    sortKey?: string
    align?: 'right'
    width?: string
  }
}

export type Column<T> = ColumnDef<T, unknown>

interface Props<T> {
  columns: Column<T>[]
  rows: T[] | undefined
  loading?: boolean
  empty: ReactNode
  /** "field,asc|desc" as the backend expects; undefined means the server default. */
  sort?: string
  onSortChange?: (sort: string | undefined) => void
  onRowClick?: (row: T) => void
  rowTone?: (row: T) => 'alert' | undefined
}

function toSorting(sort: string | undefined, columns: Column<unknown>[]): SortingState {
  if (!sort) return []
  const [field, dir] = sort.split(',')
  const col = columns.find((c) => c.meta?.sortKey === field)
  return col?.id ? [{ id: col.id, desc: dir !== 'asc' }] : []
}

/**
 * Server-sorted, server-paged table. Sorting is "manual": clicking a header only reports the
 * new sort upward; the page re-queries the API.
 */
export function DataTable<T>({ columns, rows, loading, empty, sort, onSortChange, onRowClick, rowTone }: Props<T>) {
  const table = useReactTable({
    data: rows ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
    manualSorting: true,
    state: { sorting: toSorting(sort, columns as Column<unknown>[]) },
    enableSortingRemoval: false,
  })

  const cycleSort = (col: Column<T>) => {
    const key = col.meta?.sortKey
    if (!key || !onSortChange) return
    const [field, dir] = (sort ?? '').split(',')
    onSortChange(field === key && dir !== 'asc' ? `${key},asc` : `${key},desc`)
  }

  return (
    <div className="overflow-x-auto rounded-lg bg-surface ring-1 ring-line">
      <table className="w-full border-collapse text-left">
        <thead>
          {table.getHeaderGroups().map((hg) => (
            <tr key={hg.id} className="border-b border-line">
              {hg.headers.map((header) => {
                const col = header.column.columnDef as Column<T>
                const sorted = header.column.getIsSorted()
                const sortable = Boolean(col.meta?.sortKey && onSortChange)
                const label = flexRender(col.header, header.getContext())
                return (
                  <th
                    key={header.id}
                    scope="col"
                    style={{ width: col.meta?.width }}
                    aria-sort={sorted ? (sorted === 'asc' ? 'ascending' : 'descending') : undefined}
                    className={`px-4 py-2.5 text-[13px] font-bold whitespace-nowrap text-muted ${
                      col.meta?.align === 'right' ? 'text-right' : ''
                    }`}
                  >
                    {sortable ? (
                      <button type="button" onClick={() => cycleSort(col)} className="inline-flex items-center gap-1 hover:text-ink">
                        {label}
                        <span aria-hidden className={sorted ? 'text-ink' : 'text-line-strong'}>
                          {sorted === 'asc' ? '▲' : '▼'}
                        </span>
                      </button>
                    ) : (
                      label
                    )}
                  </th>
                )
              })}
            </tr>
          ))}
        </thead>
        <tbody>
          {loading && !rows
            ? Array.from({ length: 6 }, (_, i) => (
                <tr key={i} className="border-b border-line last:border-0">
                  {columns.map((_, j) => (
                    <td key={j} className="px-4 py-3.5">
                      <div className="h-3 w-3/4 animate-pulse rounded bg-line" />
                    </td>
                  ))}
                </tr>
              ))
            : table.getRowModel().rows.map((row) => {
                const alert = rowTone?.(row.original) === 'alert'
                return (
                  <tr
                    key={row.id}
                    onClick={onRowClick ? () => onRowClick(row.original) : undefined}
                    className={`border-b border-line align-top last:border-0 ${
                      onRowClick ? 'cursor-pointer hover:bg-paper' : ''
                    } ${alert ? 'shadow-[inset_3px_0_0_var(--heart)]' : ''}`}
                  >
                    {row.getVisibleCells().map((cell) => {
                      const col = cell.column.columnDef as Column<T>
                      return (
                        <td key={cell.id} className={`px-4 py-3 ${col.meta?.align === 'right' ? 'num text-right' : ''}`}>
                          {flexRender(col.cell, cell.getContext())}
                        </td>
                      )
                    })}
                  </tr>
                )
              })}
        </tbody>
      </table>
      {!loading && rows && rows.length === 0 && <div className="px-4 py-10 text-center text-muted">{empty}</div>}
      {loading && rows && <div className="h-0.5 animate-pulse bg-heart/40" aria-hidden />}
    </div>
  )
}
