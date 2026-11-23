<template>
  <section class="card">
    <div class="card-head">
      <div><h2>客户端 IP</h2><p>按来源 IP 的累计流量（自采集起）；点击 IP 查看详情。属地 / 运营商为离线库估计值。</p></div>
      <div class="toolbar">
        <input v-model="query" class="input" type="search" placeholder="搜索 IP、地区、运营商" aria-label="搜索客户端">
        <ExportLink kind="ips">导出 CSV</ExportLink>
      </div>
    </div>
    <div class="card-body flush">
      <DataTable :columns="columns" :rows="rows" row-key="ip" sort="total" :query="query" :search-keys="['ip', 'location', 'isp', 'asn']" :loading="loading">
        <template #cell-ip="{ row }"><IpCell :ip="row.ip" :banned="row.banned" /></template>
        <template #cell-location="{ row }">{{ row.location }}</template>
        <template #cell-isp="{ row }">{{ row.isp }}<span v-if="row.asn" class="sub">AS{{ row.asn }}</span></template>
        <template #cell-online="{ row }"><span class="tag" :class="{ on: row.online }">{{ row.online }}</span></template>
        <template #cell-rate="{ row }"><span v-if="row.online">↓ {{ rate(row.rd) }}<span class="sub">↑ {{ rate(row.ru) }}</span></span><span v-else class="muted">—</span></template>
        <template #cell-upload="{ row }">{{ bytes(row.upload) }}</template>
        <template #cell-download="{ row }">{{ bytes(row.download) }}</template>
        <template #cell-total="{ row }"><div class="bar-cell"><div class="bar-track"><div class="bar-fill" :style="{ width: share(row) }"></div></div><span>{{ bytes(row.total) }}</span></div></template>
        <template #cell-last_seen="{ row }">{{ ago(row.last_seen) }}</template>
        <template #cell-action="{ row }"><button class="btn sm" :class="row.banned ? '' : 'danger'" type="button" @click="toggleBan(row)">{{ row.banned ? '解除封禁' : '封禁' }}</button></template>
      </DataTable>
    </div>
  </section>
</template>

<script setup>
import ExportLink from '../components/ExportLink.vue'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import Icon from '../components/Icon.vue'
import { get } from '../lib/api.js'
import { bytes, rate, ago } from '../lib/format.js'
import { toast } from '../lib/state.js'
import { banFlow } from '../lib/actions.js'

const data = ref([])
const loading = ref(true)
const query = ref('')
const columns = [
  { key: 'ip', label: 'IP 地址' }, { key: 'location', label: '地区' }, { key: 'isp', label: '运营商 / ASN' },
  { key: 'online', label: '在线', align: 'right' }, { key: 'rate', label: '当前速率', align: 'right' },
  { key: 'connections', label: '累计连接', align: 'right', format: v => (v || 0).toLocaleString('zh-CN') },
  { key: 'upload', label: '上传', align: 'right' }, { key: 'download', label: '下载', align: 'right' },
  { key: 'total', label: '总流量', align: 'right' }, { key: 'last_seen', label: '最近活动', align: 'right' },
  { key: 'action', label: '', sortable: false },
]
const rows = computed(() => data.value.map(r => ({ ...r, rate: r.ru + r.rd })))
const max = computed(() => Math.max(1, ...data.value.map(r => r.total)))
const share = r => Math.max(1, r.total * 100 / max.value) + '%'

async function load() {
  if (document.hidden) return
  try { data.value = (await get('api/ips')).rows } catch (e) { toast(e.message, 'error') }
  loading.value = false
}
async function toggleBan(row) {
  if (await banFlow(row.ip, row.banned)) load()
}
let timer = null
onMounted(() => { load(); timer = setInterval(load, 5000) })
onBeforeUnmount(() => clearInterval(timer))
</script>
