// Node activity is measured from its own inbound bytes, independently of shared users or source IPs.
export function nodeActivity(node, nowSeconds, failed = false) {
  if (failed || !node.fresh || node.up_rate == null || node.down_rate == null ||
      !Number.isFinite(node.sampled_at) || nowSeconds - node.sampled_at > 15 ||
      !Object.hasOwn(node, 'last_activity')) return null
  return Number.isFinite(node.last_activity) && nowSeconds - node.last_activity <= 60
}

export function nodeActivitySummary(nodes, nowSeconds, failed = false) {
  const states = nodes.map(node => nodeActivity(node, nowSeconds, failed))
  const active = states.filter(value => value === true).length
  const unknown = states.filter(value => value == null).length
  return { active: unknown === nodes.length ? null : active, unknown, total: nodes.length,
    label: unknown === nodes.length ? '—' : `${unknown ? '≥' : ''}${active} / ${nodes.length}` }
}
