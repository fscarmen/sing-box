// Pure source decisions. Xray status must never depend on sing-box health.
export function defaultEngine(overview) {
  return overview?.xray?.enabled ? 'xray' : 'singbox'
}

export function engineStatus(engine, overview, xray, failed, link, now = Date.now()) {
  if (engine === 'xray') {
    if (failed) return { kind: 'bad', text: '监控连接中断', notice: 'Xray 页面数据暂时无法刷新，下面保留最近结果。' }
    if (!xray) return { kind: '', text: '正在连接 Xray' }
    if (!xray.enabled) return { kind: 'warn', text: '未配置 Xray', notice: '尚未配置 Xray 统计实例。' }
    const offline = xray.instances.filter(i => !i.connected || (i.last_success && now / 1000 - i.last_success > 15))
    if (offline.length) return { kind: 'bad', text: '部分采集中断', notice: offline.map(i => i.label + '：' + (i.error || '采样已过期')).join('；') }
    return { kind: 'good', text: 'Xray · 2 秒采样' }
  }
  if (overview && !overview.health.connected) return { kind: 'bad', text: '采集中断', notice: 'sing-box 采集中断：' + (overview.health.last_error || '等待重连') }
  const cdn = overview?.topology?.inbounds?.some(i => i.entry === 'cdn')
  const notice = cdn && !overview?.gate?.enabled ? 'sing-box CDN 入口尚未接入封禁网关。' : ''
  return { kind: { stream: 'good', polling: 'warn', offline: 'bad' }[link] || '', text: { stream: '实时', polling: '轮询', offline: '离线', connecting: '连接中' }[link], notice }
}
