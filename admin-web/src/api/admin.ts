import { request } from './client'
import type {
  Activity,
  AdminMe,
  Dose,
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
}
