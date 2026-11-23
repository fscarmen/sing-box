// Chart option builders shared by views. All colors come from theme tokens.
import { axisBase, colorFor, legendBase, tipRows, tooltipBase } from './charts.js'
import { bytes, rate, shortBytes, shortTime } from './format.js'

const area = color => ({ color, opacity: 0.14 })

export function sparkOption(t, values, color) {
  return {
    animation: false,
    grid: { left: 0, right: 0, top: 4, bottom: 0 },
    xAxis: { type: 'category', show: false, boundaryGap: false, data: values.map((_, i) => i) },
    yAxis: { type: 'value', show: false, min: 0 },
    series: [{ type: 'line', data: values, symbol: 'none', smooth: 0.3, lineStyle: { width: 2, color }, areaStyle: area(color) }],
  }
}

// Realtime throughput: total (download/upload) or stacked by outbound.
export function realtimeOption(t, samples, mode, outbounds, labelOf) {
  const common = {
    animationDurationUpdate: 600,
    animationEasingUpdate: 'linear',
    grid: { left: 54, right: 12, top: 30, bottom: 26 },
    xAxis: { type: 'time', ...axisBase(t), splitLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, hideOverlap: true, formatter: v => shortTime(v) } },
    yAxis: { type: 'value', min: 0, ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => shortBytes(v) + '/s' } },
  }
  if (mode === 'outbound') {
    const series = outbounds.map(tag => ({
      name: labelOf(tag), type: 'line', stack: 'out', symbol: 'none', smooth: 0.25, showSymbol: false,
      lineStyle: { width: 1.5, color: colorFor(t, outbounds, tag) }, itemStyle: { color: colorFor(t, outbounds, tag) },
      areaStyle: { color: colorFor(t, outbounds, tag), opacity: 0.22 },
      data: samples.map(s => [s.t, (s.out[tag] || [0, 0]).reduce((a, b) => a + b, 0)]),
    }))
    return {
      ...common,
      legend: legendBase(t),
      tooltip: tooltipBase(t, {
        trigger: 'axis', axisPointer: { type: 'line', lineStyle: { color: t.axis } },
        formatter: ps => tipRows(shortTime(ps[0].value[0]), ps.map(p => ({ name: p.seriesName, value: rate(p.value[1]), color: p.color }))),
      }),
      series,
    }
  }
  return {
    ...common,
    legend: legendBase(t, { data: ['下载', '上传'] }),
    tooltip: tooltipBase(t, {
      trigger: 'axis', axisPointer: { type: 'line', lineStyle: { color: t.axis } },
      formatter: ps => tipRows(shortTime(ps[0].value[0]), ps.map(p => ({ name: p.seriesName, value: rate(p.value[1]), color: p.color }))),
    }),
    series: [
      { name: '下载', type: 'line', symbol: 'none', smooth: 0.25, lineStyle: { width: 2, color: t.down }, itemStyle: { color: t.down }, areaStyle: area(t.down), data: samples.map(s => [s.t, s.down]) },
      { name: '上传', type: 'line', symbol: 'none', smooth: 0.25, lineStyle: { width: 2, color: t.up }, itemStyle: { color: t.up }, areaStyle: area(t.up), data: samples.map(s => [s.t, s.up]) },
    ],
  }
}

// Bucketed traffic from /api/series. keys = stable entity order; total of up+down per bucket.
export function trendOption(t, data, keys, labelOf, { split = false } = {}) {
  const step = data.step
  const withDate = step >= 3600
  const fmt = ts => shortTime(ts * 1000, withDate || data.buckets.length > 300)
  const x = data.buckets.map(b => b * 1000)
  let series
  if (split) {
    const sum = which => x.map((_, i) => data.series.reduce((a, s) => a + s[which][i], 0))
    series = [
      { name: '下载', type: 'bar', stack: 'all', data: sum('down').map((v, i) => [x[i], v]), itemStyle: { color: t.down, borderRadius: [0, 0, 0, 0] } },
      { name: '上传', type: 'bar', stack: 'all', data: sum('up').map((v, i) => [x[i], v]), itemStyle: { color: t.up, borderRadius: [3, 3, 0, 0] } },
    ]
  } else {
    const present = data.series.map(s => s.key)
    const ordered = [...keys.filter(k => present.includes(k)), ...present.filter(k => !keys.includes(k))]
    series = ordered.map((key, idx) => {
      const s = data.series.find(z => z.key === key)
      return {
        name: labelOf(key), type: 'bar', stack: 'all', barMaxWidth: 18,
        itemStyle: { color: colorFor(t, keys, key), borderRadius: idx === ordered.length - 1 ? [3, 3, 0, 0] : 0, borderColor: t.surface, borderWidth: 0.5 },
        data: s.up.map((u, i) => [x[i], u + s.down[i]]),
      }
    })
  }
  return {
    animationDuration: 400,
    grid: { left: 54, right: 12, top: 34, bottom: 26 },
    legend: legendBase(t, { type: 'scroll' }),
    tooltip: tooltipBase(t, {
      trigger: 'axis', axisPointer: { type: 'shadow', shadowStyle: { color: t.grid, opacity: 0.4 } },
      formatter: ps => {
        const total = ps.reduce((a, p) => a + (p.value[1] || 0), 0)
        const rows = ps.filter(p => p.value[1]).map(p => ({ name: p.seriesName, value: bytes(p.value[1]), color: p.color }))
        rows.push({ name: '合计', value: bytes(total) })
        return tipRows(fmt(ps[0].value[0] / 1000), rows)
      },
    }),
    xAxis: { type: 'time', ...axisBase(t), splitLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, hideOverlap: true, formatter: v => fmt(v / 1000) } },
    yAxis: { type: 'value', ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => shortBytes(v) } },
    series,
  }
}

export function latencyOption(t, history, outbounds, labelOf, target = 'trace') {
  const series = outbounds.map(tag => ({
    name: labelOf(tag), type: 'line', symbol: 'circle', symbolSize: 5, showSymbol: false, connectNulls: false,
    lineStyle: { width: 2, color: colorFor(t, outbounds, tag) }, itemStyle: { color: colorFor(t, outbounds, tag) },
    data: history.filter(h => h.outbound === tag && h.target === target).map(h => [h.at * 1000, h.ok ? h.total_ms : null]),
  }))
  return {
    grid: { left: 50, right: 12, top: 34, bottom: 26 },
    legend: legendBase(t, { type: 'scroll' }),
    tooltip: tooltipBase(t, {
      trigger: 'axis',
      formatter: ps => tipRows(shortTime(ps[0].value[0], true), ps.map(p => ({ name: p.seriesName, value: p.value[1] == null ? '失败' : p.value[1] + ' ms', color: p.color }))),
    }),
    xAxis: { type: 'time', ...axisBase(t), splitLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, hideOverlap: true, formatter: v => shortTime(v, true) } },
    yAxis: { type: 'value', min: 0, ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => v + ' ms' } },
    series,
  }
}

const timeAxis = (t, fmt) => ({ type: 'time', ...axisBase(t), splitLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, hideOverlap: true, formatter: fmt } })

// Interface throughput (receive / send), last few minutes.
export function nicLiveOption(t, samples) {
  const line = (name, color, key) => ({ name, type: 'line', symbol: 'none', smooth: 0.25, lineStyle: { width: 2, color }, itemStyle: { color }, areaStyle: area(color), data: samples.map(s => [s.t, s[key]]) })
  return {
    animationDurationUpdate: 600,
    animationEasingUpdate: 'linear',
    grid: { left: 54, right: 12, top: 30, bottom: 26 },
    legend: legendBase(t, { data: ['接收', '发送'] }),
    tooltip: tooltipBase(t, {
      trigger: 'axis', axisPointer: { type: 'line', lineStyle: { color: t.axis } },
      formatter: ps => tipRows(shortTime(ps[0].value[0]), ps.map(p => ({ name: p.seriesName, value: rate(p.value[1]), color: p.color }))),
    }),
    xAxis: timeAxis(t, v => shortTime(v)),
    yAxis: { type: 'value', min: 0, ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => shortBytes(v) + '/s' } },
    series: [line('接收', t.series[0], 'rx'), line('发送', t.series[1], 'tx')],
  }
}

// Interface bytes per bucket (stacked receive + send) beside the proxy payload line, one byte axis.
export function nicTrafficOption(t, data) {
  const withDate = data.step >= 3600 || data.buckets.length > 300
  const fmt = ms => shortTime(ms, withDate)
  const x = data.buckets.map(b => b * 1000)
  return {
    animationDuration: 400,
    grid: { left: 54, right: 12, top: 34, bottom: 26 },
    legend: legendBase(t, { data: ['网卡接收', '网卡发送', '代理载荷'] }),
    tooltip: tooltipBase(t, {
      trigger: 'axis', axisPointer: { type: 'shadow', shadowStyle: { color: t.grid, opacity: 0.4 } },
      formatter: ps => {
        const rows = ps.map(p => ({ name: p.seriesName, value: bytes(p.value[1]), color: p.color }))
        const nic = ps.filter(p => p.seriesName !== '代理载荷').reduce((a, p) => a + (p.value[1] || 0), 0)
        const payload = ps.find(p => p.seriesName === '代理载荷')?.value[1] || 0
        rows.push({ name: '网卡 / 载荷', value: payload && nic ? (nic / payload).toFixed(2) + ' 倍' : '—' })
        return tipRows(fmt(ps[0].value[0]), rows)
      },
    }),
    xAxis: timeAxis(t, v => fmt(v)),
    yAxis: { type: 'value', min: 0, ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => shortBytes(v) } },
    series: [
      { name: '网卡接收', type: 'bar', stack: 'nic', barMaxWidth: 18, itemStyle: { color: t.series[0], borderColor: t.surface, borderWidth: 0.5 }, data: data.rx.map((v, i) => [x[i], v]) },
      { name: '网卡发送', type: 'bar', stack: 'nic', barMaxWidth: 18, itemStyle: { color: t.series[1], borderRadius: [3, 3, 0, 0], borderColor: t.surface, borderWidth: 0.5 }, data: data.tx.map((v, i) => [x[i], v]) },
      { name: '代理载荷', type: 'line', symbol: 'circle', symbolSize: 8, showSymbol: false, lineStyle: { width: 2, color: t.series[2] }, itemStyle: { color: t.series[2], borderColor: t.surface, borderWidth: 2 }, data: data.payload.map((v, i) => [x[i], v]) },
    ],
  }
}

// Path quality per segment: metric is 'rtt' (ms) or 'retrans_pct' (%); one unit per chart.
export function qualityOption(t, data, segments, labelOf, metric) {
  const withDate = data.step >= 3600 || data.buckets.length > 300
  const fmt = ms => shortTime(ms, withDate)
  const unit = metric === 'rtt' ? v => v + ' ms' : v => v + '%'
  const x = data.buckets.map(b => b * 1000)
  const series = segments.filter(s => data.segments[s]).map(s => ({
    name: labelOf(s), type: 'line', symbol: 'circle', symbolSize: 8, showSymbol: false, connectNulls: false,
    lineStyle: { width: 2, color: colorFor(t, segments, s) }, itemStyle: { color: colorFor(t, segments, s), borderColor: t.surface, borderWidth: 2 },
    data: data.segments[s][metric].map((v, i) => [x[i], v]),
  }))
  return {
    grid: { left: 58, right: 12, top: 34, bottom: 26 },
    legend: legendBase(t, { type: 'scroll' }),
    tooltip: tooltipBase(t, {
      trigger: 'axis', axisPointer: { type: 'line', lineStyle: { color: t.axis } },
      formatter: ps => tipRows(fmt(ps[0].value[0]), ps.map(p => ({ name: p.seriesName, value: p.value[1] == null ? '无样本' : unit(p.value[1]), color: p.color }))),
    }),
    xAxis: timeAxis(t, v => fmt(v)),
    yAxis: { type: 'value', min: 0, ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: unit } },
    series,
  }
}
