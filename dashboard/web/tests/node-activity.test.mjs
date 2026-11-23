import test from 'node:test'
import assert from 'node:assert/strict'
import { nodeActivity, nodeActivitySummary } from '../src/lib/node-activity.js'

const node = { fresh: true, up_rate: 0, down_rate: 0, sampled_at: 100, last_activity: 90 }
test('activity survives an idle sample, expires after 60 seconds, and is not a user/IP count', () => {
  assert.equal(nodeActivity(node, 100), true)
  assert.equal(nodeActivity({ ...node, sampled_at: 151 }, 151), false)
  assert.equal(nodeActivity({ ...node, last_activity: null, online_sources: ['198.51.100.7'] }, 100), false)
})
test('missing, failed and stale samples remain unknown', () => {
  for (const value of [{ ...node, fresh: false }, { ...node, up_rate: null }, { ...node, sampled_at: 80 }]) {
    assert.equal(nodeActivity(value, 100), null)
  }
  assert.equal(nodeActivity(node, 100, true), null)
  assert.equal(nodeActivity({ fresh: true, up_rate: 0, down_rate: 0, sampled_at: 100 }, 100), null)
})
test('summary counts each node, exposes partial coverage and works for an instance subset', () => {
  const inactive = { ...node, last_activity: null }
  const unknown = { ...node, fresh: false }
  assert.equal(nodeActivitySummary([node, inactive], 100).label, '1 / 2')
  assert.equal(nodeActivitySummary([node, unknown], 100).label, '≥1 / 2')
  assert.equal(nodeActivitySummary([unknown], 100).label, '—')
  assert.equal(nodeActivitySummary([inactive], 100).label, '0 / 1')
})
