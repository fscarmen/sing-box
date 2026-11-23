<template>
  <div class="grid">
    <section class="card">
      <div class="card-head"><div><h2>每日流量</h2><p>北京时间（按服务器时区设置）每日上传 / 下载，最近 {{ days.length }} 个有记录的日期；点击柱子筛选当天明细。</p></div></div>
      <div class="card-body"><Chart v-if="days.length" :option="chart" height="240px" label="每日流量柱状图" replace @chart-click="pick" /></div>
    </section>
    <section class="card">
      <div class="card-head">
        <div><h2>{{ day || '全部日期' }}{{ ip ? ' · ' + ip : '' }}</h2><p>按日期和 IP 分别统计；顶部总量为全节点合计。</p></div>
        <div class="toolbar">
          <input v-model="query" class="input" type="search" placeholder="搜索 IP、地区、运营商" aria-label="搜索">
          <select v-model="day" class="input" aria-label="日期"><option value="">全部日期</option><option v-for="d in days" :key="d.day" :value="d.day">{{ d.day }}</option></select>
          <button v-if="ip" class="btn sm" type="button" @click="ip = ''">全部 IP</button>
          <ExportLink kind="daily" :params="{ ip }" />
        </div>
      </div>
      <div class="card-body flush">
        <DataTable :columns="columns" :rows="filtered" sort="day" :query="query" :search-keys="['ip', 'location', 'isp', 'day']">
          <template #cell-ip="{ row }"><IpCell :ip="row.ip" /></template>
          <template #cell-upload="{ row }">{{ bytes(row.upload) }}</template>
          <template #cell-download="{ row }">{{ bytes(row.download) }}</template>
          <template #cell-total="{ row }">{{ bytes(row.total) }}</template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import ExportLink from '../components/ExportLink.vue'
import { computed, onMounted, ref, watch } from 'vue'
import Chart from '../components/Chart.vue'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import Icon from '../components/Icon.vue'
import { get } from '../lib/api.js'
import { state, toast } from '../lib/state.js'
import { route } from '../lib/router.js'
import { bytes, shortBytes } from '../lib/format.js'
import { axisBase, legendBase, tipRows, tooltipBase } from '../lib/charts.js'

const days = ref([])
const rowsRaw = ref([])
const day = ref('')
const ip = ref(route.query.ip || '')
const query = ref('')
const columns = [
  { key: 'day', label: '日期' }, { key: 'ip', label: 'IP 地址' }, { key: 'location', label: '地区' }, { key: 'isp', label: '运营商' },
  { key: 'upload', label: '上传', align: 'right' }, { key: 'download', label: '下载', align: 'right' }, { key: 'total', label: '总流量', align: 'right' },
]
const filtered = computed(() => rowsRaw.value.filter(r => !day.value || r.day === day.value).map(r => ({ ...r, total: r.upload + r.download })))
const chart = computed(() => {
  const t = state.tokens
  const list = [...days.value].reverse()
  return {
    grid: { left: 54, right: 12, top: 30, bottom: 26 },
    legend: legendBase(t, { data: ['下载', '上传'] }),
    tooltip: tooltipBase(t, { trigger: 'axis', axisPointer: { type: 'shadow', shadowStyle: { color: t.grid, opacity: 0.4 } },
      formatter: ps => tipRows(ps[0].axisValue, [...ps.map(p => ({ name: p.seriesName, value: bytes(p.value), color: p.color })), { name: '合计', value: bytes(ps.reduce((a, p) => a + p.value, 0)) }]) }),
    xAxis: { type: 'category', data: list.map(d => d.day), ...axisBase(t), axisLabel: { color: t.muted, fontSize: 11, formatter: v => v.slice(5) } },
    yAxis: { type: 'value', ...axisBase(t), axisLine: { show: false }, axisLabel: { color: t.muted, fontSize: 11, formatter: v => shortBytes(v) } },
    series: [
      { name: '下载', type: 'bar', stack: 'd', barMaxWidth: 26, itemStyle: { color: t.down }, data: list.map(d => d.download) },
      { name: '上传', type: 'bar', stack: 'd', barMaxWidth: 26, itemStyle: { color: t.up, borderRadius: [4, 4, 0, 0] }, data: list.map(d => d.upload) },
    ],
  }
})
function pick(p) { if (p.name) day.value = day.value === p.name ? '' : p.name }
async function load() {
  try {
    const d = await get('api/daily', { days: 30, ip: ip.value })
    days.value = d.days
    rowsRaw.value = d.rows
  } catch (e) { toast(e.message, 'error') }
}
watch(ip, load)
onMounted(load)
</script>
