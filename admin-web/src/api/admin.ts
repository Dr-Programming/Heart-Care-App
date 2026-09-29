import { download, request } from './client'
import type {
  Activity,
  AdminMe,
  Dose,
  Grant,
  IssuedPassword,
  ResearchActivity,
  Researcher,
  ResearcherEvent,
  DoseStatus,
  LoginResult,
  Medication,
  Page,
  Severity,
  Stats,
  Symptom,
  UserDetail,
  UserSummary,
  Vital,
  VitalType,
} from './types'

export interface PageQuery {
  page?: number
  size?: number
  sort?: string
}

export interface RangeQuery {
  from?: string
  to?: string
}

export const adminApi = {
  login: (username: string, password: string) =>
    request<LoginResult>('/admin/auth/login', { method: 'POST', body: { username, password }, auth: false }),
  me: () => request<AdminMe>('/admin/auth/me'),

  stats: () => request<Stats>('/admin/stats'),

  users: (q: PageQuery & { q?: string }) => request<Page<UserSummary>>('/admin/users', { params: { ...q } }),
  user: (id: string) => request<UserDetail>(`/admin/users/${id}`),
  medications: (id: string) => request<Medication[]>(`/admin/users/${id}/medications`),
  doseLogs: (id: string, q: PageQuery & RangeQuery & { status?: DoseStatus; medicationId?: string }) =>
    request<Page<Dose>>(`/admin/users/${id}/dose-logs`, { params: { ...q } }),
  userVitals: (id: string, q: PageQuery & RangeQuery & { type?: VitalType; flagged?: boolean }) =>
    request<Page<Vital>>(`/admin/users/${id}/vitals`, { params: { ...q } }),
  userSymptoms: (id: string, q: PageQuery & RangeQuery & { minSeverity?: Severity }) =>
    request<Page<Symptom>>(`/admin/users/${id}/symptoms`, { params: { ...q } }),
  userActivities: (id: string, q: PageQuery & RangeQuery) =>
    request<Page<Activity>>(`/admin/users/${id}/activities`, { params: { ...q } }),

  flaggedVitals: (q: PageQuery & RangeQuery & { type?: VitalType }) =>
    request<Page<Vital>>('/admin/vitals', { params: { ...q, flagged: true } }),
  urgentSymptoms: (q: PageQuery & RangeQuery & { minSeverity?: Severity }) =>
    request<Page<Symptom>>('/admin/symptoms', { params: { ...q } }),

  researchers: () => request<Researcher[]>('/admin/researchers'),
  researcher: (id: string) => request<Researcher>(`/admin/researchers/${id}`),
  archivedResearchers: () => request<Researcher[]>('/admin/researchers/archive'),
  archiveResearcher: (id: string, reason: string) =>
    request<Researcher>(`/admin/researchers/${id}/archive`, { method: 'POST', body: { reason } }),
  unarchiveResearcher: (id: string) => request<Researcher>(`/admin/researchers/${id}/unarchive`, { method: 'POST' }),
  createResearcher: (body: { username: string; fullName: string; organisation: string; grant: Grant }) =>
    request<IssuedPassword>('/admin/researchers', { method: 'POST', body }),
  updateGrant: (id: string, grant: Grant) => request<Researcher>(`/admin/researchers/${id}/grant`, { method: 'PUT', body: grant }),
  revokeResearcher: (id: string) => request<Researcher>(`/admin/researchers/${id}/revoke`, { method: 'POST' }),
  restoreResearcher: (id: string) => request<Researcher>(`/admin/researchers/${id}/restore`, { method: 'POST' }),
  resetResearcherPassword: (id: string) => request<IssuedPassword>(`/admin/researchers/${id}/reset-password`, { method: 'POST' }),
  researcherEvents: (id: string) => request<ResearcherEvent[]>(`/admin/researchers/${id}/events`),
  researchActivity: (q: ActivityQuery) => request<Page<ResearchActivity>>('/admin/research-activity', { params: { ...q } }),
  downloadResearchActivity: (q: ActivityQuery) => download('/admin/research-activity.csv', { ...q, page: undefined, size: undefined }),
  researchSettings: () => request<{ minGroupSize: number }>('/admin/research-settings'),
  updateResearchSettings: (minGroupSize: number) =>
    request<{ minGroupSize: number }>('/admin/research-settings', { method: 'PUT', body: { minGroupSize } }),
}

export interface ActivityQuery {
  researcherId?: string
  path?: string
  from?: string
  to?: string
  failuresOnly?: boolean
  page?: number
  size?: number
}
