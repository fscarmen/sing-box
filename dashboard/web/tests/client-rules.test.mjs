import test from 'node:test'
import assert from 'node:assert/strict'
import {mergeRule, moveRule} from '../src/lib/clientRules.js'

const first = {id: 'a', type: 'domain_suffix', target: 'example.com', action: 'proxy', enabled: true, note: ''}
const exact = {id: 'b', type: 'domain', target: 'api.example.com', action: 'reject', enabled: true, note: ''}
const source = () => ({default_action: 'inherit', rules: [{...first}, {...exact}]})

test('history overrides are inserted first without modifying the loaded policy', () => {
  const policy = source()
  const result = mergeRule(policy, {type: 'domain', target: 'new.example.com', action: 'direct', enabled: true, note: 'history'})
  assert.equal(result.rules[0].target, 'new.example.com')
  assert.equal(result.rules[0].action, 'direct')
  assert.ok(result.rules[0].id)
  assert.deepEqual(policy, source())
})
test('an existing exact target is updated and promoted, rather than duplicated', () => {
  const result = mergeRule(source(), {...exact, target: 'API.EXAMPLE.COM', action: 'direct'})
  assert.equal(result.rules.length, 2)
  assert.equal(result.rules[0].id, 'b')
  assert.equal(result.rules[0].action, 'direct')
})
test('editing preserves the existing priority and id', () => {
  const result = mergeRule(source(), {...exact, action: 'direct'}, 'b')
  assert.equal(result.rules[1].id, 'b')
  assert.equal(result.rules[1].action, 'direct')
})
test('rule order can be changed and boundary moves are harmless', () => {
  const policy = source()
  assert.deepEqual(moveRule(policy, 1, -1).rules.map(r => r.id), ['b', 'a'])
  assert.deepEqual(moveRule(policy, 0, -1), policy)
  assert.deepEqual(moveRule(policy, 1, 1), policy)
  assert.deepEqual(policy, source())
})
test('plain JSON cloning accepts reactive proxy inputs', () => {
  const policy = new Proxy(source(), {})
  assert.equal(moveRule(policy, 1, -1).rules[0].id, 'b')
  assert.equal(mergeRule(policy, {...exact, action: 'direct'}, 'b').rules[1].action, 'direct')
})
