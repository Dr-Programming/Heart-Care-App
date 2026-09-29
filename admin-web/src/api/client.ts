import type { ApiEnvelope } from './types'

const BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? '/api/v1'
const TOKEN_KEY = 'libu-admin-token'
const EXPIRES_KEY = 'libu-admin-expires'

/**
 * The token lives in sessionStorage, not localStorage: it grants read access to every
 * patient's health record, so it should not outlive the browser tab it was issued to.
 */
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
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

let onUnauthorized: () => void = () => {}
export function setUnauthorizedHandler(handler: () => void) {
  onUnauthorized = handler
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
    if (response.status === 401 && auth) onUnauthorized()
    throw new ApiError(response.status, envelope?.message ?? `Request failed (${response.status})`)
  }
  return envelope.data as T
}

/** Fetches an authenticated file (e.g. CSV) and hands it to the browser as a download. */
export async function download(path: string, params?: Params): Promise<void> {
  const token = session.get()
  const response = await fetch(`${BASE}${path}${toQuery(params)}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  })
  if (!response.ok) {
    if (response.status === 401) onUnauthorized()
    throw new ApiError(response.status, `Download failed (${response.status})`)
  }
  const blob = await response.blob()
  const disposition = response.headers.get('Content-Disposition') ?? ''
  const name = /filename="([^"]+)"/.exec(disposition)?.[1] ?? 'download.csv'
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}
