// Mirrors the backend DTOs in com.heartcare.admin.dto. Dates arrive as ISO strings.

export interface ApiEnvelope<T> {
  success: boolean
  data: T | null
  message: string
  timestamp: string
}

export interface Page<T> {
  items: T[]
  page: number
  size: number
  totalElements: number
  totalPages: number
}

export interface AdminMe {
  id: string
  username: string
  lastLoginAt: string | null
}

export interface LoginResult {
  token: string
  expiresAt: string
  admin: AdminMe
}

export interface DayCount {
  day: string
  count: number
}

export interface Stats {
  totals: {
    users: number
    patientProfiles: number
    medications: number
    doseLogs: number
    vitals: number
    symptoms: number
    activities: number
  }
  newUsersLast7Days: number
  newUsersLast30Days: number
  flaggedVitals: number
  urgentSymptoms: number
  lockedAccounts: number
  signupsPerDay: DayCount[]
  recordsPerDay: DayCount[]
}

export interface RecordCounts {
  medications: number
  doseLogs: number
  vitals: number
  symptoms: number
  activities: number
}

export interface UserSummary {
  id: string
  name: string
  phoneMasked: string
  preferredLanguage: string
  createdAt: string
  locked: boolean
  counts: RecordCounts
}

export interface Goals {
  bpSystolic: number | null
  bpDiastolic: number | null
  totalCholesterol: number | null
  stepsPerDay: number | null
  targetWeightKg: number | null
  dietNote: string | null
}

export interface Profile {
  birthYear: number | null
  preferredLanguage: string | null
  heightCm: number | null
  chdStage: string | null
  diseaseHistory: string | null
  comorbidities: string[]
  managementPlan: string | null
  goals: Goals | null
  createdAt: string
  updatedAt: string
}

export interface UserDetail {
  id: string
  name: string
  phone: string
  preferredLanguage: string
  role: string
  createdAt: string
  failedLoginAttempts: number
  lockedUntil: string | null
  counts: RecordCounts
  profile: Profile | null
}

export type VitalType = 'BLOOD_PRESSURE' | 'GLUCOSE' | 'HEART_RATE' | 'WEIGHT' | 'CHOLESTEROL'
export type Severity = 'NONE' | 'MONITOR' | 'URGENT' | 'EMERGENCY'
export type DoseStatus = 'TAKEN' | 'MISSED' | 'SKIPPED'
export type Frequency = 'ONCE_DAILY' | 'BID' | 'TID' | 'CUSTOM'

export interface Vital {
  id: string
  userId: string
  userName: string | null
  type: VitalType
  values: Record<string, number>
  flagged: boolean
  measuredAt: string
  note: string | null
  createdAt: string
}

export interface Symptom {
  id: string
  userId: string
  userName: string | null
  overallSeverity: Severity
  data: Record<string, unknown>
  assessment: Record<string, unknown>
  measuredAt: string
  note: string | null
  createdAt: string
}

export interface Activity {
  id: string
  userId: string
  userName: string | null
  data: Record<string, unknown>
  measuredAt: string
  note: string | null
  createdAt: string
}

export interface Dose {
  id: string
  userId: string
  userName: string | null
  medicationId: string
  medicationName: string | null
  scheduledDate: string
  scheduledTime: string | null
  status: DoseStatus
  loggedAt: string
  note: string | null
}

export interface Medication {
  id: string
  name: string
  doseMg: number
  frequency: Frequency
  scheduleTimes: string[]
  active: boolean
  createdAt: string
  updatedAt: string
  taken: number
  missed: number
  skipped: number
}

// ---- research access (admin side) -------------------------------------------------------

export type AccessLevel = 'AGGREGATE' | 'PSEUDONYMOUS'
export type Dataset = 'VITALS' | 'SYMPTOMS' | 'ACTIVITY' | 'MEDICATIONS' | 'DEMOGRAPHICS'

export interface Grant {
  accessLevel: AccessLevel
  datasets: Dataset[]
  exportAllowed: boolean
  dataFrom: string | null
  dataTo: string | null
  expiresAt: string | null
  updatedAt?: string
}

export interface Researcher {
  id: string
  username: string
  fullName: string
  organisation: string | null
  status: 'ACTIVE' | 'REVOKED' | 'ARCHIVED'
  expired: boolean
  mustChangePassword: boolean
  canChangePassword: boolean
  passwordChangedAt: string | null
  createdAt: string
  createdBy: string | null
  revokedAt: string | null
  lastLoginAt: string | null
  grant: Grant | null
  archivedAt: string | null
  archivedBy: string | null
  archiveReason: string | null
}

export interface IssuedPassword {
  researcher: Researcher
  password: string
}

export interface ResearchActivity {
  id: number
  researcherId: string | null
  researcherUsername: string | null
  researcherStatus: 'ACTIVE' | 'REVOKED' | 'ARCHIVED' | null
  usernameAttempted: string | null
  occurredAt: string
  method: string
  path: string
  paramsJson: string | null
  status: number
  rowsReturned: number | null
  durationMs: number
  ip: string | null
  userAgent: string | null
}

export interface ResearcherEvent {
  id: number
  researcherId: string
  adminId: string | null
  adminUsername: string | null
  action: 'CREATED' | 'GRANT_UPDATED' | 'REVOKED' | 'RESTORED' | 'PASSWORD_RESET' | 'ARCHIVED' | 'UNARCHIVED'
  detailsJson: string | null
  occurredAt: string
}
