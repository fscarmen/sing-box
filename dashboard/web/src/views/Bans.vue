<template>
  <div class="grid">
    <section class="card">
      <div class="card-head"><div><h2>封禁地址</h2><p>支持单个公网 IP 或网段（IPv4 ≥ /{{ minV4 }}，IPv6 ≥ /{{ minV6 }}）。防火墙规则只作用于{{ scope }}节点公网端口 {{ ports }}，监听回环、经 Nginx 转发的入口由回源网关负责。</p></div></div>
      <div class="card-body">
        <form class="toolbar" @submit.prevent="submit">
          <input v-model="form.ip" class="input" required placeholder="公网 IP 或网段，如 203.0.113.7 或 203.0.113.0/24" aria-label="地址或网段" size="34">
          <input v-model="form.reason" class="input" maxlength="160" placeholder="备注（可选）" aria-label="备注">
          <select v-model.number="form.duration" class="input" aria-label="时长">
            <option :value="0">永久</option><option :value="3600">1 小时</option><option :value="86400">24 小时</option><option :value="604800">7 天</option><option :value="2592000">30 天</option>
          </select>
          <button class="btn danger" type="submit">封禁</button>
        </form>
      </div>
    </section>
    <section class="card">
      <div class="card-head"><div><h2>封禁名单</h2><p>到期的封禁会自动解除并写入审计日志。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="columns" :rows="rows" sort="created" empty="暂无封禁">
          <template #cell-ip="{ row }"><span class="mono">{{ row.ip }}</span><span class="sub">{{ row.location }} · {{ row.isp }}</span></template>
          <template #cell-created="{ row }">{{ datetime(row.created * 1000) }}</template>
          <template #cell-expires="{ row }">{{ row.expires ? datetime(row.expires * 1000) : '永久' }}<span v-if="row.expires" class="sub">剩余 {{ duration(row.expires - now / 1000) }}</span></template>
          <template #cell-action="{ row }"><button class="btn sm" type="button" @click="unban(row)">解除</button></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import DataTable from '../components/DataTable.vue'
import { get } from '../lib/api.js'
import { banFlow } from '../lib/actions.js'
import { datetime, duration, endpointText } from '../lib/format.js'
import { state, toast } from '../lib/state.js'

const rows = ref([])
const now = ref(Date.now())
const ports = ref('—')
const scope = ref('')
const minV4 = ref(16)
const minV6 = ref(32)
const form = reactive({ ip: '', reason: '', duration: 0 })
const columns = [
  { key: 'ip', label: '地址 / 网段' }, { key: 'reason', label: '备注', class: 'wrap' }, { key: 'created', label: '封禁时间' },
  { key: 'expires', label: '到期' }, { key: 'action', label: '', sortable: false },
]
async function load() {
  try {
    rows.value = (await get('api/bans')).rows
    now.value = Date.now()
    const sys = await get('api/system')
    ports.value = endpointText(sys.firewall) || '（未发现公网入站）'
    scope.value = sys.firewall.xray ? (state.overview?.singbox_enabled ? ' sing-box 与 Xray ' : ' Xray ') : ' sing-box '
    minV4.value = sys.settings.values.firewall.min_prefix_v4
    minV6.value = sys.settings.values.firewall.min_prefix_v6
  } catch (e) { toast(e.message, 'error') }
}
async function submit() {
  if (await banFlow(form.ip.trim(), false, form.reason, form.duration)) {
    form.ip = ''
    form.reason = ''
    load()
  }
}
async function unban(row) { if (await banFlow(row.ip, true)) load() }
onMounted(load)
</script>
