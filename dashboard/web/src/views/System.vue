<template>
  <div v-if="sys" class="grid">
    <div class="grid cols-3">
      <section class="card">
        <div class="card-head"><div><h2>服务</h2><p>面板 v{{ sys.version }} · 运行 {{ duration(Date.now() / 1000 - sys.started) }}</p></div></div>
        <div class="card-body">
          <dl class="kv">
            <template v-for="(st, name) in sys.services" :key="name"><dt>{{ name }}</dt><dd><Status :kind="st === 'active' ? 'good' : 'bad'" :text="st" /></dd></template>
            <dt>内核事件</dt><dd><Status :kind="sys.health.connected ? 'good' : 'bad'" :text="sys.health.connected ? '采集正常' : '中断：' + sys.health.last_error" /></dd>
            <dt>实时推送</dt><dd>{{ sys.streams }} 个订阅</dd>
            <dt>sing-box</dt><dd>{{ sys.singbox.version || '—' }}</dd>
            <dt>内核 API</dt><dd class="mono">{{ sys.singbox.api }}</dd>
          </dl>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>证书与存储</h2></div></div>
        <div class="card-body">
          <dl class="kv">
            <dt>TLS 证书</dt><dd><Status v-if="sys.certificate.days_left != null" :kind="sys.certificate.days_left > 14 ? 'good' : 'warn'" :text="sys.certificate.days_left + ' 天后到期'" /><span v-else class="muted">{{ sys.certificate.found ? sys.certificate.error : '未找到' }}</span></dd>
            <dt>数据盘</dt><dd>{{ bytes(sys.disk.used) }} / {{ bytes(sys.disk.total) }}（{{ sys.disk.percent }}%）</dd>
            <dt>账本</dt><dd>{{ bytes(sys.database.bytes) }}</dd>
            <dt>本次迁移</dt><dd>{{ sys.database.migrations.length ? sys.database.migrations.map(m => 'v' + m[0] + '（' + m[1] + ' 秒）').join('、') : '无' }}</dd>
            <dt>回源校验</dt><dd><Status :kind="sys.gate.enabled ? 'good' : 'warn'" :text="sys.gate.enabled ? '已启用' : '未启用'" /></dd>
            <dt>防火墙</dt><dd>{{ sys.firewall.chain }} · {{ endpointText(sys.firewall) || '无公网入站' }}</dd>
          </dl>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>定位数据库</h2><p>全部离线查询，不向第三方发送客户端 IP。</p></div></div>
        <div class="card-body">
          <dl class="kv">
            <template v-for="(v, k) in sys.geo" :key="k"><dt>{{ k }}</dt><dd>{{ v.file }} · {{ new Date(v.built * 1000).toLocaleDateString('zh-CN') }}</dd></template>
          </dl>
          <p class="small muted">ip2region（Apache-2.0 / MIT）· <a href="https://db-ip.com" target="_blank" rel="noreferrer">IP Geolocation by DB-IP</a>（CC BY 4.0）</p>
        </div>
      </section>
    </div>

    <section class="card">
      <div class="card-head">
        <div><h2>显示名称</h2><p>节点列表直接读取 sing-box 配置（{{ sys.singbox.config }}），新增入站 / 出站会自动出现；这里只设置显示名称与入口类型。</p></div>
        <button class="btn primary sm" type="button" :disabled="saving" @click="saveLabels">保存</button>
      </div>
      <div class="card-body grid cols-2">
        <div class="grid">
          <h3>入站</h3>
          <div v-for="i in topo.inbounds" :key="i.tag" class="toolbar">
            <span class="mono small nowrap">{{ i.tag }}</span>
            <input v-model="draft.inbounds[i.tag]" class="input" maxlength="40" :placeholder="i.tag" :aria-label="i.tag + ' 显示名称'">
            <select v-model="draft.entries[i.tag]" class="input" :aria-label="i.tag + ' 入口类型'">
              <option value="">自动（{{ i.public ? '直连' : 'CDN' }}）</option><option value="direct">直连</option><option value="cdn">CDN 中转</option>
            </select>
          </div>
        </div>
        <div class="grid">
          <h3>出站</h3>
          <div v-for="o in topo.outbounds" :key="o.tag" class="toolbar">
            <span class="mono small nowrap">{{ o.tag }}</span>
            <input v-model="draft.outbounds[o.tag]" class="input" maxlength="40" :placeholder="o.tag" :aria-label="o.tag + ' 显示名称'">
          </div>
        </div>
      </div>
    </section>

    <section class="card">
      <div class="card-head">
        <div><h2>告警与探测</h2><p>保存后立即生效，写入面板数据库（不改动服务器配置文件）。</p></div>
        <button class="btn primary sm" type="button" :disabled="saving" @click="saveAlerts">保存</button>
      </div>
      <div class="card-body toolbar">
        <label class="field">采集中断告警（秒）<input v-model.number="alerts['alerts.collector_down_seconds']" class="input" type="number" min="0"></label>
        <label class="field">探测连续失败（轮）<input v-model.number="alerts['alerts.probe_failures']" class="input" type="number" min="0"></label>
        <label class="field">证书剩余（天）<input v-model.number="alerts['alerts.cert_days']" class="input" type="number" min="0"></label>
        <label class="field">磁盘使用（%）<input v-model.number="alerts['alerts.disk_percent']" class="input" type="number" min="0" max="100"></label>
        <label class="field">单 IP 每日流量（GiB，0 关闭）<input v-model.number="dailyGiB" class="input" type="number" min="0" step="0.5"></label>
        <label class="field">探测间隔（秒）<input v-model.number="alerts['probes.interval_seconds']" class="input" type="number" min="60"></label>
        <label class="field">出口探测<select v-model="alerts['probes.enabled']" class="input"><option :value="true">开启</option><option :value="false">关闭</option></select></label>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><div><h2>生效配置</h2><p>来源（后者覆盖前者）：内置默认 → {{ sys.settings.sources.join(' → ') }} → 面板设置。密钥不在此显示。</p></div></div>
      <div class="card-body"><pre class="mono small config">{{ JSON.stringify(sys.settings.values, null, 2) }}</pre></div>
    </section>
  </div>
  <p v-else class="muted">加载中…</p>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import Status from '../components/Status.vue'
import { get, put } from '../lib/api.js'
import { bytes, duration, endpointText } from '../lib/format.js'
import { refreshOverview, state, toast } from '../lib/state.js'

const sys = ref(null)
const saving = ref(false)
const draft = reactive({ inbounds: {}, outbounds: {}, entries: {} })
const alerts = reactive({})
const topo = computed(() => state.overview?.topology || { inbounds: [], outbounds: [] })
const dailyGiB = computed({
  get: () => (alerts['alerts.ip_daily_bytes'] || 0) / 1024 ** 3,
  set: v => { alerts['alerts.ip_daily_bytes'] = Math.round((Number(v) || 0) * 1024 ** 3) },
})

async function load() {
  try {
    const [s, p] = await Promise.all([get('api/system'), get('api/prefs')])
    sys.value = s
    const eff = p.effective
    Object.assign(draft.inbounds, eff['labels.inbounds'] || {})
    Object.assign(draft.outbounds, eff['labels.outbounds'] || {})
    for (const i of state.overview?.topology?.inbounds || []) draft.entries[i.tag] = ''
    Object.assign(draft.entries, eff.entries || {})
    for (const k of ['alerts.collector_down_seconds', 'alerts.probe_failures', 'alerts.cert_days', 'alerts.disk_percent', 'alerts.ip_daily_bytes', 'probes.interval_seconds', 'probes.enabled']) alerts[k] = eff[k]
  } catch (e) { toast(e.message, 'error') }
}
const clean = obj => Object.fromEntries(Object.entries(obj).filter(([, v]) => v && String(v).trim()).map(([k, v]) => [k, String(v).trim()]))
async function save(body) {
  saving.value = true
  try {
    await put('api/prefs', body)
    toast('已保存', 'ok')
    await refreshOverview()
    await load()
  } catch (e) { toast(e.message, 'error') }
  saving.value = false
}
const saveLabels = () => save({ 'labels.inbounds': clean(draft.inbounds), 'labels.outbounds': clean(draft.outbounds), entries: clean(draft.entries) })
const saveAlerts = () => save({ ...alerts })
onMounted(load)
</script>

<style scoped>
.config { margin: 0; max-height: 420px; overflow: auto; background: var(--surface-2); border: 1px solid var(--border); border-radius: 8px; padding: 12px; }
.field .input { width: 150px; }
</style>
