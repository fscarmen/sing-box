// Theme: data colors come from CSS custom properties so light/dark stay in one place.
import { state } from './state.js'
import { waitForStyles } from './stylesheet-ready.js'

const KEY = 'joysol-theme'

export function refreshTokens() {
  const styles = getComputedStyle(document.documentElement)
  const read = name => styles.getPropertyValue(name).trim()
  const tokens = {
    surface: read('--surface-1'), page: read('--page'), ink: read('--text-primary'), ink2: read('--text-secondary'),
    muted: read('--text-muted'), grid: read('--grid'), axis: read('--axis'), border: read('--border'),
    accent: read('--accent'),
    series: [1, 2, 3, 4, 5, 6, 7, 8].map(i => read('--series-' + i)),
    up: read('--series-2'), down: read('--series-1'),
    good: read('--status-good'), warning: read('--status-warning'), serious: read('--status-serious'), critical: read('--status-critical'),
    land: read('--map-land'), landLine: read('--map-line'),
  }
  if (Object.values(tokens).flat().some(value => !value)) throw new Error('Theme colors unavailable')
  state.tokens = tokens
}

export function currentTheme() {
  const stamp = document.documentElement.dataset.theme
  if (stamp) return stamp
  return matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

export async function initTheme() {
  let saved = ''
  try { saved = localStorage.getItem(KEY) || '' } catch { saved = '' }
  if (saved === 'light' || saved === 'dark') document.documentElement.dataset.theme = saved
  await waitForStyles()
  state.theme = currentTheme()
  refreshTokens()
  matchMedia('(prefers-color-scheme: light)').addEventListener('change', () => {
    state.theme = currentTheme()
    refreshTokens()
  })
}

export function toggleTheme() {
  const next = currentTheme() === 'dark' ? 'light' : 'dark'
  document.documentElement.dataset.theme = next
  try { localStorage.setItem(KEY, next) } catch { /* private mode */ }
  state.theme = next
  refreshTokens()
}
