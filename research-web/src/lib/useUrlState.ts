import { useCallback } from 'react'
import { useSearchParams } from 'react-router'

/**
 * List state (page, sort, filters) kept in the URL, so a filtered view survives a reload and
 * can be pasted to a colleague. Changing anything other than the page resets to page 0.
 */
export function useUrlState(prefix = '') {
  const [params, setParams] = useSearchParams()

  const get = useCallback((key: string) => params.get(prefix + key) ?? '', [params, prefix])

  const set = useCallback(
    (updates: Record<string, string | number | undefined>) => {
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev)
          for (const [key, value] of Object.entries(updates)) {
            if (value === undefined || value === '' || (key === 'page' && value === 0)) next.delete(prefix + key)
            else next.set(prefix + key, String(value))
          }
          if (!('page' in updates)) next.delete(prefix + 'page')
          return next
        },
        { replace: true },
      )
    },
    [setParams, prefix],
  )

  const clear = useCallback(
    (keys: string[]) => set(Object.fromEntries(keys.map((k) => [k, undefined]))),
    [set],
  )

  return { get, set, clear, page: Number(params.get(prefix + 'page') ?? 0) || 0 }
}
