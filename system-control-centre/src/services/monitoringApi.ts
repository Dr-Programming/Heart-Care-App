import { download, request } from './client'
import type {
  Activity,
  ApiPerformance,
  ChartSeries,
  DatabaseMetrics,
  DemoSession,
  HistoryMetric,
  HistoryRange,
  Infrastructure,
  LoginResponse,
  Network,
  Overview,
} from './types'

export const monitoringApi = {
  login: (username: string, password: string) =>
    request<LoginResponse>('/auth/login', { method: 'POST', body: { username, password }, auth: false }),

  overview: () => request<Overview>('/overview'),
  apiPerformance: () => request<ApiPerformance>('/api-performance'),
  database: () => request<DatabaseMetrics>('/database'),
  infrastructure: () => request<Infrastructure>('/infrastructure'),
  network: () => request<Network>('/network'),
  activity: () => request<Activity>('/activity'),
  history: (metric: HistoryMetric, range: HistoryRange) =>
    request<ChartSeries[]>('/history', { params: { metric, range } }),

  demoCurrent: () => request<DemoSession | null>('/demo/current'),
  demoSessions: () => request<DemoSession[]>('/demo/sessions'),
  demoStart: (label: string, conditions: string) =>
    request<DemoSession>('/demo/start', { method: 'POST', body: { label, conditions } }),
  demoStop: () => request<DemoSession>('/demo/stop', { method: 'POST' }),
  demoExport: (id: string) => download(`/demo/sessions/${encodeURIComponent(id)}/export`, 'scc-demonstration.json'),
}
