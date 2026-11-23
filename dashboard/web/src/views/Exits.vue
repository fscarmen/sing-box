<template>
  <div class="grid">
    <section class="card">
      <div class="card-head">
        <div><h2>出口节点</h2><p>面板每 {{ Math.round((data?.interval || 300) / 60) }} 分钟经各出站探测：trace 类目标回显确认出口 IP，其他目标（{{ targets.filter(t => t.value !== 'trace').map(t => t.label).join('、') || '无' }}）检查 HTTPS 可达性与耗时。成功不代表视频播放、账号登录或带宽测速通过。{{ data && !data.enabled ? '探测已关闭。' : '' }}</p></div>
        <button class="btn sm primary" type="button" :disabled="running" @click="runNow"><Icon name="refresh" :size="14" />{{ running ? '探测中…' : '立即探测' }}</button>
      </div>
      <div class="card-body">
        <div class="exit-grid">
          <div v-for="o in outbounds" :key="o.tag" class="exit">
            <div class="exit-head">
              <b class="legend-key"><i :class="swatch(o.tag)"></i>{{ o.label }}</b>
              <Status v-if="latest[o.tag]" :kind="latest[o.tag].ok ? 'good' : 'bad'" :text="latest[o.tag].ok ? '可用' : '失败'" />
              <span v-else class="tag">{{ o.probe ? '待探测' : '不支持' }}</span>
            </div>
            <span class="exit-ip">{{ latest[o.tag]?.exit_ip || '—' }}</span>
            <span class="small muted">{{ latest[o.tag]?.geo ? latest[o.tag].geo.location : '' }}</span>
            <span class="small muted">{{ latest[o.tag]?.geo ? latest[o.tag].geo.isp + (latest[o.tag].geo.asn ? ' · AS' + latest[o.tag].geo.asn : '') : o.type + (o.server ? ' · ' + o.server + ':' + o.port : '') }}</span>
            <dl class="kv small">
              <template v-for="(v, k) in (latest[o.tag]?.targets || {})" :key="k">
                <dt>{{ k }}</dt>
                <dd><Status :kind="v.ok ? 'good' : 'bad'">{{ v.ok ? v.total_ms + ' ms' + (v.colo ? ' · ' + v.colo : '') : (v.error || '失败') }}</Status></dd>
              </template>
            </dl>
            <span v-if="latest[o.tag]" class="small muted">{{ datetime(latest[o.tag].at * 1000) }}</span>
          </div>
        </div>
      </div>
    </section>
    <section class="card">
      <div class="card-head">
        <div><h2>探测耗时</h2><p>最近 {{ hours }} 小时；空缺表示该轮失败。</p></div>
        <div class="toolbar">
          <Seg v-model="target" :options="targets" label="探测目标" />
          <Seg v-model="hours" :options="[{ value: 24, label: '24 小时' }, { value: 168, label: '7 天' }]" label="范围" />
        </div>
      </div>
      <div class="card-body"><Chart v-if="data" :option="latencyChart" height="260px" label="出口探测耗时折线图" replace /></div>
    </section>
    <section class="card">
      <div class="card-head"><div><h2>出口地址变化</h2><p>每个出站的公网地址变化记录（家宽出口可能轮换）。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="changeCols" :rows="changes" sort="at" hide-foot empty="暂无记录">
          <template #cell-outbound="{ row }">{{ label('outbound', row.outbound) }}</template>
          <template #cell-at="{ row }">{{ datetime(row.at * 1000) }}</template>
          <template #cell-exit_ip="{ row }"><span class="mono">{{ row.exit_ip }}</span></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import Chart from '../components/Chart.vue'
import Seg from '../components/Seg.vue'
import Status from '../components/Status.vue'
import Icon from '../components/Icon.vue'
import DataTable from '../components/DataTable.vue'
import { get, post } from '../lib/api.js'
import { state, label, outboundTags, toast } from '../lib/state.js'
import { datetime } from '../lib/format.js'
import { latencyOption } from '../lib/options.js'

const data = ref(null)
const running = ref(false)
const target = ref('trace')
const hours = ref(24)
const outbounds = computed(() => state.overview?.topology?.outbounds || [])
const latest = computed(() => data.value?.latest || {})
const targets = computed(() => {
  const names = new Set((data.value?.history || []).map(h => h.target))
  return [...names].map(n => ({ value: n, label: n }))
})
const latencyChart = computed(() => latencyOption(state.tokens, data.value.history, outboundTags().filter(t => outbounds.value.find(o => o.tag === t)?.probe), t => label('outbound', t), target.value))
const swatch = tag => { const i = outboundTags().indexOf(tag); return i >= 0 && i < 8 ? 'sw-' + (i + 1) : 'sw-muted' }
const changeCols = [{ key: 'at', label: '时间' }, { key: 'outbound', label: '出站' }, { key: 'exit_ip', label: '出口地址' }]
const changes = computed(() => Object.entries(data.value?.changes || {}).flatMap(([outbound, list]) => list.map(c => ({ ...c, outbound }))))

async function load() {
  try { data.value = await get('api/probes', { hours: hours.value }) } catch (e) { toast(e.message, 'error') }
}
async function runNow() {
  running.value = true
  try {
    await post('api/probes/run')
    await load()
    toast('探测完成', 'ok')
  } catch (e) { toast(e.message, 'error') }
  running.value = false
}
watch(hours, load)
onMounted(load)
</script>
