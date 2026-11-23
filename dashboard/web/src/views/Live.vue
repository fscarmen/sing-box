<template>
  <div class="grid">
    <section class="card">
      <div class="card-head">
        <div><h2>当前连接（sing-box）</h2><p>每 2 秒刷新；速率为最近一个采样周期的平均值。断开只关闭这一条连接，客户端通常会自动重连。Xray 的节点统计位于“Xray 节点”，不提供逐连接字节。</p></div>
        <div class="toolbar">
          <input v-model="query" class="input" type="search" placeholder="搜索 IP、目标、规则…" aria-label="搜索连接">
          <select v-model="outbound" class="input" aria-label="按出口筛选">
            <option value="">全部出口</option>
            <option v-for="o in outbounds" :key="o.tag" :value="o.tag">{{ o.label }}</option>
          </select>
          <button class="btn sm" type="button" @click="paused = !paused"><Icon :name="paused ? 'play' : 'pause'" :size="14" />{{ paused ? '继续' : '暂停' }}</button>
        </div>
      </div>
      <div class="card-body flush">
        <DataTable :columns="columns" :rows="filtered" row-key="id" sort="rate" :query="''" :page-size="100" :loading="loading" empty="当前没有活动连接" :note="ipNote">
          <template #cell-ip="{ row }"><IpCell :ip="row.ip" :sub="geo(row.ip)" /></template>
          <template #cell-domain="{ row }"><span :title="row.destination">{{ row.domain }}</span><span class="sub">{{ row.protocol }}</span></template>
          <template #cell-inbound="{ row }">{{ label('inbound', row.inbound) }}</template>
          <template #cell-rule_label="{ row }"><span class="tag" :title="row.rule">{{ ruleText(row.rule_label) }}</span></template>
          <template #cell-outbound="{ row }"><span class="legend-key"><i :class="swatch(row.outbound)"></i>{{ label('outbound', row.outbound) }}</span></template>
          <template #cell-rate="{ row }"><span>↓ {{ rate(row.rd) }}</span><span class="sub">↑ {{ rate(row.ru) }}</span></template>
          <template #cell-total="{ row }">{{ bytes(row.total) }}</template>
          <template #cell-age="{ row }">{{ duration(row.age) }}</template>
          <template #cell-action="{ row }"><button class="btn sm danger" type="button" @click="close(row)">断开</button></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import Icon from '../components/Icon.vue'
import { get, post } from '../lib/api.js'
import { state, label, outboundTags, ruleText, toast } from '../lib/state.js'
import { route } from '../lib/router.js'
import { bytes, rate, duration } from '../lib/format.js'
import { confirmAction } from '../lib/confirm.js'
import { useGeo } from '../lib/geo.js'

const rows = ref([])
const loading = ref(true)
const paused = ref(false)
const query = ref(route.query.q || '')
const outbound = ref('')
const { geo } = useGeo()
const outbounds = computed(() => state.overview?.topology?.outbounds || [])
const columns = [
  { key: 'ip', label: '来源' }, { key: 'domain', label: '目标' }, { key: 'inbound', label: '入口' },
  { key: 'rule_label', label: '分流规则' }, { key: 'outbound', label: '出口' },
  { key: 'rate', label: '速率', align: 'right' }, { key: 'total', label: '已传输', align: 'right' },
  { key: 'age', label: '时长', align: 'right' }, { key: 'action', label: '', sortable: false },
]
const filtered = computed(() => {
  const term = query.value.trim().toLowerCase()
  const now = Date.now()
  return rows.value
    .filter(r => !outbound.value || r.outbound === outbound.value)
    .filter(r => !term || [r.ip, r.domain, r.destination, r.rule_label, r.inbound, r.outbound].some(v => String(v || '').toLowerCase().includes(term)))
    .map(r => ({ ...r, rate: r.ru + r.rd, total: r.up + r.down, age: (now - r.started) / 1000 }))
})
const ipNote = computed(() => new Set(filtered.value.map(r => r.ip)).size + ' 个来源 IP')
const swatch = tag => { const i = outboundTags().indexOf(tag); return i >= 0 && i < 8 ? 'sw-' + (i + 1) : 'sw-muted' }

async function load() {
  if (paused.value || document.hidden) return
  try {
    rows.value = (await get('api/connections')).rows
  } catch (e) { toast(e.message, 'error') }
  loading.value = false
}
async function close(row) {
  const ok = await confirmAction({ title: '断开连接', message: '断开 ' + row.ip + ' → ' + row.domain + '？', confirm: '断开', danger: true })
  if (!ok) return
  try {
    const r = await post('api/connections/close', { id: row.id })
    toast(r.ok ? '已断开' : '连接可能已结束', r.ok ? 'ok' : 'info')
    load()
  } catch (e) { toast(e.message, 'error') }
}
let timer = null
onMounted(() => { load(); timer = setInterval(load, 2000) })
onBeforeUnmount(() => clearInterval(timer))
</script>
