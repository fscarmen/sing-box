import test from 'node:test'
import assert from 'node:assert/strict'
import { defaultEngine, engineStatus } from '../src/lib/engines.js'

test('Xray is primary whenever configured; older sing-box installs retain a usable default', () => {
  assert.equal(defaultEngine({ xray: { enabled: true } }), 'xray')
  assert.equal(defaultEngine({ xray: { enabled: false } }), 'singbox')
})

test('healthy sing-box never hides an Xray outage or a failed UI refresh', () => {
  const legacy = { health: { connected: true }, gate: { enabled: true } }
  const xray = { enabled: true, instances: [{ label: 'Xray test', connected: false, error: 'Unavailable' }] }
  assert.equal(engineStatus('xray', legacy, xray, false, 'stream').kind, 'bad')
  assert.equal(engineStatus('xray', legacy, { enabled: true, instances: [{ connected: true }] }, true, 'stream').kind, 'bad')
})

test('unused sing-box or its gate never triggers a warning in a healthy Xray view', () => {
  const legacy = { health: { connected: false }, gate: { enabled: false } }
  const result = engineStatus('xray', legacy, { enabled: true, instances: [{ connected: true }] }, false, 'offline')
  assert.equal(result.kind, 'good')
  assert.equal(result.notice, undefined)
})

test('a direct sing-box node does not get a CDN gate warning', () => {
  const legacy = { health: { connected: true }, gate: { enabled: false }, topology: { inbounds: [{ entry: 'direct' }] } }
  assert.equal(engineStatus('singbox', legacy, null, false, 'stream').notice, '')
  legacy.topology.inbounds[0].entry = 'cdn'
  assert.match(engineStatus('singbox', legacy, null, false, 'stream').notice, /CDN/)
})

test('an old successful response cannot remain green while the next request hangs', () => {
  const xray = { enabled: true, instances: [{ label: 'Xray', connected: true, last_success: 100 }] }
  assert.equal(engineStatus('xray', null, xray, false, '', 110000).kind, 'good')
  assert.equal(engineStatus('xray', null, xray, false, '', 116000).kind, 'bad')
})
