// Mirrors com.heartcare.research DTOs. Dates arrive as ISO strings.

export interface ApiEnvelope<T> {
  success: boolean
  data: T | null
  message: string
  timestamp: string
}

export type AccessLevel = 'AGGREGATE' | 'PSEUDONYMOUS'
export type Dataset = 'VITALS' | 'SYMPTOMS' | 'ACTIVITY' | 'MEDICATIONS' | 'DEMOGRAPHICS'
export type Severity = 'NONE' | 'MONITOR' | 'URGENT' | 'EMERGENCY'
export type DoseStatus = 'TAKEN' | 'MISSED' | 'SKIPPED'

export interface Grant {
  accessLevel: AccessLevel
  datasets: Dataset[]
  exportAllowed: boolean
  dataFrom: string | null
  dataTo: string | null
  expiresAt: string | null
  updatedAt: string
}

export interface Me {
  id: string
  username: string
  fullName: string
  organisation: string | null
  mustChangePassword: boolean
  canChangePassword: boolean
  passwordChangedAt: string | null
  lastLoginAt: string | null
  grant: Grant
  minGroupSize: number
}

export interface LoginResult {
  token: string
  expiresAt: string
  researcher: Me
}

export interface MetricView {
  id: string
  label: string
  unit: string
  dataset: Dataset
  kind: 'MEASURE' | 'RATE'
  group: string
}

export interface Catalog {
  accessLevel: AccessLevel
  datasets: Dataset[]
  exportAllowed: boolean
  dataFrom: string | null
  dataTo: string | null
  expiresAt: string | null
  minGroupSize: number
  metrics: MetricView[]
  cohortFields: {
    ageBands: string[]
    chdStages: string[]
    comorbidities: string[]
    languages: string[]
    medications: string[]
  }
}

export interface CohortDefinition {
  ageBands?: string[]
  chdStages?: string[]
  comorbidities?: string[]
  comorbidityMatch?: 'ANY' | 'ALL'
  languages?: string[]
  medicationName?: string
  hadFlaggedVital?: boolean
  minSymptomSeverity?: Severity
}

export interface SavedCohort {
  id: string
  name: string
  definition: CohortDefinition
  createdAt: string
}

export interface CohortPreview {
  size: number | null
  suppressed: boolean
  k: number
}

export interface WindowView {
  from: string | null
  to: string | null
}

export interface Stats {
  suppressed: boolean
  readings: number | null
  patients: number | null
  mean: number | null
  sd: number | null
  p5: number | null
  p25: number | null
  median: number | null
  p75: number | null
  p95: number | null
}

export interface Bin {
  lo: number
  hi: number
  count: number | null
  suppressed: boolean
}

export type Unit = 'READING' | 'PATIENT'
export type GroupBy = 'NONE' | 'AGE_BAND' | 'CHD_STAGE' | 'LANGUAGE'
export type Period = 'WEEK' | 'MONTH'

export interface DescribeResult {
  metric: MetricView
  unit: Unit
  window: WindowView
  overall: Stats
  histogram: Bin[]
  groupBy: GroupBy
  groups: { group: string; stats: Stats }[]
  k: number
}

export interface TrendPoint {
  period: string
  suppressed: boolean
  mean: number | null
  readings: number | null
  patients: number | null
}

export interface TrendResult {
  metric: MetricView
  period: Period
  window: WindowView
  series: { label: string; points: TrendPoint[] }[]
  k: number
}

export interface AdherenceBand {
  band: string
  suppressed: boolean
  patients: number | null
  meanAdherence: number | null
  patientsWithBp: number | null
  meanSystolic: number | null
  meanDiastolic: number | null
  pctBpOutOfRange: number | null
  pctUrgentCheckins: number | null
}

export interface AdherenceResult {
  window: WindowView
  bands: AdherenceBand[]
  symptomsIncluded: boolean
  k: number
}

export interface CorrelationResult {
  x: MetricView
  y: MetricView
  window: WindowView
  suppressed: boolean
  patients: number | null
  r: number | null
  ciLow: number | null
  ciHigh: number | null
  points: { patient: string; x: number; y: number }[] | null
  grid: { xEdges: number[]; yEdges: number[]; counts: (number | null)[][] } | null
  k: number
}

export interface SeverityResult {
  period: Period
  window: WindowView
  buckets: {
    period: string
    suppressed: boolean
    patients: number | null
    checkins: number | null
    counts: Record<Severity, number> | null
  }[]
  k: number
}

export interface RecordsPage {
  dataset: Dataset
  columns: string[]
  rows: Record<string, unknown>[]
  page: number
  size: number
  totalElements: number
  totalPages: number
}
