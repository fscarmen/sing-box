<template>
  <div class="scrim" @click="closeIp"></div>
  <aside class="drawer" role="dialog" aria-modal="true" :aria-label="'IP 详情 ' + ip" @keydown.esc="closeIp">
    <div class="drawer-head">
      <div>
        <h2 class="mono">{{ ip }}</h2>
        <span class="small muted">{{ g ? g.location + ' · ' + g.isp + (g.asn ? ' · AS' + g.asn : '') : '…' }}</span>
      </div>
      <span class="spacer"></span>
      <button class="btn sm" :class="info?.banned ? '' : 'danger'" type="button" @click="ban">{{ info?.banned ? '解除封禁' : '封禁' }}</button>
      <button ref="closer" class="icon-btn" type="button" aria-label="关闭" @click="closeIp"><Icon name="close" /></button>
    </div>
    <div class="drawer-body">
      <div class="grid cols-3">
        <div class="card kpi"><span class="k-label">累计流量</span><span class="k-value num">{{ bytes((info?.upload || 0) + (info?.download || 0)) }}</span><span class="k-sub">↓ {{ bytes(info?.download) }} · ↑ {{ bytes(info?.upload) }}</span></div>
        <div class="card kpi"><span class="k-label">当前</span><span class="k-value num">{{ live.online || 0 }} 连接</span><span class="k-sub">↓ {{ rate(live.rd || 0) }} · ↑ {{ rate(live.ru || 0) }}</span></div>
        <div class="card kpi"><span class="k-label">活动时间</span><span class="k-value num">{{ num(info?.connections) }} 次</span><span class="k-sub">{{ info?.first_seen ? datetime(info.first_seen).slice(0, 10) : '—' }} 至 {{ ago(info?.last_seen) }}</span></div>
      </div>
      <section class="card">
        <div class="card-head"><div><h2>近 7 天流量</h2><p>按出口，每小时</p></div></div>
        <div class="card-body"><Chart v-if="series" :option="seriesChart" height="200px" label="该 IP 近 7 天流量" replace /></div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>定位</h2></div></div>
        <div class="card-body">
          <dl v-if="g" class="kv">
            <dt>国家 / 地区</dt><dd>{{ g.country || '—' }} {{ g.country_code ? '(' + g.country_code + ')' : '' }}</dd>
            <dt>省 / 州</dt><dd>{{ g.region || '—' }}</dd>
            <dt>城市</dt><dd>{{ g.city || '—' }}</dd>
            <dt>运营商</dt><dd>{{ g.isp }}</dd>
            <dt>ASN</dt><dd>{{ g.asn ? 'AS' + g.asn + ' · ' + g.as_org : '—' }}</dd>
            <dt>坐标精度</dt><dd>{{ { city: '城市', region: '省级', country: '国家' }[g.precision] || '—' }}</dd>
            <dt>数据来源</dt><dd>{{ g.source || '—' }}</dd>
          </dl>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>热门目标</h2><p>最近 7 天</p></div><NavLink class="btn sm" to="history" :query="{ ip }" @navigate="closeIp">连接历史</NavLink></div>
        <div class="card-body">
          <ol class="rank">
            <li v-for="r in topDomains" :key="r.k"><div class="r-top"><span>{{ r.k }}</span><span class="num muted">{{ bytes(r.upload + r.download) }} · {{ r.connections }} 次</span></div></li>
            <li v-if="!topDomains.length" class="muted small">暂无数据</li>
          </ol>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>每日流量</h2></div><NavLink class="btn sm" to="daily" :query="{ ip }" @navigate="closeIp">全部</NavLink></div>
        <div class="card-body flush">
          <DataTable :columns="dailyCols" :rows="daily" sort="day" :page-size="10" hide-foot>
            <template #cell-upload="{ row }">{{ bytes(row.upload) }}</template>
            <template #cell-download="{ row }">{{ bytes(row.download) }}</template>
          </DataTable>
        </div>
      </section>
    </div>
  </aside>
</template>

<script setup>
import NavLink from './NavLink.vue'
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import Icon from './Icon.vue'
import Chart from './Chart.vue'
import DataTable from './DataTable.vue'
import { get } from '../lib/api.js'
import { closeIp } from '../lib/router.js'
import { state, label, outboundTags, toast } from '../lib/state.js'
import { ago, bytes, datetime, num, rate } from '../lib/format.js'
import { trendOption } from '../lib/options.js'
import { banFlow } from '../lib/actions.js'

const props = defineProps({ ip: { type: String, required: true } })
const g = ref(null)
const info = ref(null)
const series = ref(null)
const topDomains = ref([])
const daily = ref([])
const closer = ref(null)
const live = computed(() => state.frame?.ips?.[props.ip] || {})
const seriesChart = computed(() => trendOption(state.tokens, series.value, outboundTags(), k => label('outbound', k)))
const dailyCols = [{ key: 'day', label: '日期' }, { key: 'upload', label: '上传', align: 'right' }, { key: 'download', label: '下载', align: 'right' }]

async function load() {
  try {
    const [geo, ips, s, top, d] = await Promise.all([
      get('api/geo/' + encodeURIComponent(props.ip)), get('api/ips'), get('api/series', { range: '7d', by: 'outbound', ip: props.ip }),
      get('api/top', { by: 'domain', range: '7d', ip: props.ip, limit: 10 }), get('api/daily', { days: 30, ip: props.ip }),
    ])
    g.value = geo
    info.value = ips.rows.find(r => r.ip === props.ip) || null
    series.value = s
    topDomains.value = top.rows
    daily.value = d.rows
  } catch (e) { toast(e.message, 'error') }
}
async function ban() { if (await banFlow(props.ip, info.value?.banned)) load() }
watch(() => props.ip, load)
onMounted(() => { load(); nextTick(() => closer.value && closer.value.focus()) })
</script>
