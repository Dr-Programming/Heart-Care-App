import type { ApiEnvelope } from './types'

const BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? '/api/v1'
const TOKEN_KEY = 'libu-research-token'
const EXPIRES_KEY = 'libu-research-expires'

/** The token lives in sessionStorage so a research session never outlives its browser tab. */
export const session = {
  get(): string | null {
    try {
      const token = sessionStorage.getItem(TOKEN_KEY)
      const expires = sessionStorage.getItem(EXPIRES_KEY)
      if (!token || !expires || Date.parse(expires) <= Date.now()) return null
      return token
    } catch {
      return null
    }
  },
  expiresAt(): number | null {
    try {
      const expires = sessionStorage.getItem(EXPIRES_KEY)
      return expires ? Date.parse(expires) : null
    } catch {
      return null
    }
  },
  set(token: string, expiresAt: string) {
    try {
      sessionStorage.setItem(TOKEN_KEY, token)
      sessionStorage.setItem(EXPIRES_KEY, expiresAt)
    } catch {
      /* private mode: the session simply won't survive a reload */
    }
  },
  clear() {
    try {
      sessionStorage.removeItem(TOKEN_KEY)
      sessionStorage.removeItem(EXPIRES_KEY)
    } catch {
      /* nothing to clear */
    }
  },
}

export class ApiError extends Error {
  readonly status: number
  /** Machine-readable reason from the server, e.g. ACCESS_REVOKED or PASSWORD_CHANGE_REQUIRED. */
  readonly code: string | undefined
  constructor(status: number, message: string, code?: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

/** Called for errors the whole app must react to: ended sessions and the forced password change. */
let onAccessProblem: (error: ApiError) => void = () => {}
export function setAccessProblemHandler(handler: (error: ApiError) => void) {
  onAccessProblem = handler
}

function codeOf(envelope: ApiEnvelope<unknown> | null): string | undefined {
  const data = envelope?.data as { code?: unknown } | null | undefined
  return typeof data?.code === 'string' ? data.code : undefined
}

function raise(status: number, envelope: ApiEnvelope<unknown> | null, fallback: string, auth: boolean): never {
  const error = new ApiError(status, envelope?.message ?? fallback, codeOf(envelope))
  if (auth && (status === 401 || error.code === 'PASSWORD_CHANGE_REQUIRED')) onAccessProblem(error)
  throw error
}

type Params = Record<string, string | number | boolean | null | undefined>

function toQuery(params?: Params): string {
  if (!params) return ''
  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') search.set(key, String(value))
  }
  const qs = search.toString()
  return qs ? `?${qs}` : ''
}

export async function request<T>(
  path: string,
  options: { method?: string; body?: unknown; params?: Params; auth?: boolean } = {},
): Promise<T> {
  const { method = 'GET', body, params, auth = true } = options
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (body !== undefined) headers['Content-Type'] = 'application/json'
  const token = session.get()
  if (auth && token) headers.Authorization = `Bearer ${token}`

  let response: Response
  try {
    response = await fetch(`${BASE}${path}${toQuery(params)}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError(0, 'Can’t reach the server. Check that the backend is running.')
  }

  let envelope: ApiEnvelope<T> | null = null
  try {
    envelope = (await response.json()) as ApiEnvelope<T>
  } catch {
    /* non-JSON body, e.g. a proxy error page */
  }

  if (!response.ok || !envelope?.success) {
    raise(response.status, envelope, `Request failed (${response.status})`, auth)
  }
  return envelope.data as T
}

/** Runs an analysis with ?format=csv and hands the file to the browser as a download. */
export async function downloadCsv(path: string, body: unknown): Promise<void> {
  const token = session.get()
  const response = await fetch(`${BASE}${path}?format=csv`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  })
  if (!response.ok) {
    let envelope: ApiEnvelope<unknown> | null = null
    try {
      envelope = (await response.json()) as ApiEnvelope<unknown>
    } catch {
      /* not JSON */
    }
    raise(response.status, envelope, `Download failed (${response.status})`, true)
  }
  const blob = await response.blob()
  const name = /filename="([^"]+)"/.exec(response.headers.get('Content-Disposition') ?? '')?.[1] ?? 'research.csv'
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}
