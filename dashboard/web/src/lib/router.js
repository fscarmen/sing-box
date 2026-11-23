// Minimal hash router: #/view?key=value. Keeps the page path (and thus the API base) stable.
import { reactive } from 'vue'

export const ROUTES = [
  { name: 'rules', title: '代理规则', group: '管理', icon: 'exits' },
  { name: 'manage', title: '服务器管理', group: '管理', icon: 'system' },
  { name: 'overview', title: '概览', group: '监控', icon: 'overview' },
  { name: 'xray', title: 'Xray 节点', group: '监控', icon: 'exits' },
  { name: 'live', title: '实时连接', xrayTitle: '实时速率', group: '监控', icon: 'live' },
  { name: 'topology', title: '链路拓扑', group: '监控', icon: 'topology' },
  { name: 'map', title: '地理分布', xrayTitle: '出口分布', group: '监控', icon: 'map' },
  { name: 'network', title: '网络质量', xrayTitle: '网络状态', group: '监控', icon: 'network' },
  { name: 'clients', title: '客户端', xrayTitle: '用户与来源', group: '数据', icon: 'clients' },
  { name: 'history', title: '连接历史', xrayTitle: '流量记录', group: '数据', icon: 'history' },
  { name: 'daily', title: '每日流量', group: '数据', icon: 'daily' },
  { name: 'exits', title: '出口节点', group: '管理', icon: 'exits' },
  { name: 'bans', title: '访问控制', group: '管理', icon: 'bans' },
  { name: 'alerts', title: '告警', group: '管理', icon: 'alerts' },
  { name: 'security', title: '会话与审计', group: '管理', icon: 'security' },
  { name: 'system', title: '系统与设置', group: '管理', icon: 'system' },
]

export const route = reactive({ name: 'overview', query: {}, ip: '' })

function parse() {
  const raw = location.hash.replace(/^#\/?/, '')
  const [name, qs] = raw.split('?')
  route.name = ROUTES.some(r => r.name === name) ? name : 'overview'
  route.query = Object.fromEntries(new URLSearchParams(qs || ''))
}

// Navigation updates state directly; the hash only mirrors it (embedded viewers may not route hashes).
export function go(name, query = {}) {
  const clean = Object.fromEntries(Object.entries(query).filter(([, v]) => v !== '' && v != null))
  route.name = ROUTES.some(r => r.name === name) ? name : 'overview'
  route.query = clean
  const qs = new URLSearchParams(clean).toString()
  try { history.replaceState(null, '', '#/' + route.name + (qs ? '?' + qs : '')) } catch { /* sandboxed frame */ }
}

export function openIp(ip) { route.ip = ip }
export function closeIp() { route.ip = '' }

export function initRouter() {
  parse()
  addEventListener('hashchange', parse)
}
