<template>
  <div class="grid">
    <section class="card">
      <div class="card-head">
        <div><h2>流量路径</h2><p>客户端 → 入口 → 分流规则 → 出口 → 出口公网地址，宽度为所选时段的流量。规则字段自本次升级起开始记录，之前的连接显示为“未记录”。</p></div>
        <Seg v-model="range" :options="ranges" label="时间范围" />
      </div>
      <div class="card-body">
        <Chart v-if="data && flows.length" :option="sankey" :height="sankeyHeight" label="流量桑基图" replace />
        <p v-else class="muted small">{{ data ? '所选时段没有流量' : '加载中…' }}</p>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>入口链路</h2><p>每个入站从公网到 sing-box 的经过节点；占比为所选时段各出口的流量份额。</p></div></div>
      <div class="card-body paths">
        <div v-for="row in entryPaths" :key="row.tag" class="path">
          <div class="hop"><span class="h-kind">客户端</span><b>{{ row.clients }} 个 IP</b><span class="h-meta">{{ bytes(row.bytes) }}</span></div>
          <template v-if="row.entry === 'cdn'">
            <div class="link"></div>
            <div class="hop"><span class="h-kind">CDN 边缘</span><b>阿里云 ESA</b><span class="h-meta">{{ host }}:443</span></div>
            <div class="link"></div>
            <div class="hop"><span class="h-kind">源站 Nginx</span><b>{{ serverIp || '源站' }}</b><span class="h-meta">TLS 终止 · 回源校验{{ gate ? '已启用' : '未启用' }}</span></div>
          </template>
          <div class="link"></div>
          <div class="hop accent"><span class="h-kind">入站</span><b>{{ row.label }}</b><span class="h-meta">{{ row.type }} · {{ row.transport }}{{ row.reality ? ' · Reality' : '' }} · :{{ row.port }}</span></div>
          <div class="link"></div>
          <div class="hop"><span class="h-kind">分流到</span>
            <span v-for="o in row.outs" :key="o.tag" class="h-meta legend-key"><i :class="swatch(o.tag)"></i>{{ label('outbound', o.tag) }} {{ o.share }}%</span>
            <span v-if="!row.outs.length" class="h-meta">暂无流量</span>
          </div>
        </div>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>出口链路</h2><p>出口地址由面板定时经同一上游探测得到，与 sing-box 实际出口一致。</p></div><NavLink class="btn sm" to="exits">出口详情</NavLink></div>
      <div class="card-body paths">
        <div v-for="o in exitPaths" :key="o.tag" class="path">
          <div class="hop"><span class="h-kind">sing-box</span><b>{{ serverIp || '本机' }}</b><span class="h-meta">{{ serverGeo }}</span></div>
          <div class="link"></div>
          <div class="hop accent"><span class="h-kind">出站</span><b class="legend-key"><i :class="swatch(o.tag)"></i>{{ o.label }}</b><span class="h-meta">{{ o.type }}{{ o.port ? ' · :' + o.port : '' }} · {{ bytes(o.bytes) }}</span></div>
          <template v-if="o.type !== 'direct'">
            <div class="link"></div>
            <div class="hop"><span class="h-kind">上游代理</span><b>{{ o.server || '—' }}</b><span class="h-meta">{{ o.type.toUpperCase() }} 代理</span></div>
          </template>
          <div class="link"></div>
          <div class="hop" :class="{ bad: o.probe && !o.probe.ok }"><span class="h-kind">出口地址</span><b class="mono">{{ o.probe?.exit_ip || '—' }}</b><span class="h-meta">{{ o.probe?.geo ? o.probe.geo.location : o.probe ? '探测失败' : '未探测' }}</span><span v-if="o.probe?.geo" class="h-meta">{{ o.probe.geo.isp }}{{ o.probe.geo.asn ? ' · AS' + o.probe.geo.asn : '' }}</span></div>
          <div class="link"></div>
          <div class="hop"><span class="h-kind">目标</span><b>{{ o.top || '—' }}</b><span class="h-meta">{{ o.rules ? o.rules + ' 条规则命中' : '默认路由' }}</span></div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import NavLink from '../components/NavLink.vue'
import { computed, onMounted, ref, watch } from 'vue'
import Chart from '../components/Chart.vue'
import Seg from '../components/Seg.vue'
import { get } from '../lib/api.js'
import { state, label, outboundTags } from '../lib/state.js'
import { bytes } from '../lib/format.js'
import { colorFor, tipRows, tooltipBase } from '../lib/charts.js'

const ranges = [{ value: '1h', label: '1 小时' }, { value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }]
const range = ref('24h')
const data = ref(null)
const top = ref([])
const MAX_CLIENTS = 10

const flows = computed(() => (data.value?.flows || []).filter(f => f.upload + f.download > 0))
const host = computed(() => data.value?.entry_host || '')
const gate = computed(() => state.overview?.gate?.enabled)
const probes = computed(() => data.value?.probes || {})
const serverIp = computed(() => data.value?.server?.exit_ip || '')
const serverGeo = computed(() => data.value?.server?.geo ? data.value.server.geo.location + ' · ' + data.value.server.geo.isp : '')
const swatch = tag => { const i = outboundTags().indexOf(tag); return i >= 0 && i < 8 ? 'sw-' + (i + 1) : 'sw-muted' }

const sankeyHeight = computed(() => Math.max(320, Math.min(720, 60 + 34 * Math.max(clientNodes.value.length, 6))) + 'px')
const clientNodes = computed(() => {
  const totals = {}
  for (const f of flows.value) totals[f.ip] = (totals[f.ip] || 0) + f.upload + f.download
  return Object.entries(totals).sort((a, b) => b[1] - a[1]).map(([ip]) => ip)
})

const sankey = computed(() => {
  const t = state.tokens
  const totalBytes = flows.value.reduce((a, f) => a + f.upload + f.download, 0) || 1
  const perIp = {}
  for (const f of flows.value) perIp[f.ip] = (perIp[f.ip] || 0) + f.upload + f.download
  // Tiny nodes overlap; fold the long tail into one node.
  const keep = new Set(clientNodes.value.slice(0, MAX_CLIENTS).filter(ip => perIp[ip] / totalBytes >= 0.015))
  const others = clientNodes.value.length - keep.size
  const display = {}
  const color = {}
  const links = {}
  const add = (a, b, v) => { const k = a + '\u0000' + b; links[k] = (links[k] || 0) + v }
  const outs = outboundTags()
  for (const f of flows.value) {
    const v = f.upload + f.download
    const client = keep.has(f.ip) ? 'c:' + f.ip : 'c:*'
    display[client] = keep.has(f.ip) ? f.ip : '其他 ' + others + ' 个客户端'
    const inbound = 'i:' + f.inbound_tag
    display[inbound] = label('inbound', f.inbound_tag)
    const rule = 'r:' + (f.rule ? f.rule_label : '—')
    display[rule] = f.rule ? f.rule_label.replace(/ → (.*)$/, (_, target) => ' → ' + label('outbound', target)) : '未记录规则'
    if (f.rule === '' && f.outbound === (data.value.topology.final || 'direct')) display[rule] = '默认 / 未记录'
    const out = 'o:' + f.outbound
    display[out] = label('outbound', f.outbound)
    color[out] = colorFor(t, outs, f.outbound)
    const exitIp = probes.value[f.outbound]?.exit_ip
    const exit = 'e:' + (exitIp || f.outbound)
    display[exit] = exitIp || '未探测'
    color[exit] = colorFor(t, outs, f.outbound)
    add(client, inbound, v); add(inbound, rule, v); add(rule, out, v); add(out, exit, v)
  }
  const nodes = Object.keys(display).map(name => ({ name, itemStyle: { color: color[name] || t.axis, borderColor: t.surface } }))
  return {
    tooltip: tooltipBase(t, {
      trigger: 'item',
      formatter: p => p.dataType === 'edge'
        ? tipRows(display[p.data.source] + ' → ' + display[p.data.target], [{ name: '流量', value: bytes(p.data.value) }])
        : tipRows(display[p.name], [{ name: '流量', value: bytes(p.value) }]),
    }),
    series: [{
      type: 'sankey', left: 8, right: 120, top: 8, bottom: 8, nodeWidth: 12, nodeGap: 10, nodeAlign: 'justify', draggable: true,
      emphasis: { focus: 'adjacency' },
      label: { color: t.ink2, fontSize: 12, formatter: p => display[p.name] },
      lineStyle: { color: 'gradient', opacity: 0.32, curveness: 0.5 },
      data: nodes,
      links: Object.entries(links).map(([k, value]) => { const [source, target] = k.split('\u0000'); return { source, target, value } }),
    }],
  }
})

const entryPaths = computed(() => {
  const inbounds = data.value?.topology?.inbounds || []
  return inbounds.map(i => {
    const own = flows.value.filter(f => f.inbound_tag === i.tag)
    const total = own.reduce((a, f) => a + f.upload + f.download, 0)
    const byOut = {}
    for (const f of own) byOut[f.outbound] = (byOut[f.outbound] || 0) + f.upload + f.download
    const outs = Object.entries(byOut).sort((a, b) => b[1] - a[1]).map(([tag, v]) => ({ tag, share: total ? Math.round(v * 1000 / total) / 10 : 0 }))
    return { ...i, clients: new Set(own.map(f => f.ip)).size, bytes: total, outs }
  })
})

const exitPaths = computed(() => {
  const outbounds = data.value?.topology?.outbounds || []
  return outbounds.map(o => {
    const own = flows.value.filter(f => f.outbound === o.tag)
    const topRow = top.value.find(r => r.outbound === o.tag)
    return { ...o, probe: probes.value[o.tag], bytes: own.reduce((a, f) => a + f.upload + f.download, 0), rules: new Set(own.map(f => f.rule).filter(Boolean)).size, top: topRow?.k || '' }
  })
})

async function load() {
  data.value = await get('api/topology', { range: range.value })
  // Top destination per outbound (small: one query per outbound).
  const outs = (data.value.topology.outbounds || []).map(o => o.tag)
  const rows = await Promise.all(outs.map(async tag => {
    const r = await get('api/top', { by: 'domain', range: range.value, limit: 1, outbound: tag })
    return { outbound: tag, k: r.rows[0]?.k }
  }))
  top.value = rows
}
watch(range, load)
onMounted(load)
</script>
