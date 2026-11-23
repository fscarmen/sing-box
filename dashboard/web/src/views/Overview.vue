<template>
  <div class="grid">
    <section v-if="state.overview?.xray?.enabled" class="card">
      <div class="card-head"><div><h2>Xray 节点已接入 · {{ state.overview.xray.nodes.length }} 个</h2><p>Xray 今日 {{ bytes(state.overview.xray.totals.today_upload + state.overview.xray.totals.today_download) }} · 接入后累计 {{ bytes(state.overview.xray.totals.upload + state.overview.xray.totals.download) }}。下面的逐连接统计覆盖 sing-box；Xray 的节点流量、速率和媒体出口请打开专页。</p></div><NavLink class="btn sm" to="xray">Xray 监控</NavLink></div>
    </section>
    <div class="grid cols-4">
      <Kpi label="实时速率" :value="rate(liveUp + liveDown)">
        <span class="legend-key"><i class="sw-1"></i>↓ {{ rate(liveDown) }}</span>
        <span class="legend-key"><i class="sw-2"></i>↑ {{ rate(liveUp) }}</span>
        <template #spark><Chart :option="sparkTotal" height="44px" label="最近两分钟速率" /></template>
      </Kpi>
      <Kpi label="今日流量" :value="bytes(totals.today_upload + totals.today_download)">
        <span>↓ {{ bytes(totals.today_download) }}</span><span>↑ {{ bytes(totals.today_upload) }}</span>
      </Kpi>
      <Kpi label="累计流量" :value="bytes(totals.upload + totals.download)">
        <span>{{ num(totals.connections) }} 次连接</span><span>自 {{ since }}</span>
      </Kpi>
      <Kpi label="在线客户端 / 连接" :value="(state.frame?.online_ips ?? 0) + ' / ' + (state.frame?.active ?? 0)">
        <span>已记录 {{ num(totals.ips) }} 个 IP</span>
      </Kpi>
    </div>

    <section class="card">
      <div class="card-head">
        <div><h2>实时吞吐</h2><p>最近 5 分钟，每秒采样；数值为代理有效载荷</p></div>
        <Seg v-model="liveMode" :options="[{ value: 'total', label: '上下行' }, { value: 'outbound', label: '按出口' }]" label="实时视图" />
      </div>
      <div class="card-body"><Chart :option="realtime" height="280px" label="实时吞吐折线图" /></div>
    </section>

    <section class="card">
      <div class="card-head">
        <div><h2>流量趋势</h2><p>{{ trendNote }}</p></div>
        <div class="toolbar">
          <Seg v-model="trendBy" :options="[{ value: 'outbound', label: '按出口' }, { value: 'inbound', label: '按入口' }, { value: '', label: '上下行' }]" label="分组" />
          <Seg v-model="trendRange" :options="ranges" label="时间范围" />
        </div>
      </div>
      <div class="card-body"><Chart v-if="trend" :option="trendChart" height="260px" label="流量趋势柱状图" replace /></div>
    </section>

    <section class="card">
      <div class="card-head">
        <div><h2>出口节点</h2><p>{{ probeNote }}</p></div>
        <NavLink class="btn sm" to="exits">详情</NavLink>
      </div>
      <div class="card-body">
        <div class="exit-grid">
          <div v-for="o in outbounds" :key="o.tag" class="exit">
            <div class="exit-head">
              <b>{{ o.label }}</b>
              <Status v-if="probe(o.tag)" :kind="probe(o.tag).ok ? 'good' : 'bad'" :text="probe(o.tag).ok ? '可用' : '失败'" />
              <span v-else class="tag">{{ o.probe ? '待探测' : '不支持探测' }}</span>
            </div>
            <span class="exit-ip">{{ probe(o.tag)?.exit_ip || '—' }}</span>
            <span class="small muted">{{ probe(o.tag)?.geo ? probe(o.tag).geo.location + ' · ' + probe(o.tag).geo.isp : o.type + (o.server ? ' · ' + o.server : '') }}</span>
            <div class="latency">
              <span>当前 {{ rate(outRate(o.tag)) }}</span>
              <span v-for="(v, k) in (probe(o.tag)?.targets || {})" :key="k">{{ k }} {{ v.ok ? v.total_ms + ' ms' : '✕' }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="grid cols-2">
      <section class="card">
        <div class="card-head"><div><h2>热门目标</h2><p>最近 24 小时，按流量</p></div><NavLink class="btn sm" to="history" :query="{ since: '24h' }">全部</NavLink></div>
        <div class="card-body">
          <ol class="rank">
            <li v-for="r in topDomains" :key="r.k">
              <div class="r-top"><span :title="r.k">{{ r.k }}</span><span class="num muted">{{ bytes(r.upload + r.download) }}</span></div>
              <div class="bar-track"><div class="bar-fill" :style="{ width: pct(r, topDomains) }"></div></div>
            </li>
            <li v-if="!topDomains.length" class="muted small">暂无数据</li>
          </ol>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>活跃客户端</h2><p>最近 24 小时，按流量</p></div><NavLink class="btn sm" to="clients">全部</NavLink></div>
        <div class="card-body">
          <ol class="rank">
            <li v-for="r in topIps" :key="r.k">
              <div class="r-top">
                <span><IpCell :ip="r.k" /> <span class="muted small">{{ r.location }} · {{ r.isp }}</span></span>
                <span class="num muted">{{ bytes(r.upload + r.download) }}<span v-if="online(r.k)" class="tag on">{{ online(r.k) }} 在线</span></span>
              </div>
              <div class="bar-track"><div class="bar-fill" :style="{ width: pct(r, topIps) }"></div></div>
            </li>
            <li v-if="!topIps.length" class="muted small">暂无数据</li>
          </ol>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import NavLink from '../components/NavLink.vue'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import Chart from '../components/Chart.vue'
import Kpi from '../components/Kpi.vue'
import Seg from '../components/Seg.vue'
import Status from '../components/Status.vue'
import IpCell from '../components/IpCell.vue'
import { state, label, outboundTags, inboundKeys } from '../lib/state.js'
import { get } from '../lib/api.js'
import { bytes, rate, num, datetime } from '../lib/format.js'
import { realtimeOption, sparkOption, trendOption } from '../lib/options.js'

const ranges = [{ value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }]
const liveMode = ref('total')
const trendBy = ref('outbound')
const trendRange = ref('24h')
const trend = ref(null)
const probes = ref({})
const topDomains = ref([])
const topIps = ref([])

const totals = computed(() => state.overview?.totals || { upload: 0, download: 0, today_upload: 0, today_download: 0, connections: 0, ips: 0 })
const since = computed(() => totals.value.tracking_since ? datetime(totals.value.tracking_since).slice(0, 10) : '—')
const liveUp = computed(() => state.frame?.up || 0)
const liveDown = computed(() => state.frame?.down || 0)
const outbounds = computed(() => state.overview?.topology?.outbounds || [])

const sparkTotal = computed(() => sparkOption(state.tokens, state.samples.slice(-120).map(s => s.up + s.down), state.tokens.down))
const realtime = computed(() => realtimeOption(state.tokens, state.samples, liveMode.value, outboundTags(), tag => label('outbound', tag)))
const trendKeys = computed(() => trendBy.value === 'inbound' ? inboundKeys() : outboundTags())
const trendChart = computed(() => trendOption(state.tokens, trend.value, trendKeys.value, k => label(trendBy.value === 'inbound' ? 'inbound' : 'outbound', k), { split: !trendBy.value }))
const trendNote = computed(() => {
  const d = trend.value
  if (!d) return '加载中…'
  const unit = d.step >= 3600 ? (d.step / 3600) + ' 小时' : (d.step / 60) + ' 分钟'
  const est = d.source === 'series_hour' && d.estimated_before && d.buckets[0] < d.estimated_before ? '；升级前的小时数据按连接最后活动时间估算' : d.source === 'series_minute' && d.series_since && d.buckets[0] < d.series_since ? '；分钟级数据自升级时开始记录' : ''
  return '每柱 ' + unit + est
})
const probeNote = computed(() => {
  const at = Math.max(0, ...Object.values(probes.value).map(p => p.at || 0))
  return at ? '最近探测 ' + datetime(at * 1000) + '；实时速率来自内核事件' : (state.overview?.features?.probes ? '首次探测将在服务启动后数分钟内完成' : '出口探测已关闭')
})

const probe = tag => probes.value[tag]
const outRate = tag => (state.frame?.out?.[tag] || [0, 0]).reduce((a, b) => a + b, 0)
const online = ip => state.frame?.ips?.[ip]?.online || 0
const pct = (r, list) => {
  const max = Math.max(1, ...list.map(x => x.upload + x.download))
  return Math.max(2, (r.upload + r.download) * 100 / max) + '%'
}

async function loadTrend() {
  trend.value = await get('api/series', { range: trendRange.value, by: trendBy.value })
}
async function loadSide() {
  const [p, d, i] = await Promise.all([get('api/probes', { hours: 1 }), get('api/top', { by: 'domain', range: '24h', limit: 8 }), get('api/top', { by: 'ip', range: '24h', limit: 6 })])
  probes.value = p.latest
  topDomains.value = d.rows
  topIps.value = i.rows
}
watch([trendBy, trendRange], loadTrend)
let timer = null
onMounted(() => {
  loadTrend()
  loadSide()
  timer = setInterval(() => { if (!document.hidden) { loadTrend(); loadSide() } }, 60000)
})
onBeforeUnmount(() => clearInterval(timer))
</script>
