import { useQuery } from '@tanstack/react-query'
import { researchApi } from '../api/research'

/** The grant-scoped catalogue: metrics, datasets, window, k. Shared by every tool page. */
export function useCatalog() {
  return useQuery({ queryKey: ['catalog'], queryFn: researchApi.catalog, staleTime: 60_000 })
}

export function useCohorts() {
  return useQuery({ queryKey: ['cohorts'], queryFn: researchApi.cohorts, staleTime: 60_000 })
}
