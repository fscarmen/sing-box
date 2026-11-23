<template>
  <div class="grid">
    <section class="card">
      <div class="card-head">
        <div><h2>链路地图</h2><p>客户端（离线库定位）→ 服务器 → 各出口公网地址。点大小对应所选时段流量；可拖动、滚轮缩放。</p></div>
        <Seg v-model="range" :options="ranges" label="时间范围" />
      </div>
      <div class="card-body">
        <Chart v-if="ready" :option="option" height="520px" label="客户端与出口地理分布图" replace />
        <p v-else class="muted small">{{ error || '正在加载地图…' }}</p>
      </div>
    </section>
    <section class="card">
      <div class="card-head"><div><h2>定位明细</h2><p>国内地址以 ip2region 为准（省 / 市 / 运营商），境外以 DB-IP 为准；坐标精度标注为“城市”或“省级”。移动网络出口通常只能定位到省。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="columns" :rows="rows" row-key="key" sort="bytes" :page-size="30">
          <template #cell-name="{ row }"><IpCell v-if="row.kind === '客户端'" :ip="row.name" /><span v-else class="mono">{{ row.name }}</span></template>
          <template #cell-bytes="{ row }">{{ row.bytes ? bytes(row.bytes) : '—' }}</template>
          <template #cell-precision="{ row }">{{ { city: '城市', region: '省级', country: '国家' }[row.precision] || '—' }}<span class="sub">{{ row.source }}</span></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { feature } from 'topojson-client'
import landUrl from 'world-atlas/land-50m.json?url'
import Chart from '../components/Chart.vue'
import Seg from '../components/Seg.vue'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import { echarts, tipRows, tooltipBase, legendBase } from '../lib/charts.js'
import { get } from '../lib/api.js'
import { state, label } from '../lib/state.js'
import { bytes } from '../lib/format.js'

const ranges = [{ value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }, { value: 'all', label: '全部' }]
const range = ref('7d')
const data = ref(null)
const ready = ref(false)
const error = ref('')
const SEAM = -30 // Pacific-centred view: shift the Americas east of Asia so trans-Pacific links stay short.
const motion = !matchMedia('(prefers-reduced-motion: reduce)').matches
const shift = lon => (lon < SEAM ? lon + 360 : lon)

let mapLoaded = false
async function loadMap() {
  if (mapLoaded) return
  const topo = await (await fetch(landUrl)).json()
  const land = feature(topo, topo.objects.land)
  const polygons = []
  for (const f of land.features || [land]) {
    const geom = f.geometry
    const list = geom.type === 'Polygon' ? [geom.coordinates] : geom.coordinates
    for (const poly of list) {
      if (Math.max(...poly[0].map(p => p[1])) < -58) continue // Antarctica spans every meridian
      // Unwrap each ring so it is continuous across ±180°, then move the whole polygon into [SEAM, SEAM + 360).
      const rings = poly.map(ring => {
        let prev = null
        return ring.map(([x, y]) => {
          if (prev !== null) { while (x - prev > 180) x -= 360; while (x - prev < -180) x += 360 }
          prev = x
          return [x, y]
        })
      })
      const outer = rings[0]
      let mean = outer.reduce((a, p) => a + p[0], 0) / outer.length
      let dx = 0
      while (mean + dx < SEAM) dx += 360
      while (mean + dx >= SEAM + 360) dx -= 360
      polygons.push(rings.map(r => r.map(([x, y]) => [x + dx, y])))
    }
  }
  echarts.registerMap('joysol-land', { type: 'FeatureCollection', features: [{ type: 'Feature', properties: { name: 'land' }, geometry: { type: 'MultiPolygon', coordinates: polygons } }] })
  mapLoaded = true
}

const server = computed(() => data.value ? Object.values(data.value.probes).find(p => p.outbound === 'direct' || isDirect(p.outbound)) : null)
const isDirect = tag => (data.value?.outbounds || []).some(o => o.tag === tag && o.type === 'direct')
const exits = computed(() => data.value ? Object.values(data.value.probes).filter(p => !isDirect(p.outbound) && p.geo && p.geo.lat != null) : [])

const option = computed(() => {
  const t = state.tokens
  const clients = data.value?.clients || []
  const max = Math.max(1, ...clients.map(c => c.bytes))
  const size = b => 6 + Math.sqrt(b / max) * 18
  const sv = server.value?.geo
  const sPos = sv && sv.lat != null ? [shift(sv.lon), sv.lat] : null
  const cColor = t.series[0], sColor = t.series[1], eColor = t.series[2]
  const clientPts = clients.map(c => ({ name: c.ip, value: [shift(c.lon), c.lat, c.bytes], c }))
  const lines = []
  if (sPos) {
    for (const c of clients) lines.push({ coords: [[shift(c.lon), c.lat], sPos], lineStyle: { color: cColor } })
    for (const e of exits.value) lines.push({ coords: [sPos, [shift(e.geo.lon), e.geo.lat]], lineStyle: { color: eColor } })
  }
  return {
    legend: legendBase(t, { data: ['客户端', '服务器', '出口'], left: 0, right: 'auto' }),
    tooltip: tooltipBase(t, {
      trigger: 'item',
      formatter: p => {
        if (p.seriesType === 'lines') return ''
        const d = p.data
        if (d.c) return tipRows(d.c.ip, [{ name: '位置', value: d.c.location }, { name: '运营商', value: d.c.isp }, { name: '流量', value: bytes(d.c.bytes) }, { name: '在线连接', value: String(d.c.online) }])
        if (d.e) return tipRows(label('outbound', d.e.outbound), [{ name: '出口', value: d.e.exit_ip }, { name: '位置', value: d.e.geo.location }, { name: '网络', value: d.e.geo.isp }])
        if (d.s) return tipRows('服务器', [{ name: '公网地址', value: d.s.exit_ip }, { name: '位置', value: d.s.geo.location }, { name: '网络', value: d.s.geo.isp }])
        return ''
      },
    }),
    geo: {
      map: 'joysol-land', roam: true, silent: true, zoom: 1.15, center: [150, 25], scaleLimit: { min: 0.8, max: 12 },
      itemStyle: { areaColor: t.land, borderColor: t.landLine, borderWidth: 0.6 },
      emphasis: { disabled: true },
    },
    series: [
      {
        name: '链路', type: 'lines', coordinateSystem: 'geo', zlevel: 1, silent: true,
        effect: { show: motion, period: 4, trailLength: 0.25, symbol: 'circle', symbolSize: 3 },
        lineStyle: { width: 1.2, opacity: 0.45, curveness: 0.25 }, data: lines,
      },
      {
        name: '客户端', type: 'scatter', coordinateSystem: 'geo', zlevel: 2,
        symbolSize: v => size(v[2]), itemStyle: { color: cColor, borderColor: t.surface, borderWidth: 2 },
        data: clientPts.filter(p => !p.c.online),
      },
      {
        name: '客户端', type: 'effectScatter', coordinateSystem: 'geo', zlevel: 2, rippleEffect: { scale: motion ? 3 : 1, brushType: 'stroke' },
        symbolSize: v => size(v[2]), itemStyle: { color: cColor, borderColor: t.surface, borderWidth: 2 },
        data: clientPts.filter(p => p.c.online),
      },
      {
        name: '服务器', type: 'effectScatter', coordinateSystem: 'geo', zlevel: 3, symbolSize: 13, rippleEffect: { scale: motion ? 3.5 : 1 },
        itemStyle: { color: sColor, borderColor: t.surface, borderWidth: 2 },
        data: sPos ? [{ name: 'server', value: sPos, s: server.value }] : [],
      },
      {
        name: '出口', type: 'scatter', coordinateSystem: 'geo', zlevel: 3, symbol: 'diamond', symbolSize: 13,
        itemStyle: { color: eColor, borderColor: t.surface, borderWidth: 2 },
        data: exits.value.map(e => ({ name: e.exit_ip, value: [shift(e.geo.lon), e.geo.lat], e })),
      },
    ],
  }
})

const columns = [
  { key: 'kind', label: '类型' }, { key: 'name', label: '地址' }, { key: 'location', label: '位置' }, { key: 'isp', label: '运营商 / 网络' },
  { key: 'precision', label: '精度' }, { key: 'bytes', label: '流量', align: 'right' },
]
const rows = computed(() => {
  const out = (data.value?.clients || []).map(c => ({ key: 'c' + c.ip, kind: '客户端', name: c.ip, location: c.location, isp: c.isp, precision: c.precision, source: c.source, bytes: c.bytes }))
  if (server.value?.geo) out.push({ key: 's', kind: '服务器', name: server.value.exit_ip, location: server.value.geo.location, isp: server.value.geo.isp, precision: '', source: '直连探测', bytes: 0 })
  for (const e of exits.value) out.push({ key: 'e' + e.outbound, kind: '出口 · ' + label('outbound', e.outbound), name: e.exit_ip, location: e.geo.location, isp: e.geo.isp, precision: '', source: '出口探测', bytes: 0 })
  return out
})

async function load() {
  try {
    await loadMap()
    data.value = await get('api/map', { range: range.value })
    ready.value = true
  } catch (e) { error.value = e.message }
}
watch(range, load)
onMounted(load)
</script>
