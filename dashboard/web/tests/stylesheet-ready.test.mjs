import test from 'node:test'
import assert from 'node:assert/strict'
import { waitForStyles } from '../src/lib/stylesheet-ready.js'

class Stylesheet extends EventTarget {
  sheet = null
  disabled = false
  load() { this.sheet = {}; this.dispatchEvent(new Event('load')) }
}
const doc = links => ({ querySelectorAll: () => links })

test('cold-load chart bootstrap waits for every pending stylesheet before reading colors', async () => {
  const first = new Stylesheet(), second = new Stylesheet()
  let chartsMounted = false
  const boot = waitForStyles(doc([first, second])).then(() => { chartsMounted = true })
  await Promise.resolve()
  assert.equal(chartsMounted, false)
  first.load()
  await Promise.resolve()
  assert.equal(chartsMounted, false)
  second.load()
  await boot
  assert.equal(chartsMounted, true)
})

test('cached or disabled stylesheets do not leave startup waiting for a past load event', async () => {
  const cached = new Stylesheet(), disabled = new Stylesheet()
  cached.sheet = {}; disabled.disabled = true
  await waitForStyles(doc([cached, disabled]))
})

test('failed stylesheet stops chart initialization instead of silently caching blank colors', async () => {
  const link = new Stylesheet()
  const ready = waitForStyles(doc([link]))
  link.dispatchEvent(new Event('error'))
  await assert.rejects(ready, /stylesheet failed/)
})
