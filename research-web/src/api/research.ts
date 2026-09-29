import { downloadCsv, request } from './client'
import type {
  AdherenceResult,
  Catalog,
  CohortDefinition,
  CohortPreview,
  CorrelationResult,
  Dataset,
  DescribeResult,
  GroupBy,
  LoginResult,
  Me,
  Period,
  RecordsPage,
  SavedCohort,
  SeverityResult,
  TrendResult,
  Unit,
} from './types'

export interface Range {
  from?: string
  to?: string
}

export interface DescribeBody extends Range {
  metric: string
  cohort?: CohortDefinition
  unit?: Unit
  groupBy?: GroupBy
  bins?: number
}

export interface TrendBody extends Range {
  metric: string
  period: Period
  cohorts: { label: string; definition: CohortDefinition }[]
}

export interface CorrelationBody extends Range {
  metricX: string
  metricY: string
  cohort?: CohortDefinition
}

export const researchApi = {
  login: (username: string, password: string) =>
    request<LoginResult>('/research/auth/login', { method: 'POST', body: { username, password }, auth: false }),
  me: () => request<Me>('/research/auth/me'),
  changePassword: (currentPassword: string, newPassword: string) =>
    request<Me>('/research/auth/change-password', { method: 'POST', body: { currentPassword, newPassword } }),

  catalog: () => request<Catalog>('/research/catalog'),

  cohorts: () => request<SavedCohort[]>('/research/cohorts'),
  saveCohort: (name: string, definition: CohortDefinition) =>
    request<SavedCohort>('/research/cohorts', { method: 'POST', body: { name, definition } }),
  deleteCohort: (id: string) => request<void>(`/research/cohorts/${id}`, { method: 'DELETE' }),
  previewCohort: (definition: CohortDefinition, range: Range) =>
    request<CohortPreview>('/research/cohorts/preview', { method: 'POST', body: { definition, ...range } }),

  describe: (body: DescribeBody) => request<DescribeResult>('/research/analytics/describe', { method: 'POST', body }),
  trend: (body: TrendBody) => request<TrendResult>('/research/analytics/trend', { method: 'POST', body }),
  adherence: (body: Range & { cohort?: CohortDefinition }) =>
    request<AdherenceResult>('/research/analytics/adherence-outcomes', { method: 'POST', body }),
  correlation: (body: CorrelationBody) =>
    request<CorrelationResult>('/research/analytics/correlation', { method: 'POST', body }),
  severity: (body: Range & { period: Period; cohort?: CohortDefinition }) =>
    request<SeverityResult>('/research/analytics/severity', { method: 'POST', body }),
  records: (dataset: Dataset, body: Range & { cohort?: CohortDefinition; page?: number; size?: number }) =>
    request<RecordsPage>(`/research/records/${dataset.toLowerCase()}`, { method: 'POST', body }),

  /** Same body as the JSON call; the server checks the export permission and logs the download. */
  exportCsv: (path: string, body: unknown) => downloadCsv(`/research/${path}`, body),
}
