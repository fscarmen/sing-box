// Same-origin API client. The base path is derived from the page URL, never hard-coded.
export const BASE = new URL('.', location.href).pathname.replace(/\/$/, '')
let csrf = ''

export function setCsrf(token) { csrf = token || csrf }

export class ApiError extends Error {
  constructor(message, status) { super(message); this.status = status }
}

export async function api(path, { method = 'GET', body, params } = {}) {
  let url = BASE + '/' + path.replace(/^\//, '')
  if (params) {
    const q = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') q.set(k, v)
    const s = q.toString()
    if (s) url += (url.includes('?') ? '&' : '?') + s
  }
  const headers = {}
  if (method !== 'GET') { headers['Content-Type'] = 'application/json'; headers['X-CSRF-Token'] = csrf }
  const r = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), cache: 'no-store', credentials: 'same-origin' })
  if (r.status === 401) { location.href = BASE + '/login'; throw new ApiError('登录已过期', 401) }
  let data = null
  try { data = await r.json() } catch { data = null }
  if (!r.ok) throw new ApiError((data && data.error) || '请求失败（' + r.status + '）', r.status)
  if (data && data.csrf) setCsrf(data.csrf)
  return data
}

export const get = (path, params) => api(path, { params })
export const post = (path, body) => api(path, { method: 'POST', body: body || {} })
export const put = (path, body) => api(path, { method: 'PUT', body })
export const exportUrl = (kind, params = {}) => BASE + '/api/export/' + kind + '.csv?' + new URLSearchParams(Object.entries(params).filter(([, v]) => v)).toString()
