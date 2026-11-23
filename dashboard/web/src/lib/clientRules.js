
export const ruleActions = { proxy: '代理', direct: '直连', reject: '拒绝' }
export const ruleTypes = { domain: '精确域名', domain_suffix: '域名及子域名', domain_keyword: '域名关键词', ip_cidr: 'IP / CIDR' }
export const clientFormats = { clash: 'Clash（提供者）', clash2: 'Clash Meta 完整配置', 'sing-box': 'sing-box 完整配置', 'shadowrocket.conf': 'Shadowrocket 远程配置', 'rules-v2rayn.json': 'v2rayN 路由 JSON' }

export function mergeRule(policy, row, existingId = '') {
  const next = JSON.parse(JSON.stringify(policy))
  const index = existingId ? next.rules.findIndex(r => r.id === existingId) : next.rules.findIndex(r => r.type === row.type && r.target.toLowerCase() === row.target.trim().toLowerCase())
  const item = {...row, target: row.target.trim(), id: index >= 0 ? next.rules[index].id : crypto.randomUUID()}
  if (index >= 0 && existingId) next.rules.splice(index, 1, item)
  else {
    if (index >= 0) next.rules.splice(index, 1)
    next.rules.unshift(item)
  }
  return next
}

export function moveRule(policy, index, step) {
  const next = JSON.parse(JSON.stringify(policy))
  const target = index + step
  if (index < 0 || index >= next.rules.length || target < 0 || target >= next.rules.length) return next
  const [row] = next.rules.splice(index, 1)
  next.rules.splice(target, 0, row)
  return next
}

export async function publishRules(policy, revision) {
  const { get, post } = await import('./api.js')
  const {job} = await post('api/manage/rules-save', {policy, revision})
  for (let attempt = 0; attempt < 120; attempt++) {
    const status = await get('api/manage/status', {engine: 'singbox'})
    const current = status.jobs.find(j => j.id === job.id)
    if (current && !['queued', 'running'].includes(current.state)) {
      if (current.state !== 'succeeded') throw new Error(current.error || '规则发布失败')
      return current
    }
    await new Promise(resolve => setTimeout(resolve, 500))
  }
  throw new Error('任务仍在后台运行，请刷新规则页查看结果')
}
