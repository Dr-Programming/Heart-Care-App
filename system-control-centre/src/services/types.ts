// Mirrors the Monitoring API DTOs (monitoring-api/src/main/java/com/heartcare/monitoring/dto).
// Every metric is nullable: null means the source had no data, and the UI shows a dash.

export interface ApiEnvelope<T> {
  success: boolean
  data: T
  message: string
  timestamp: string
}

export type SourceStatus = 'OK' | 'UNAVAILABLE'
export type SystemStatus = 'OPERATIONAL' | 'DEGRADED' | 'OFFLINE'

export interface TimePoint {
  t: number
  v: number | null
}

export interface ChartSeries {
  name: string
  points: TimePoint[]
}

export interface Breakdown {
  name: string
  value: number
}

export interface LoginResponse {
  token: string
  expiresAt: string
  username: string
}

export interface Overview {
  systemStatus: SystemStatus
  statusReasons: string[]
  activeUsers: number | null
  activeUsersByClient: Record<string, number>
  totalRequests: number | null
  requestsPerSecond: number | null
  averageLatencyMs: number | null
  p95LatencyMs: number | null
  errorRatePercent: number | null
  cpuUsagePercent: number | null
  cpuSource: 'windows-host' | 'docker-vm' | null
  memoryUsagePercent: number | null
  sources: Record<string, SourceStatus>
  generatedAt: string
}

export interface EndpointStat {
  method: string
  uri: string
  client: string
  requests: number
  averageLatencyMs: number | null
  errorRatePercent: number | null
}

export interface ApiPerformance {
  totalRequests: number | null
  requestsPerSecond: number | null
  averageLatencyMs: number | null
  p95LatencyMs: number | null
  failedRequests: number | null
  clientErrors: number | null
  successRatePercent: number | null
  errorRatePercent: number | null
  endpoints: EndpointStat[]
  statusCodes: Breakdown[]
  requestsByClient: Breakdown[]
  requestsOverTime: ChartSeries[]
  latencyOverTime: ChartSeries[]
  generatedAt: string
}

export interface QueryStat {
  queryId: string
  query: string
  calls: number | null
  totalTimeMs: number
  meanTimeMs: number | null
}

export interface DatabaseMetrics {
  source: SourceStatus
  databaseName: string
  activeConnections: number | null
  idleConnections: number | null
  idleInTransaction: number | null
  totalConnections: number | null
  maxConnections: number | null
  transactionsPerSecond: number | null
  cacheHitRatioPercent: number | null
  databaseSizeBytes: number | null
  slowQueries: number | null
  slowQueryThresholdMs: number
  deadlocks: number | null
  pool: {
    active: number | null
    idle: number | null
    pending: number | null
    max: number | null
    utilisationPercent: number | null
    averageAcquireMs: number | null
  }
  topQueries: QueryStat[]
  activityOverTime: ChartSeries[]
  generatedAt: string
}

export interface Container {
  name: string
  displayName: string
  status: 'RUNNING' | 'DOWN' | 'UNKNOWN'
  statusSource: string
  cpuPercent: number | null
  memoryBytes: number | null
}

export interface Infrastructure {
  host: {
    source: SourceStatus
    cpuSource: string
    cpuUsagePercent: number | null
    memoryUsagePercent: number | null
    memoryUsedBytes: number | null
    memoryTotalBytes: number | null
    diskUsagePercent: number | null
    diskFreeBytes: number | null
    diskTotalBytes: number | null
    networkReceiveBytesPerSec: number | null
    networkTransmitBytesPerSec: number | null
  }
  containerMetricsSource: SourceStatus
  containers: Container[]
  cpuOverTime: ChartSeries[]
  memoryOverTime: ChartSeries[]
  networkOverTime: ChartSeries[]
  generatedAt: string
}

export interface Network {
  ngrok: {
    status: 'ONLINE' | 'OFFLINE' | 'UNREACHABLE'
    publicUrl: string | null
    requestsThroughTunnel: number | null
    detail: string
  }
  webRequestsPerSecond: number | null
  mobileRequestsPerSecond: number | null
  mobileRequestsTotal: number | null
  mobileFailedRequests: number | null
  mobileClientErrors: number | null
  webFailedRequests: number | null
  hostSource: SourceStatus
  hostReceiveBytesPerSec: number | null
  hostTransmitBytesPerSec: number | null
  requestsByClient: Breakdown[]
  requestsPerSecondByClient: ChartSeries[]
  hostTrafficOverTime: ChartSeries[]
  generatedAt: string
}

export interface ActivityEvent {
  at: string
  client: string
  category: string
  label: string
  outcome: 'success' | 'client_error' | 'server_error'
  durationMs: number
}

export interface Activity {
  source: SourceStatus
  events: ActivityEvent[]
  lastFiveMinutesByClient: Record<string, number>
  generatedAt: string
}

export interface DemoSummary {
  durationSeconds: number
  peakActiveUsers: number | null
  totalRequests: number | null
  successfulRequests: number | null
  failedRequests: number | null
  clientErrors: number | null
  averageLatencyMs: number | null
  p95LatencyMs: number | null
  peakRequestsPerSecond: number | null
  peakCpuPercent: number | null
  cpuSource: string
  peakMemoryPercent: number | null
  peakDatabaseConnections: number | null
  result: 'RUNNING' | 'COMPLETED' | 'COMPLETED_WITH_ERRORS' | 'NO_DATA'
  notes: string[]
  computedAt: string
}

export interface DemoSession {
  id: string
  label: string
  conditions: string
  state: 'RUNNING' | 'COMPLETED'
  startedAt: string
  endedAt: string | null
  baseline: {
    cpuUsagePercent: number | null
    memoryUsagePercent: number | null
    activeUsers: number | null
    totalRequests: number | null
    databaseConnections: number | null
  }
  summary: DemoSummary | null
}

export type HistoryMetric =
  | 'rps'
  | 'latency'
  | 'p95'
  | 'errors'
  | 'cpu'
  | 'memory'
  | 'active_users'
  | 'db_tps'
  | 'db_connections'
export type HistoryRange = '15m' | '1h' | '6h' | '24h' | '7d'
