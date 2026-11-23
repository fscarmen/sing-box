<template>
  <div class="grid">
  <section class="card">
    <div class="card-head">
      <div><h2>连接历史{{ ip ? ' · ' + ip : '' }}</h2><p>按 来源 IP + 目标 + 协议 + 入口 合并；时间范围按连接最近活动时间选取，显示其完整累计流量。</p></div>
      <div class="toolbar">
        <input v-model="query" class="input" type="search" placeholder="搜索 IP、域名、入口、出口" aria-label="搜索历史" @input="debounced">
        <Seg v-model="since" :options="ranges" label="时间范围" />
        <button v-if="ip" class="btn sm" type="button" @click="ip = ''">全部 IP</button>
        <ExportLink kind="history" :params="{ ip, q: query, since }" />
      </div>
    </div>
    <p v-if="state.overview?.features?.client_rules" class="history-note small muted">客户端规则列按当前已发布规则推算，不代表历史连接或设备实际已应用。直连流量不经过 VPS 时不会记录。</p>
    <div class="card-body flush">
      <DataTable :columns="columns" :rows="rows" :total="total" :page-size="limit" :sort="sort" :dir="dir" :loading="loading" @sort="onSort" @page="onPage" ref="table">
        <template #cell-client_rules="{ row }"><div class="rule-cell"><span class="small muted">{{ row.client_rule ? ruleActions[row.client_rule.action] : '基础规则' }}</span><button v-if="row.client_rule_target" class="btn sm" @click="selectedTarget = row">设置规则</button><span v-else class="small muted">目标不可识别</span></div></template>
        <template #cell-ip="{ row }"><IpCell :ip="row.ip" /></template>
        <template #cell-domain="{ row }"><span :title="row.domain">{{ row.domain }}</span></template>
        <template #cell-inbound="{ row }">{{ label('inbound', row.inbound) }}</template>
        <template #cell-outbounds="{ row }"><span v-for="o in (row.outbounds || '').split(',').filter(Boolean)" :key="o" class="legend-key"><i :class="swatch(o)"></i>{{ label('outbound', o) }}&nbsp;</span></template>
        <template #cell-online="{ row }"><span class="tag" :class="{ on: row.online }">{{ row.online }}</span></template>
        <template #cell-upload="{ row }">{{ bytes(row.upload) }}</template>
        <template #cell-download="{ row }">{{ bytes(row.download) }}</template>
        <template #cell-total="{ row }">{{ bytes(row.total) }}</template>
        <template #cell-last_seen="{ row }"><span :title="datetime(row.last_seen)">{{ ago(row.last_seen) }}</span></template>
      </DataTable>
    </div>
  </section>
  <ClientRuleDialog v-if="selectedTarget" :initial="{...selectedTarget.client_rule_target, action: selectedTarget.client_rule?.action || 'proxy', note: '来自连接历史'}" :matched="selectedTarget.client_rule" from-history @close="selectedTarget = null" @saved="rulesSaved" />
  </div>
</template>

<script setup>
import ExportLink from '../components/ExportLink.vue'
import { computed, onMounted, ref, watch } from 'vue'
import ClientRuleDialog from '../components/ClientRuleDialog.vue'
import { ruleActions } from '../lib/clientRules.js'
import DataTable from '../components/DataTable.vue'
import IpCell from '../components/IpCell.vue'
import Seg from '../components/Seg.vue'
import Icon from '../components/Icon.vue'
import { get } from '../lib/api.js'
import { state, label, outboundTags, toast } from '../lib/state.js'
import { route } from '../lib/router.js'
import { ago, bytes, datetime } from '../lib/format.js'

const ranges = [{ value: 'all', label: '全部' }, { value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }]
const baseColumns = [
  { key: 'ip', label: '来源 IP' }, { key: 'domain', label: '目标' }, { key: 'protocol', label: '协议' }, { key: 'inbound', label: '入口' },
  { key: 'outbounds', label: '出口' }, { key: 'connections', label: '合并连接', align: 'right', format: v => (v || 0).toLocaleString('zh-CN') },
  { key: 'online', label: '在线', align: 'right' }, { key: 'upload', label: '上传', align: 'right' }, { key: 'download', label: '下载', align: 'right' },
  { key: 'total', label: '总流量', align: 'right' }, { key: 'last_seen', label: '最近活动', align: 'right' },
]
const selectedTarget = ref(null)
const columns = computed(() => state.overview?.features?.client_rules ? [...baseColumns, {key: 'client_rules', label: '客户端规则', sortable: false}] : baseColumns)
function rulesSaved() { toast('规则已发布，请在客户端更新对应配置'); load() }
const limit = 100
const rows = ref([])
const total = ref(0)
const loading = ref(true)
const ip = ref(route.query.ip || '')
const query = ref(route.query.q || '')
const since = ref(route.query.since || 'all')
const sort = ref('last_seen')
const dir = ref('desc')
const offset = ref(0)
const table = ref(null)
const swatch = tag => { const i = outboundTags().indexOf(tag); return i >= 0 && i < 8 ? 'sw-' + (i + 1) : 'sw-muted' }

async function load() {
  loading.value = true
  try {
    const d = await get('api/history', { ip: ip.value, q: query.value, since: since.value, sort: sort.value, dir: dir.value, limit, offset: offset.value })
    rows.value = d.rows
    total.value = d.total
  } catch (e) { toast(e.message, 'error') }
  loading.value = false
}
function restart() { offset.value = 0; table.value && table.value.reset(); load() }
let pending = null
function debounced() { clearTimeout(pending); pending = setTimeout(restart, 300) }
function onSort(e) { sort.value = e.key; dir.value = e.dir; restart() }
function onPage(e) { offset.value = e.offset; load() }
watch([since, ip], restart)
watch(() => route.query.ip, v => { ip.value = v || '' })
onMounted(load)
</script>

<style scoped>
.history-note { padding: 0 22px 12px; margin: 0; }
.rule-cell { display: flex; align-items: center; gap: 8px; white-space: nowrap; }
</style>
