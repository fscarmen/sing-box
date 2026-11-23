<template>
  <div class="grid">
    <section class="card">
      <div class="card-head"><div><h2>国内入口 HTTPS 检测</h2><p>{{ mainland.scope || '公开大陆节点检测入口 HTTPS；不代表完整订阅下载或代理协议握手。' }}</p></div><span class="tag">Globalping · {{ mainland.enabled ? '已开启' : '未开启' }}</span></div>
      <div class="card-body">
        <p class="muted">电信、联通、移动分别累计失败；连续 {{ mainland.failures || 2 }} 轮触发，真实恢复后关闭。间隔 {{ (mainland.interval || 600) / 60 }} 分钟，缺失、离线或检测服务异常显示未知。</p>
        <p class="muted">主解析器 {{ mainland.resolver || '223.5.5.5' }}（默认阿里 DNS）；仅解析失败时在同一探测点使用备用解析器 {{ mainland.fallback_resolver || '119.29.29.29' }}（默认 DNSPod）。故障城市通过后才关闭对应告警；抽样结果不代表整个运营商。</p>
        <p class="muted">尚未配置完整订阅下载检查。公开检测仅发送无令牌的入口域名与公开页面；两种核心共享站点入口检测，不验证代理协议握手。</p>
        <p v-if="mainland.provider_error" class="status warn">检测服务：{{ mainland.provider_error }}</p>
        <p v-if="mainland.running" class="muted">正在检测…</p>
        <DataTable :columns="mainlandColumns" :rows="mainland.rows || []">
          <template #cell-ok="{ row }"><span class="tag" :class="fresh(row) && row.ok === true ? 'good' : fresh(row) && row.ok === false ? 'bad' : ''">{{ !fresh(row) || row.ok == null ? '未知' : row.ok ? '正常' : '失败' }}</span></template>
          <template #cell-at="{ row }">{{ datetime(row.at * 1000) }}</template>
          <template #cell-error="{ row }">{{ row.error || (row.dns_fallback_used ? '备用 DNS 验证通过' : '—') }}</template>
        </DataTable>
      </div>
    </section>
    <section class="card">
      <div class="card-head">
        <div><h2>当前告警</h2><p>条件恢复后自动关闭。阈值可在“系统与设置”中调整；配置 Webhook 后新告警会推送通知。</p></div>
        <button v-if="open.length" class="btn sm" type="button" @click="ack()">全部标为已读</button>
      </div>
      <div class="card-body">
        <div v-if="!open.length" class="status good"><Icon name="check" />当前没有触发告警</div>
        <div v-for="a in open" :key="a.id" class="notice" :class="a.level === 'critical' ? 'bad' : a.level === 'warning' ? 'warn' : ''">
          <Icon :name="a.level === 'info' ? 'check' : 'warn'" />
          <div><b>{{ levelText(a.level) }}</b> · {{ a.message }}<span class="sub">{{ datetime(a.opened * 1000) }}{{ a.acked ? ' · 已读' : '' }}</span></div>
          <button v-if="!a.acked" class="btn sm ghost" type="button" @click="ack(a.id)">已读</button>
        </div>
      </div>
    </section>
    <section class="card">
      <div class="card-head"><div><h2>告警记录</h2><p>最近 100 条。</p></div></div>
      <div class="card-body flush">
        <DataTable :columns="columns" :rows="recent" sort="opened">
          <template #cell-level="{ row }"><span class="tag" :class="row.level === 'critical' ? 'bad' : row.level === 'warning' ? 'warn' : ''">{{ levelText(row.level) }}</span></template>
          <template #cell-opened="{ row }">{{ datetime(row.opened * 1000) }}</template>
          <template #cell-resolved="{ row }">{{ row.resolved ? datetime(row.resolved * 1000) : '进行中' }}</template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import DataTable from '../components/DataTable.vue'
import Icon from '../components/Icon.vue'
import { get, post } from '../lib/api.js'
import { datetime } from '../lib/format.js'
import { refreshOverview, state, toast } from '../lib/state.js'

const open = ref([])
const recent = ref([])
const mainland = ref({})
const mainlandColumns = [{ key: 'label', label: '入口' }, { key: 'isp', label: '运营商' }, { key: 'city', label: '探测城市' }, { key: 'resolver', label: '解析器' }, { key: 'ok', label: '结果' }, { key: 'failures', label: '连续失败' }, { key: 'error', label: '说明', class: 'wrap' }, { key: 'at', label: '检测时间' }]
const fresh = row => Date.now() / 1000 - row.at <= Math.max(1800, (mainland.value.interval || 600) * 3)
const columns = [{ key: 'level', label: '级别' }, { key: 'message', label: '内容', class: 'wrap' }, { key: 'opened', label: '开始' }, { key: 'resolved', label: '恢复' }]
const levelText = l => ({ critical: '严重', warning: '警告', info: '提示' }[l] || l)
async function load() {
  try { const d = await get('api/alerts', { engine: state.engine }); open.value = d.open; recent.value = d.recent; mainland.value = d.reachability || {} } catch (e) { toast(e.message, 'error') }
}
async function ack(id) {
  await post('api/alerts/ack', { ...(id ? { id } : {}), engine: state.engine })
  await load()
  refreshOverview()
}
let timer
onMounted(() => { load(); timer = setInterval(load, 15000) })
onUnmounted(() => clearInterval(timer))
</script>
