const UNITS = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB']

export function bytes(n, digits) {
  n = Number(n) || 0
  let i = 0
  const neg = n < 0
  n = Math.abs(n)
  while (n >= 1024 && i < UNITS.length - 1) { n /= 1024; i++ }
  const d = digits ?? (i === 0 ? 0 : n >= 100 ? 0 : n >= 10 ? 1 : 2)
  return (neg ? '-' : '') + n.toFixed(d) + ' ' + UNITS[i]
}

export const rate = n => bytes(n) + '/s'

// Compact axis labels: 1.2G, 340M.
export function shortBytes(n) {
  n = Number(n) || 0
  const u = ['', 'K', 'M', 'G', 'T']
  let i = 0
  while (Math.abs(n) >= 1024 && i < u.length - 1) { n /= 1024; i++ }
  return (Math.abs(n) >= 10 || i === 0 ? Math.round(n) : n.toFixed(1)) + u[i]
}

export function datetime(ms) {
  if (!ms) return '—'
  return new Date(Number(ms)).toLocaleString('zh-CN', { hour12: false, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

export function shortTime(ms, withDate) {
  if (!ms) return '—'
  const d = new Date(Number(ms))
  const opts = withDate ? { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false } : { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false }
  return d.toLocaleString('zh-CN', opts)
}

export function ago(ms) {
  if (!ms) return '—'
  const s = Math.round((Date.now() - Number(ms)) / 1000)
  if (s < 5) return '刚刚'
  if (s < 60) return s + ' 秒前'
  if (s < 3600) return Math.floor(s / 60) + ' 分钟前'
  if (s < 86400) return Math.floor(s / 3600) + ' 小时前'
  return Math.floor(s / 86400) + ' 天前'
}

export function duration(seconds) {
  seconds = Math.max(0, Math.round(seconds))
  if (seconds < 60) return seconds + ' 秒'
  if (seconds < 3600) return Math.floor(seconds / 60) + ' 分 ' + (seconds % 60) + ' 秒'
  if (seconds < 86400) return Math.floor(seconds / 3600) + ' 小时 ' + Math.floor(seconds % 3600 / 60) + ' 分'
  return Math.floor(seconds / 86400) + ' 天 ' + Math.floor(seconds % 86400 / 3600) + ' 小时'
}

export const num = n => (Number(n) || 0).toLocaleString('zh-CN')

export function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}

export const inboundTag = s => String(s || '').split('/').pop()

// Public node ports as "TCP 443、UDP 443"; older backends only send `ports` (all TCP).
export function endpointText(firewall) {
  const list = (firewall && firewall.endpoints) || ((firewall && firewall.ports) || []).map(port => ({ proto: 'tcp', port }))
  return list.map(e => e.proto.toUpperCase() + ' ' + e.port).join('、')
}
