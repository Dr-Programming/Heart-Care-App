import { useQuery } from '@tanstack/react-query'
import { monitoringApi } from '../services/monitoringApi'
import type { HistoryMetric, HistoryRange } from '../services/types'

/**
 * The one place polling is configured. Each section is a single request on its own interval, so
 * an open dashboard costs a handful of requests every few seconds, not one per card. TanStack
 * Query shares a query between every component that uses it and pauses polling while the tab
 * is hidden (refetchIntervalInBackground defaults to false).
 */
export const REFRESH = {
  overview: 5_000,
  apiPerformance: 5_000,
  database: 10_000,
  infrastructure: 5_000,
  network: 5_000,
  activity: 5_000,
  history: 10_000,
  demo: 5_000,
} as const

const live = (interval: number) => ({ refetchInterval: interval, staleTime: interval / 2 })

export const useOverview = () =>
  useQuery({ queryKey: ['overview'], queryFn: monitoringApi.overview, ...live(REFRESH.overview) })

export const useApiPerformance = () =>
  useQuery({ queryKey: ['api-performance'], queryFn: monitoringApi.apiPerformance, ...live(REFRESH.apiPerformance) })

export const useDatabase = () =>
  useQuery({ queryKey: ['database'], queryFn: monitoringApi.database, ...live(REFRESH.database) })

export const useInfrastructure = () =>
  useQuery({ queryKey: ['infrastructure'], queryFn: monitoringApi.infrastructure, ...live(REFRESH.infrastructure) })

export const useNetwork = () =>
  useQuery({ queryKey: ['network'], queryFn: monitoringApi.network, ...live(REFRESH.network) })

export const useActivity = () =>
  useQuery({ queryKey: ['activity'], queryFn: monitoringApi.activity, ...live(REFRESH.activity) })

export const useHistory = (metric: HistoryMetric, range: HistoryRange) =>
  useQuery({
    queryKey: ['history', metric, range],
    queryFn: () => monitoringApi.history(metric, range),
    ...live(REFRESH.history),
  })

export const useDemoCurrent = () =>
  useQuery({ queryKey: ['demo', 'current'], queryFn: monitoringApi.demoCurrent, ...live(REFRESH.demo) })

export const useDemoSessions = () =>
  useQuery({ queryKey: ['demo', 'sessions'], queryFn: monitoringApi.demoSessions, staleTime: 30_000 })
