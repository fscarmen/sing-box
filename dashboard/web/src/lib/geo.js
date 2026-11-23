// Lazily resolved, cached geolocation strings for IP cells (offline lookup on the server).
import { reactive } from 'vue'
import { get } from './api.js'

const cache = reactive({})
const pending = new Set()

export function useGeo() {
  function geo(ip) {
    if (!ip) return ''
    if (cache[ip] === undefined && !pending.has(ip)) {
      pending.add(ip)
      get('api/geo/' + encodeURIComponent(ip)).then(g => { cache[ip] = g.location + (g.isp && g.isp !== '未知' ? ' · ' + g.isp : '') })
        .catch(() => { cache[ip] = '' }).finally(() => pending.delete(ip))
    }
    return cache[ip] || ''
  }
  return { geo }
}
