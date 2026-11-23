<template>
  <div class="grid">
    <div class="grid cols-4">
      <Kpi label="网卡实时" :value="rate(nicNow.rx + nicNow.tx)">
        <span class="legend-key"><i class="sw-1"></i>收 {{ rate(nicNow.rx) }}</span>
        <span class="legend-key"><i class="sw-2"></i>发 {{ rate(nicNow.tx) }}</span>
        <template #spark><Chart :option="spark" height="44px" label="最近两分钟网卡速率" /></template>
      </Kpi>
      <Kpi :label="todayLabel" :value="bytes(today.rx + today.tx)">
        <span>收 {{ bytes(today.rx) }} · 发 {{ bytes(today.tx) }}</span>
        <span>代理载荷 {{ bytes(today.payload) }}<template v-if="today.payload"> · {{ ratio(today) }} 倍</template></span>
      </Kpi>
      <Kpi label="客户端直连 RTT" :value="ms(seg.client?.rtt)">
        <span v-if="seg.client">{{ seg.client.keys }} 个客户端 · {{ seg.client.conns }} 条连接</span>
        <span v-if="seg.client">重传 {{ pct(seg.client.retrans_pct) }}</span>
        <span v-else>当前没有直连入口连接</span>
      </Kpi>
      <Kpi label="CDN 回源 / 上游 RTT" :value="ms(seg.edge?.rtt) + ' / ' + ms(seg.upstream?.rtt)">
        <span>回源重传 {{ pct(seg.edge?.retrans_pct) }}</span>
        <span>直连目标 {{ ms(seg.direct?.rtt) }}</span>
      </Kpi>
    </div>

    <section class="card">
      <div class="card-head">
        <div><h2>实时网卡吞吐</h2><p>{{ ifaceText }}，每秒采样。网卡流量含协议开销、代理进出两段、SSH 与面板，即 VPS 实际收发。</p></div>
      </div>
      <div class="card-body"><Chart :option="liveChart" height="240px" label="实时网卡吞吐折线图" /></div>
    </section>

    <section class="card">
      <div class="card-head">
        <div><h2>网卡流量与代理载荷</h2><p>柱为网卡收发，折线为 sing-box 统计的代理载荷（上下行合计）。每个代理字节进出网卡各一次，正常比值约 2 倍略多，多出的部分是协议与重传开销。{{ sinceText }}</p></div>
        <Seg v-model="range" :options="ranges" label="时间范围" />
      </div>
      <div class="card-body"><Chart v-if="data" :option="trafficChart" height="260px" label="网卡流量与代理载荷柱状图" replace /></div>
    </section>

    <section class="card">
      <div class="card-head">
        <div><h2>链路质量趋势</h2><p>每 {{ data?.quality.interval || 60 }} 秒读取一次 TCP 连接的平滑 RTT 与重传；按分段汇总，客户端按连接数加权。{{ data && !data.quality.enabled ? '采样已关闭。' : '' }}</p></div>
        <div class="toolbar">
          <Seg v-model="metric" :options="[{ value: 'rtt', label: 'RTT' }, { value: 'retrans_pct', label: '重传率' }]" label="指标" />
          <Seg v-model="range" :options="ranges" label="时间范围" />
        </div>
      </div>
      <div class="card-body"><Chart v-if="data" :option="qualityChart" height="260px" :label="metric === 'rtt' ? '各分段 RTT 折线图' : '各分段重传率折线图'" replace /></div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>分段说明</h2><p>最近一次采样（{{ latestAt }}）。CDN 入口的客户端在 CDN 边缘终止 TCP，服务器只能测到边缘回源这一段。</p></div></div>
      <div class="card-body">
        <div class="exit-grid">
          <div v-for="s in SEGMENTS" :key="s" class="exit">
            <div class="exit-head">
              <b class="legend-key"><i :class="'sw-' + (SEGMENTS.indexOf(s) + 1)"></i>{{ SEGMENT_NAMES[s] }}</b>
              <Status v-if="seg[s]" :kind="rttKind(s, seg[s].rtt)" :text="rttText(s, seg[s].rtt)" />
              <span v-else class="tag">无连接</span>
            </div>
            <span class="exit-ip">{{ ms(seg[s]?.rtt) }}<span class="small muted"> · P90 {{ ms(seg[s]?.rtt_p90) }}</span></span>
            <span class="small muted">{{ SEGMENT_NOTES[s] }}</span>
            <span class="small muted">{{ seg[s] ? seg[s].conns + ' 条连接 · 重传 ' + pct(seg[s].retrans_pct) + ' · 本轮发送 ' + bytes(seg[s].sent) : '—' }}</span>
          </div>
        </div>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>客户端直连质量</h2><p>所选范围内各客户端到 VPS 的 RTT 与重传（仅直连入口）；点击 IP 查看详情。RTT 低于 150 ms 为良好，高于 250 ms 偏慢；重传率高于 3% 说明线路丢包明显。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="clientCols" :rows="clients" row-key="key" sort="sent" :loading="!data" empty="所选范围内没有直连入口连接">
          <template #cell-key="{ row }"><IpCell :ip="row.key" /></template>
          <template #cell-isp="{ row }">{{ row.isp }}<span v-if="row.asn" class="sub">AS{{ row.asn }}</span></template>
          <template #cell-rtt="{ row }"><Status :kind="rttKind('client', row.rtt)">{{ ms(row.rtt) }}</Status></template>
          <template #cell-retrans_pct="{ row }"><Status :kind="lossKind(row.retrans_pct)">{{ pct(row.retrans_pct) }}</Status></template>
          <template #cell-last="{ row }">{{ ago(row.last * 1000) }}</template>
        </DataTable>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>服务器侧链路</h2><p>CDN 回源、上游代理（家宽出口）与直连目标的 RTT；上游 RTT 只是 VPS 到代理入口，不含代理之后的路程。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="serverCols" :rows="serverRows" row-key="id" sort="sent" hide-foot :loading="!data" empty="暂无样本">
          <template #cell-name="{ row }"><span class="legend-key"><i :class="'sw-' + (SEGMENTS.indexOf(row.segment) + 1)"></i>{{ row.name }}</span></template>
          <template #cell-rtt="{ row }"><Status :kind="rttKind(row.segment, row.rtt)">{{ ms(row.rtt) }}</Status></template>
          <template #cell-retrans_pct="{ row }"><Status :kind="lossKind(row.retrans_pct)">{{ pct(row.retrans_pct) }}</Status></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import Chart from '../components/Chart.vue'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import Kpi from '../components/Kpi.vue'
import Seg from '../components/Seg.vue'
import Status from '../components/Status.vue'
import { get } from '../lib/api.js'
import { ago, bytes, datetime, rate, shortTime } from '../lib/format.js'
import { label, state, toast } from '../lib/state.js'
import { nicLiveOption, nicTrafficOption, qualityOption, sparkOption } from '../lib/options.js'

const SEGMENTS = ['client', 'edge', 'upstream', 'direct']
const SEGMENT_NAMES = { client: '客户端 → VPS', edge: 'CDN 边缘 → 源站', upstream: 'VPS → 上游代理', direct: 'VPS → 直连目标' }
const SEGMENT_NOTES = {
  client: '直连入口（如 Reality）的客户端连接，反映客户端到 VPS 的线路',
  edge: 'CDN 节点回源到源站 TLS 端口的连接',
  upstream: 'sing-box 到家宽等上游代理入口',
  direct: 'sing-box 直接访问目标网站',
}
// Good / slow thresholds per segment (ms); the client leg crosses the ocean, the others usually do not.
const RTT_LIMITS = { client: [150, 250], edge: [180, 280], upstream: [50, 150], direct: [80, 200] }
const ranges = [{ value: '6h', label: '6 小时' }, { value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }]

const data = ref(null)
const range = ref('24h')
const metric = ref('rtt')
const live = ref([])

const ms = v => (v == null ? '—' : (v >= 10 ? Math.round(v) : Number(v).toFixed(1)) + ' ms')
const pct = v => (v == null ? '—' : Number(v).toFixed(v >= 1 ? 1 : 2) + '%')
const ratio = r => (r.payload ? ((r.rx + r.tx) / r.payload).toFixed(2) : '—')
const rttKind = (segment, v) => { const [good, slow] = RTT_LIMITS[segment] || [150, 250]; return v == null ? 'warn' : v <= good ? 'good' : v <= slow ? 'warn' : 'bad' }
const rttText = (segment, v) => ({ good: '良好', warn: '一般', bad: '偏慢' })[rttKind(segment, v)]
const lossKind = v => (v <= 1 ? 'good' : v <= 3 ? 'warn' : 'bad')

const nicNow = computed(() => state.frame?.nic || data.value?.current || { rx: 0, tx: 0 })
const today = computed(() => data.value?.totals.today || { rx: 0, tx: 0, payload: 0 })
// Counting may have started part-way through today; say so instead of comparing unequal periods.
const todayLabel = computed(() => {
  const from = data.value?.totals.today.from
  const midnight = new Date().setHours(0, 0, 0, 0) / 1000
  return from && from > midnight + 60 ? '网卡流量（' + shortTime(from * 1000, true) + ' 起）' : '今日网卡流量'
})
const seg = computed(() => data.value?.quality.latest.segments || {})
const latestAt = computed(() => data.value?.quality.latest.at ? datetime(data.value.quality.latest.at * 1000) : '尚未采样')
const ifaceText = computed(() => '接口 ' + ((data.value?.interfaces || []).join('、') || '—'))
const sinceText = computed(() => data.value?.since ? '网卡统计自 ' + datetime(data.value.since * 1000) + ' 起。' : '')

const spark = computed(() => sparkOption(state.tokens, live.value.slice(-120).map(s => s.rx + s.tx), state.tokens.series?.[0]))
const liveChart = computed(() => nicLiveOption(state.tokens, live.value))
const trafficChart = computed(() => nicTrafficOption(state.tokens, data.value.traffic))
const qualityChart = computed(() => qualityOption(state.tokens, data.value.quality.series, SEGMENTS, s => SEGMENT_NAMES[s], metric.value))

const clientCols = [
  { key: 'key', label: 'IP 地址' }, { key: 'location', label: '地区' }, { key: 'isp', label: '运营商 / ASN' },
  { key: 'rtt', label: '平均 RTT', align: 'right' }, { key: 'rtt_p90', label: 'P90', align: 'right', format: ms },
  { key: 'min_rtt', label: '最低', align: 'right', format: ms }, { key: 'retrans_pct', label: '重传率', align: 'right' },
  { key: 'peak_conns', label: '峰值连接', align: 'right' }, { key: 'sent', label: '发送量', align: 'right', format: v => bytes(v) },
  { key: 'last', label: '最近样本', align: 'right' },
]
const clients = computed(() => (data.value?.quality.keys || []).filter(r => r.segment === 'client'))
const serverCols = [
  { key: 'name', label: '链路' }, { key: 'rtt', label: '平均 RTT', align: 'right' }, { key: 'rtt_p90', label: 'P90', align: 'right', format: ms },
  { key: 'min_rtt', label: '最低', align: 'right', format: ms }, { key: 'retrans_pct', label: '重传率', align: 'right' },
  { key: 'peak_conns', label: '峰值连接', align: 'right' }, { key: 'sent', label: '发送量', align: 'right', format: v => bytes(v) },
]
const serverRows = computed(() => (data.value?.quality.keys || []).filter(r => r.segment !== 'client').map(r => ({
  ...r, id: r.segment + ':' + r.key,
  name: r.segment === 'upstream' ? '上游 · ' + label('outbound', r.key) : SEGMENT_NAMES[r.segment],
})))

async function load() {
  if (document.hidden && data.value) return
  try {
    const next = await get('api/network', { range: range.value })
    if (!live.value.length) live.value = next.live
    data.value = next
  } catch (e) { toast(e.message, 'error') }
}

// Live NIC samples arrive with every realtime frame; keep five minutes.
watch(() => state.frame?.t, () => {
  const f = state.frame
  if (!f?.nic) return
  const last = live.value[live.value.length - 1]
  if (last && f.t - last.t < 500) return
  live.value = [...live.value.slice(-299), { t: f.t, rx: f.nic.rx, tx: f.nic.tx }]
})
watch(range, load)
let timer = null
onMounted(() => { load(); timer = setInterval(load, 30000) })
onBeforeUnmount(() => clearInterval(timer))
</script>
