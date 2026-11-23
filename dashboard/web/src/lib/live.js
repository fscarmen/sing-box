// Realtime frames: Server-Sent Events first, automatic fallback to polling (CDNs may buffer streams).
import { state } from './state.js'
import { BASE, get } from './api.js'

const KEEP = 300
let source = null
let pollTimer = null
let watchdog = null
let lastFrameAt = 0

function push(frame) {
  lastFrameAt = Date.now()
  state.frame = frame
  const last = state.samples[state.samples.length - 1]
  if (!last || frame.t - last.t >= 500) {
    state.samples.push({ t: frame.t, up: frame.up, down: frame.down, out: frame.out || {} })
    if (state.samples.length > KEEP) state.samples.splice(0, state.samples.length - KEEP)
  }
}

async function seed() {
  try {
    const data = await get('api/live', { seconds: KEEP })
    state.samples = (data.series || []).map(s => ({ t: s.t, up: s.up, down: s.down, out: s.out || {} }))
    push(data.frame)
  } catch { /* the stream or poller will retry */ }
}

function startPolling() {
  stopStream()
  state.link = 'polling'
  if (pollTimer) return
  const tick = async () => {
    if (document.hidden) return
    try {
      const data = await get('api/live', { seconds: 10 })
      push(data.frame)
      state.link = 'polling'
    } catch { state.link = 'offline' }
  }
  tick()
  pollTimer = setInterval(tick, 2000)
}

function stopStream() {
  if (source) { source.close(); source = null }
}

function startStream() {
  if (typeof EventSource === 'undefined') return startPolling()
  stopStream()
  let errors = 0
  source = new EventSource(BASE + '/api/stream')
  source.addEventListener('frame', e => {
    errors = 0
    state.link = 'stream'
    try { push(JSON.parse(e.data)) } catch { /* ignore malformed frame */ }
  })
  source.onerror = () => {
    errors += 1
    if (errors >= 3) startPolling()
  }
}

export function startLive() {
  seed()
  startStream()
  // A buffered stream delivers nothing: switch to polling after a quiet period.
  clearInterval(watchdog)
  watchdog = setInterval(() => {
    if (state.link === 'polling' || document.hidden) return
    if (Date.now() - lastFrameAt > 7000) startPolling()
  }, 3000)
}

export function stopLive() {
  stopStream()
  clearInterval(pollTimer); pollTimer = null
  clearInterval(watchdog); watchdog = null
}
