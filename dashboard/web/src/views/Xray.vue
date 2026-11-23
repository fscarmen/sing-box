<template>
  <div class="grid">
    <section class="card">
      <div class="card-head"><div><h2>Xray 节点监控</h2><p>{{ data?.scope || '正在读取 Xray 原生统计…' }}</p></div><button class="btn sm" :disabled="data?.probe_running" @click="probeNow">{{ data?.probe_running ? '探测中…' : '探测媒体出口' }}</button></div>
      <div class="card-body"><p v-if="data && !data.enabled">尚未配置 Xray 实例。</p><p class="small muted">{{ data?.limitations }}</p><p v-if="data?.probe_error">最近探测未完成：{{ data.probe_error }}，下方保留上次结果及时间。</p><div class="toolbar"><span v-for="i in data?.instances || []" :key="i.id" class="legend-key"><Status :kind="i.connected ? 'good' : 'bad'" :text="i.label + (i.connected ? ' · 已连接' : ' · ' + i.error)" /></span></div></div>
    </section>
    <div v-if="data?.enabled" class="grid cols-4">
      <Kpi label="Xray 节点" :value="String(data.nodes.length)"><span>连接成功 {{ data.instances.filter(i => i.connected).length }} / {{ data.instances.length }} 个实例</span></Kpi>
      <Kpi label="Xray 实时速率" :value="allConnected && totals.rates_ready ? rate(totals.up_rate + totals.down_rate) : '—'"><span v-if="totals.rates_ready">↓ {{ rate(totals.down_rate) }} · ↑ {{ rate(totals.up_rate) }}</span><span v-else>等待连续有效采样</span></Kpi>
      <Kpi label="Xray 今日流量" :value="bytes(totals.today_upload + totals.today_download)"><span>仅累计入站字节，出站不重复相加</span></Kpi>
      <Kpi label="Xray 接入后累计" :value="bytes(totals.upload + totals.download)"><span>保留独立持久账本，重启不清零</span></Kpi>
    </div>
    <section v-if="data?.enabled" class="card">
      <div class="card-head"><div><h2>最近 24 小时流量</h2><p>每分钟真实采样增量；无采样的时段留空。</p></div></div>
      <div class="card-body"><Chart :option="chart" height="230px" label="Xray 每分钟上下行流量" replace /></div>
    </section>
    <section class="card">
      <div class="card-head"><div><h2>节点与媒体出口</h2><p>每 2 秒刷新。出口地址来自独立回显，媒体请求成功只代表 HTTPS 可达。</p></div><select v-model="instance" class="input" aria-label="筛选 Xray 实例"><option value="">全部实例</option><option v-for="i in data?.instances || []" :key="i.id" :value="i.id">{{ i.label }}</option></select></div>
      <div class="card-body flush"><DataTable :columns="columns" :rows="rows" row-key="key" :loading="loading" :page-size="50" empty="等待 Xray 节点统计">
        <template #cell-label="{ row }"><b>{{ row.label }}</b><span class="sub">{{ instanceLabel(row.instance) }} · {{ row.protocol.toUpperCase() }}</span></template>
        <template #cell-transport="{ row }">{{ row.transport }}{{ row.tls ? ' + TLS' : '' }}<span class="sub">客户端端口 {{ row.port }}</span></template>
        <template #cell-speed="{ row }"><span>{{ row.fresh && row.down_rate != null ? '↓ ' + rate(row.down_rate) : '—' }}</span><span class="sub">{{ row.fresh && row.up_rate != null ? '↑ ' + rate(row.up_rate) : '等待有效采样' }}</span></template>
        <template #cell-total="{ row }">{{ bytes(row.upload + row.download) }}<span class="sub">今日 {{ bytes(row.today_upload + row.today_download) }}</span></template>
        <template #cell-online="{ row }">{{ row.online_sources == null ? '未提供' : row.online_sources.length + ' 个来源' }}<span v-if="row.online_sources?.length" class="sub">{{ row.online_sources.join('、') }}</span></template>
        <template #cell-exit="{ row }">{{ exit(row)?.exit_ip || '未检测' }}<span class="sub">{{ exit(row)?.at ? datetime(exit(row).at * 1000) : row.probe ? '等待探测' : '复杂路由，无法单一探测' }}</span></template>
        <template #cell-media="{ row }"><span v-for="name in mediaNames" :key="name" class="sub">{{ name }} {{ target(row, name) ? target(row, name).ok ? target(row, name).total_ms + ' ms' : '失败 · ' + target(row, name).error : '未检测' }}</span></template>
      </DataTable></div>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from 'vue'
import { get, post } from '../lib/api.js'
import { toast } from '../lib/state.js'
import { bytes, rate, datetime } from '../lib/format.js'
import Kpi from '../components/Kpi.vue'
import Chart from '../components/Chart.vue'
import Status from '../components/Status.vue'
import DataTable from '../components/DataTable.vue'

const data = ref(null), loading = ref(true), instance = ref('')
const mediaNames = computed(() => data.value?.probe_targets || ['Instagram', 'YouTube', 'Facebook'])
const totals = computed(() => data.value?.totals || {})
const allConnected = computed(() => data.value?.instances?.every(i => i.connected))
const rows = computed(() => (data.value?.nodes || []).filter(n => !instance.value || n.instance === instance.value))
const columns = [{ key: 'label', label: '节点' }, { key: 'transport', label: '传输' }, { key: 'speed', label: '速率' }, { key: 'total', label: '累计 / 今日' }, { key: 'online', label: '在线来源（核心口径）' }, { key: 'exit', label: '实测出口' }, { key: 'media', label: '媒体 HTTPS' }]
const instanceLabel = id => data.value?.instances.find(i => i.id === id)?.label || id
const target = (row, name) => data.value?.probes[row.instance + ':' + row.outbound]?.targets[name]
const exit = row => {
  const p = data.value?.probes[row.instance + ':' + row.outbound]
  const trace = p?.targets.trace
  return trace?.ok && trace.exit_ip ? { exit_ip: trace.exit_ip, at: p.at } : null
}
const chart = computed(() => ({
  animation: false, grid: { left: 65, right: 15, top: 30, bottom: 30 }, legend: { data: ['上传', '下载'] },
  tooltip: { trigger: 'axis' }, xAxis: { type: 'time' }, yAxis: { type: 'value', axisLabel: { formatter: v => bytes(v) } },
  series: ['upload', 'download'].map((key, index) => ({ name: ['上传', '下载'][index], type: 'bar', stack: 'bytes', data: (data.value?.series || []).map(r => [r.ts * 1000, r[key]]) })),
}))
async function load() {
  try { data.value = await get('api/xray') } catch (e) { toast(e.message, 'error') }
  loading.value = false
}
async function probeNow() {
  try { await post('api/xray/probes/run'); await load() } catch (e) { toast(e.message, 'error') }
}
let timer
onMounted(() => { load(); timer = setInterval(() => { if (!document.hidden) load() }, 2000) })
onBeforeUnmount(() => clearInterval(timer))
</script>
