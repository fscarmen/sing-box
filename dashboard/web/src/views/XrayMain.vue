<template>
  <div class="grid" data-engine="xray" :data-view="section">
    <section class="card">
      <div class="card-head">
        <div><h2>{{ headings[section] || 'Xray 监控' }}</h2><p>{{ descriptions[section] }}</p></div>
        <div class="toolbar">
          <select v-if="section !== 'system' && section !== 'bans'" v-model="state.xrayInstance" class="input" aria-label="Xray 实例"><option value="">全部 Xray</option><option v-for="i in data?.instances || []" :key="i.id" :value="i.id">{{ i.label }}</option></select>
          <Seg v-if="section === 'daily' && !nodeOnly" v-model="dailyKind" :options="dailyKinds" label="统计对象" />
          <Seg v-if="['overview', 'history', 'daily', 'exits'].includes(section)" v-model="span" :options="ranges" label="时间范围" />
        </div>
      </div>
    </section>
    <p v-if="!data" class="muted">正在连接 Xray…</p>

    <template v-if="data && ['overview', 'live', 'xray'].includes(section)">
      <div class="grid cols-4">
        <Kpi label="Xray 实时速率" :value="ratesReady ? rate(totals.up + totals.down) : '—'"><span v-if="ratesReady">↓ {{ rate(totals.down) }} · ↑ {{ rate(totals.up) }}</span><span v-else>等待连续有效采样</span></Kpi>
        <Kpi label="Xray 今日流量" :value="bytes(totals.today)"><span>仅原生入站字节，不重复叠加出站</span></Kpi>
        <Kpi label="Xray 接入后累计" :value="bytes(totals.total)"><span>自 {{ datetime(since * 1000) }}</span></Kpi>
        <Kpi v-if="nodeOnly" label="在线节点" :value="activity.label"><span>近 60 秒采样到入站流量{{ activity.unknown ? ' · ' + activity.unknown + ' 个未知' : '' }}</span></Kpi>
        <Kpi v-else label="在线用户（核心口径）" :value="onlineUsers == null ? '—' : onlineUsers + ' / ' + users.length"><span>{{ nodes.length }} 个节点 · {{ instances.filter(i => i.connected).length }} / {{ instances.length }} 个实例已连接</span></Kpi>
      </div>
      <section class="card">
        <div class="card-head"><div><h2>实时吞吐</h2><p>每 2 秒采样 Xray 原生计数；未知速率留空，采集中断不补零。</p></div></div>
        <div class="card-body"><Chart :option="liveChart" height="250px" label="Xray 实时吞吐" replace /></div>
      </section>
    </template>

    <template v-if="data && section === 'overview'">
      <section class="card">
        <div class="card-head"><div><h2>流量趋势</h2><p>{{ stepNote }}。只展示实际采样，不回填接入前历史。</p></div></div>
        <div class="card-body"><Chart :option="trafficChart" height="250px" label="Xray 流量趋势" replace /></div>
      </section>
      <div class="grid cols-2">
        <section class="card"><div class="card-head"><h2>实例状态</h2></div><div class="card-body grid"><div v-for="i in instances" :key="i.id" class="toolbar"><Status :kind="i.connected ? 'good' : 'bad'" :text="i.label + (i.connected ? ' · 已连接' : ' · 采集中断')" /><span class="small muted">{{ nodes.filter(n => n.instance === i.id).length }} 个节点 · {{ i.error || '原生统计正常' }}</span></div></div></section>
        <section class="card"><div class="card-head"><h2>{{ nodeOnly ? '节点活动与出口' : '在线来源与出口' }}</h2></div><div class="card-body"><p v-if="nodeOnly">{{ activity.active == null ? '等待有效采样' : activity.active + ' 个节点近期有流量' }} · {{ activity.unknown }} 个节点状态未知。</p><p v-if="nodeOnly" class="small muted">按节点自身入站流量判断；无近期流量不代表连接已断开。</p><p v-if="!nodeOnly">核心当前提供 <b>{{ sources.length }}</b> 个来源地址，覆盖 {{ supportedNodes }} / {{ nodes.length }} 个节点。</p><p v-if="!nodeOnly" class="small muted">未提供列表的节点不计作无人在线；经过 CDN/Nginx 时，来源可能是边缘地址。</p><p>实测出口 {{ uniqueExits.length }} 个 · {{ exits.filter(o => o.exit_ip).length }} / {{ exits.length }} 条出站有成功回显。</p></div></section>
      </div>
      <div :class="['grid', nodeOnly ? '' : 'cols-2']">
        <section class="card"><div class="card-head"><h2>流量较高的节点</h2><NavLink class="btn sm" to="xray">全部节点</NavLink></div><div class="card-body flush"><DataTable :columns="rankCols" :rows="ranked" row-key="key" hide-foot><template #cell-label="{ row }">{{ row.label }}<span class="sub">{{ instanceLabel(row.instance) }}</span></template><template #cell-total="{ row }">{{ bytes(row.total) }}</template><template #cell-rate="{ row }">{{ row.fresh && row.down_rate != null ? rate(row.down_rate + row.up_rate) : '—' }}</template></DataTable></div></section>
        <section v-if="!nodeOnly" class="card"><div class="card-head"><h2>流量较高的用户</h2><NavLink class="btn sm" to="clients">全部用户</NavLink></div><div class="card-body flush"><DataTable :columns="userRankCols" :rows="rankedUsers" row-key="key" hide-foot empty="核心未提供用户计数（需要用户 email 与统计开关）"><template #cell-email="{ row }"><span class="mono">{{ row.email }}</span><span class="sub">{{ instanceLabel(row.instance) }}</span></template><template #cell-total="{ row }">{{ bytes(row.total) }}</template><template #cell-rate="{ row }">{{ row.speed == null ? '—' : rate(row.speed) }}</template></DataTable></div></section>
      </div>
    </template>

    <section v-if="data && (['live', 'xray'].includes(section) || nodeOnly && section === 'clients')" class="card">
      <div class="card-head"><div><h2>{{ section === 'clients' ? '节点在线状态' : '节点速率与流量' }}</h2><p>{{ nodeOnly ? '每行代表一个入站节点。在线按近 60 秒采样到真实入站流量判断；静默节点显示无近期流量，采样中断显示未知。' : 'Xray 未提供逐连接字节与关闭单连接接口；每行代表一个入站节点。' }}</p></div></div>
      <div class="card-body flush"><DataTable :columns="nodeCols" :rows="nodes" row-key="key" :page-size="50" empty="等待节点采样">
        <template #cell-label="{ row }"><b>{{ row.label }}</b><span class="sub">{{ instanceLabel(row.instance) }}</span></template>
        <template #cell-transport="{ row }">{{ row.protocol.toUpperCase() }} · {{ row.transport }}{{ row.tls ? ' + TLS' : '' }}<span class="sub">客户端端口 {{ row.port }}</span></template>
        <template #cell-speed="{ row }">{{ row.fresh && row.down_rate != null ? '↓ ' + rate(row.down_rate) : '—' }}<span class="sub">{{ row.fresh && row.up_rate != null ? '↑ ' + rate(row.up_rate) : '等待有效采样' }}</span></template>
        <template #cell-total="{ row }">{{ bytes(row.upload + row.download) }}<span class="sub">今日 {{ bytes(row.today_upload + row.today_download) }}</span></template>
        <template #cell-online="{ row }"><Status v-if="nodeOnly" :kind="row.online_activity === true ? 'good' : row.online_activity == null ? 'warn' : ''" :text="row.online_activity == null ? '未知' : row.online_activity ? '在线' : '无近期流量'" /><span v-else>{{ row.online_sources == null ? '未提供' : row.online_sources.length + ' 个来源' }}</span></template>
        <template #cell-exit="{ row }">{{ outFor(row)?.exit_ip || '未检测' }}<span class="sub">{{ outFor(row)?.geo?.location || '' }}</span></template>
      </DataTable></div>
    </section>

    <template v-if="data && section === 'topology'">
      <section class="card"><div class="card-head"><div><h2>实例 → 入站 → 出站 → 实测出口</h2><p>边宽取接入后的实际累计入站字节；同一批流量在各阶段重复展示，不相加计费。零流量节点在下表保留。</p></div></div><div class="card-body"><Chart v-if="topologyChart.series[0].links.length" :option="topologyChart" height="560px" label="Xray 真实配置与流量拓扑" replace /><p v-else class="muted">尚无实际流量，配置链路见下表。</p></div></section>
      <section class="card"><div class="card-body flush"><DataTable :columns="pathCols" :rows="nodes" row-key="key" :page-size="50"><template #cell-instance="{ row }">{{ instanceLabel(row.instance) }}</template><template #cell-label="{ row }">{{ row.label }}</template><template #cell-outbound="{ row }">{{ row.outbound ? outFor(row)?.label : '条件或复杂路由，未假定单一出口' }}</template><template #cell-exit="{ row }">{{ outFor(row)?.exit_ip || '未检测' }}</template><template #cell-total="{ row }">{{ bytes(row.upload + row.download) }}</template></DataTable></div></section>
    </template>

    <template v-if="data && !nodeOnly && section === 'clients'">
      <section class="card"><div class="card-head"><div><h2>用户流量</h2><p>按 Xray 用户 email 的原生计数；同一用户在多个入站共用一份计数，不分摊到来源 IP。{{ users.some(u => u.total == null) ? '部分用户未开启用户统计，流量显示为未提供。' : '' }}</p></div></div><div class="card-body flush"><DataTable :columns="userCols" :rows="users" row-key="key" sort="total" :page-size="50" empty="配置中没有带 email 的用户">
        <template #cell-email="{ row }"><span class="mono">{{ row.email }}</span><span class="sub">{{ instanceLabel(row.instance) }}</span></template>
        <template #cell-nodes="{ row }">{{ row.nodes.map(nodeLabel).join('、') }}</template>
        <template #cell-online="{ row }">{{ row.online_ips == null ? '未提供' : row.online_ips.length ? row.online_ips.length + ' 个地址' : '无在线地址' }}<span v-if="row.online_ips?.length" class="sub mono">{{ row.online_ips.slice(0, 3).join('、') }}{{ row.online_ips.length > 3 ? ' …' : '' }}</span></template>
        <template #cell-speed="{ row }">{{ row.speed == null ? '—' : '↓ ' + rate(row.down_rate) }}<span class="sub">{{ row.speed == null ? '等待有效采样' : '↑ ' + rate(row.up_rate) }}</span></template>
        <template #cell-today="{ row }">{{ row.today == null ? '未提供' : bytes(row.today) }}</template>
        <template #cell-total="{ row }">{{ row.total == null ? '未提供' : bytes(row.total) }}<span v-if="row.since" class="sub">自 {{ datetime(row.since * 1000) }}</span></template>
      </DataTable></div></section>
      <section class="card"><div class="card-body"><p>{{ sources.length }} 个来源地址，{{ supportedNodes }} / {{ nodes.length }} 个节点提供了在线列表。</p><p class="small muted">{{ data.scope }} 原生接口未提供单个 IP 的流量、连接数或访问目标，因此这里不分配流量给任何 IP。</p></div></section>
      <section class="card"><div class="card-body flush"><DataTable :columns="sourceCols" :rows="sources" row-key="ip" empty="核心暂未提供在线来源；这不代表没有用户连接"><template #cell-nodes="{ row }">{{ row.nodes.map(nodeLabel).join('、') }}</template><template #cell-location="{ row }">{{ row.geo?.location || '未知' }}</template><template #cell-isp="{ row }">{{ row.geo?.isp || '未知' }}</template><template #cell-sampled_at="{ row }">{{ datetime(row.sampled_at * 1000) }}</template></DataTable></div></section>
    </template>

    <template v-if="data && ['history', 'daily'].includes(section)">
      <section class="card"><div class="card-head"><div><h2>{{ section === 'daily' ? '每日流量' : '采样流量趋势' }}</h2><p>{{ section === 'daily' ? '按站点时区的自然日累计（' + dailyKinds.find(k => k.value === dailyKind).label + '），包含历史条目；跨日断采增量归入恢复日。' : stepNote + '；缺失时段留空，不推断连接数或目标网站。' }}</p></div></div><div class="card-body"><Chart :option="section === 'daily' ? dailyChart : trafficChart" height="260px" label="Xray 持久流量记录" replace /></div></section>
      <section class="card"><div class="card-body flush"><DataTable v-if="section === 'daily'" :columns="dailyCols" :rows="dailyRows" sort="day" :page-size="50" empty="所选范围暂无日累计"><template #cell-instance="{ row }">{{ instanceLabel(row.instance) }}</template><template #cell-label="{ row }"><span :class="{ mono: dailyKind !== 'nodes' }">{{ row.label }}</span></template><template #cell-upload="{ row }">{{ bytes(row.upload) }}</template><template #cell-download="{ row }">{{ bytes(row.download) }}</template></DataTable><DataTable v-else :columns="historyCols" :rows="minuteRows" sort="ts" :page-size="50" empty="所选范围暂无采样记录"><template #cell-ts="{ row }">{{ datetime(row.ts * 1000) }}</template><template #cell-instance="{ row }">{{ instanceLabel(row.instance) }}</template><template #cell-upload="{ row }">{{ bytes(row.upload) }}</template><template #cell-download="{ row }">{{ bytes(row.download) }}</template></DataTable></div></section>
    </template>

    <template v-if="data && section === 'exits'">
      <section class="card"><div class="card-head"><div><h2>Xray 媒体出口探测</h2><p>经节点配置的同一上游检查 HTTPS 可达性，Cloudflare trace 单独确认出口 IP。每 {{ Math.round((data.probe_interval || 300) / 60) }} 分钟自动探测。</p></div><button class="btn primary sm" :disabled="data.probe_running" @click="probeNow">{{ data.probe_running ? '探测中…' : '立即探测' }}</button></div><div class="card-body"><p v-if="!data.probes_enabled" class="muted">自动探测已关闭。</p><p v-if="data.probe_error" class="notice warn">最近探测未完成：{{ data.probe_error }}。保留上次结果及时间。</p><div class="exit-grid"><div v-for="out in exits" :key="out.key" class="exit"><div class="exit-head"><b>{{ out.label }}</b><Status v-if="out.probe_at" :kind="out.exit_ip ? 'good' : 'bad'" :text="out.exit_ip ? '回显成功' : '回显失败'" /><span v-else class="tag">待探测</span></div><span class="exit-ip">{{ out.exit_ip || '未检测' }}</span><span class="small muted">{{ instanceLabel(out.instance) }} · {{ out.geo?.location || '' }} {{ out.geo?.isp || '' }}</span><span v-if="!nodeOnly && out.measured" class="small">出站实测 {{ out.fresh && out.down_rate != null ? '↓ ' + rate(out.down_rate) + ' · ↑ ' + rate(out.up_rate) : '—' }} · 累计 {{ bytes(out.upload + out.download) }}</span><dl class="kv small"><template v-for="name in media" :key="name"><dt>{{ name }}</dt><dd>{{ out.targets[name] ? out.targets[name].ok ? out.targets[name].total_ms + ' ms' : out.targets[name].error || '失败' : '未检测' }}</dd></template></dl><span class="small muted">{{ datetime(out.probe_at * 1000) }}</span></div></div></div></section>
      <section v-if="!nodeOnly && outboundRows.length" class="card"><div class="card-head"><div><h2>出站流量</h2><p>Xray 原生出站计数（statsOutbound）；与入站计数是同一批流量的两个观察点，不相加。</p></div></div><div class="card-body flush"><DataTable :columns="outCols" :rows="outboundRows" row-key="key" sort="total" :page-size="50"><template #cell-tag="{ row }"><span class="mono">{{ row.tag }}</span><span class="sub">{{ instanceLabel(row.instance) }}</span></template><template #cell-speed="{ row }">{{ row.speed == null ? '—' : '↓ ' + rate(row.down_rate) + ' · ↑ ' + rate(row.up_rate) }}</template><template #cell-today="{ row }">{{ bytes(row.today) }}</template><template #cell-total="{ row }">{{ bytes(row.total) }}</template></DataTable></div></section>
      <section class="card"><div class="card-head"><div><h2>出口回显历史</h2><p>从本次更新开始保存，最多 7 天；展示最近 {{ probeRows.length }} 次{{ detail?.probe_history_truncated ? '（已截断）' : '' }}，不回填此前记录。</p></div></div><div class="card-body flush"><DataTable :columns="probeCols" :rows="probeRows" sort="at" :page-size="50" empty="等待第一轮新探测"><template #cell-at="{ row }">{{ datetime(row.at * 1000) }}</template><template #cell-label="{ row }">{{ outMap[row.instance + ':' + row.tag]?.label || instanceLabel(row.instance) }}</template><template #cell-exit="{ row }">{{ row.targets.trace?.ok ? row.targets.trace.exit_ip : '回显失败' }}</template><template #cell-media="{ row }">{{ media.map(name => name + ' ' + (row.targets[name]?.ok ? '✓' : '失败')).join(' · ') }}</template></DataTable></div></section>
    </template>

    <template v-if="data && section === 'map'">
      <section class="card"><div class="card-head"><div><h2>实测出口地理分布</h2><p>只绘制成功回显且离线数据库可定位的出口。坐标是近似位置；同一 IP 的不同链路分别保留。</p></div></div><div class="card-body"><Chart v-if="mapReady" :option="mapChart" height="460px" label="Xray 实测出口地图" replace /><p v-else class="muted">正在加载地图…</p><p class="small muted">IP Geolocation by <a href="https://db-ip.com" target="_blank" rel="noreferrer">DB-IP</a> · ip2region。地图不将 CDN/回环来源标为真实客户端。</p></div></section>
      <section class="card"><div class="card-body flush"><DataTable :columns="geoCols" :rows="exits" row-key="key" :page-size="50"><template #cell-label="{ row }">{{ row.label }}</template><template #cell-location="{ row }">{{ row.geo?.location || '未知' }}</template><template #cell-isp="{ row }">{{ row.geo?.isp || '未知' }}</template><template #cell-precision="{ row }">{{ { city: '城市', region: '省级', country: '国家' }[row.geo?.precision] || '未提供' }}</template></DataTable></div></section>
    </template>

    <template v-if="data && section === 'network'">
      <div class="grid cols-2"><Kpi label="Xray 原生载荷速率" :value="ratesReady ? rate(totals.up + totals.down) : '—'"><span>所选实例的入站采样</span></Kpi><Kpi label="整机网卡收发" :value="network ? rate(network.current.rx + network.current.tx) : '—'"><span>{{ network?.interfaces.join('、') }}</span></Kpi></div>
      <section class="card"><div class="card-head"><div><h2>服务器网卡吞吐</h2><p>{{ network?.scope }}</p></div></div><div class="card-body"><Chart :option="nicChart" height="260px" label="整机网卡真实收发" replace /></div></section>
      <section class="card"><div class="card-head"><h2>Xray 采样状态</h2></div><div class="card-body grid"><div v-for="i in instances" :key="i.id" class="toolbar"><Status :kind="i.connected ? 'good' : 'bad'" :text="i.label" /><span>{{ i.connected ? '采集正常' : i.error }}</span><span class="small muted">最近成功 {{ datetime(i.last_success * 1000) }}</span></div><p class="small muted">当前 Xray 统计接口未提供逐连接 RTT、重传和目标带宽；不沿用 sing-box 的链路质量数据。</p></div></section>
    </template>

    <section v-if="section === 'bans'" class="card"><div class="card-body"><h3>Xray 访问控制未启用</h3><p>启用后，面板用 iptables 拒绝被封禁地址访问 Xray 的公网入站端口（TCP 重置，UDP 丢弃）；监听回环、经 Nginx 转发的入口由回源网关负责。不修改 Xray 配置，也不重启 Xray。</p><p class="small muted">在 /etc/sb-dashboard/settings.json 中设置 <span class="mono">xray.access_control=true</span>，然后重启 sb-dashboard。本项目安装器已为面板配置防火墙权限。Xray 的运行时路由接口会整体替换已有规则，因此不使用它封禁。</p></div></section>

    <template v-if="data && section === 'system' && system">
      <div class="grid cols-2"><section class="card"><div class="card-head"><h2>Xray 核心与服务</h2></div><div class="card-body grid"><div v-for="i in system.xray_runtimes" :key="i.id"><h3>{{ i.label }}</h3><p>{{ i.version || '版本暂未读取' }}</p><dl class="kv small"><dt>服务状态</dt><dd>{{ system.services[i.service] || '未知' }}</dd><dt>统计接口</dt><dd>{{ i.api }}（仅回环）</dd><dt>节点配置</dt><dd class="mono wrap">{{ i.config }}</dd>
          <template v-if="data.runtimes[i.id]"><dt>核心运行</dt><dd>{{ duration(data.runtimes[i.id].uptime) }} · 内存 {{ bytes(data.runtimes[i.id].memory) }} · 协程 {{ data.runtimes[i.id].goroutines }}</dd></template>
          <template v-for="c in capabilityRows(i.id)" :key="c[0]"><dt>{{ c[0] }}</dt><dd>{{ c[1] }}</dd></template></dl></div></div></section><section class="card"><div class="card-head"><h2>证书与存储</h2></div><div class="card-body"><dl class="kv"><dt>站点证书</dt><dd>{{ system.certificate.days_left == null ? '未提供' : system.certificate.days_left + ' 天后到期' }}</dd><dt>服务器运行</dt><dd>{{ duration(system.uptime) }}</dd><dt>磁盘使用</dt><dd>{{ bytes(system.disk.used) }} / {{ bytes(system.disk.total) }}</dd><dt>监控来源</dt><dd>Xray · 原生统计</dd><dt>累计开始</dt><dd>{{ datetime(since * 1000) }}</dd></dl></div></section></div>
      <section class="card"><div class="card-head"><div><h2>Xray 节点显示名称</h2><p>只修改面板名称，保持原节点配置、认证和路由。</p></div><button class="btn primary sm" :disabled="saving" @click="saveLabels">保存名称</button></div><div class="card-body grid cols-2"><label v-for="n in data.nodes" :key="n.key" class="field"><span class="small muted">{{ instanceLabel(n.instance) }} · {{ n.label }}</span><input v-model="draftLabels[n.key]" class="input" maxlength="40" :placeholder="n.label" :aria-label="n.label + ' 显示名称'"></label></div></section>
      <section class="card"><div class="card-head"><div><h2>告警与探测</h2><p>保存后立即生效。{{ nodeOnly ? '仅统计节点入站流量。' : '流量阈值按用户 email 计算。' }}</p></div><button class="btn primary sm" :disabled="saving" @click="saveSettings">保存设置</button></div><div class="card-body toolbar"><label v-for="(label, key) in settingLabels" :key="key" class="field"><span>{{ label }}</span><input v-model.number="settings[key]" class="input" type="number" min="0" :aria-label="label"></label><label v-if="!nodeOnly" class="field"><span>单用户日流量告警（GB，0 关闭）</span><input v-model.number="quotaGb" class="input" type="number" min="0" step="0.5" aria-label="单用户日流量告警"></label><label class="field">自动出口探测<select v-model="settings['probes.enabled']" class="input"><option :value="true">开启</option><option :value="false">关闭</option></select></label></div></section>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { feature } from 'topojson-client'
import landUrl from 'world-atlas/land-50m.json?url'
import { state, refreshXray, toast } from '../lib/state.js'
import { get, post, put } from '../lib/api.js'
import { bytes, rate, datetime, duration, esc } from '../lib/format.js'
import { echarts } from '../lib/charts.js'
import Chart from '../components/Chart.vue'
import DataTable from '../components/DataTable.vue'
import Kpi from '../components/Kpi.vue'
import NavLink from '../components/NavLink.vue'
import Seg from '../components/Seg.vue'
import Status from '../components/Status.vue'
import { nodeActivity, nodeActivitySummary } from '../lib/node-activity.js'

const props = defineProps({ section: { type: String, default: 'overview' } })
const data = computed(() => state.xray)
const nodeOnly = computed(() => !!data.value?.node_only)
const activity = computed(() => nodeActivitySummary(nodes.value, state.now / 1000, state.xrayError))
const span = ref('24h'), detail = ref(null), network = ref(null), system = ref(null), mapReady = ref(false), saving = ref(false)
const draftLabels = reactive({}), settings = reactive({})
const ranges = [{ value: '24h', label: '24 小时' }, { value: '7d', label: '7 天' }, { value: '30d', label: '30 天' }]
const dailyKind = ref('nodes')
watch(nodeOnly, enabled => { if (enabled) dailyKind.value = 'nodes' })
const dailyKinds = computed(() => nodeOnly.value ? [{ value: 'nodes', label: '节点' }] : [{ value: 'nodes', label: '节点' }, { value: 'users', label: '用户' }, { value: 'outbounds', label: '出站' }])
const GB = 1024 ** 3
const quotaGb = ref(0)
const media = computed(() => data.value?.probe_targets || ['Instagram', 'YouTube', 'Facebook'])
const headings = computed(() => ({ overview: 'Xray 概览', xray: 'Xray 节点列表', live: 'Xray 实时速率', topology: 'Xray 链路拓扑', map: 'Xray 出口分布', network: 'Xray 网络状态', clients: nodeOnly.value ? 'Xray 在线节点' : 'Xray 用户与来源', history: 'Xray 流量记录', daily: 'Xray 每日流量', exits: 'Xray 出口节点', bans: 'Xray 访问控制', system: 'Xray 系统与设置' }))
const descriptions = computed(() => ({ overview: '首页统计来自 Xray 原生入站计数，不混入其他内核流量。', live: '节点字节、速率与采样时间均来自 Xray。', xray: '读取现有节点配置与原生计数，保留主入口和对照入口的独立统计。', topology: '按结构化入站路由生成链路，复杂路由不假定单一出口。', clients: nodeOnly.value ? '按节点自身入站流量观察近期活动；不额外发送网络探测。' : '用户流量与在线地址来自 Xray 原生计数，未提供的数据保持未知。', history: '真实持久采样记录，不伪装为逐连接访问历史。', daily: '按站点时区查看 Xray 日累计。', exits: '实测回显与主流媒体 HTTPS 检查；不代表播放、账号登录或地区解锁。', map: '地理位置来自本地离线数据库。', network: 'Xray 载荷与整机网卡指标分别标明来源。', system: '查看 Xray 核心版本、服务状态和面板设置。', bans: '启用后封禁 Xray 公网入站端口的来源地址。' }))
const selected = computed(() => state.xrayInstance)
const instances = computed(() => (data.value?.instances || []).filter(i => !selected.value || i.id === selected.value))
const nodes = computed(() => (data.value?.nodes || []).filter(n => !selected.value || n.instance === selected.value).map(raw => {
  const n = raw.fresh && !state.xrayError && state.now / 1000 - raw.sampled_at <= 15 ? raw : { ...raw, fresh: false, up_rate: null, down_rate: null, online_sources: null, online_activity: null }
  const onlineActivity = nodeActivity(n, state.now / 1000, state.xrayError)
  return { ...n, online_activity: onlineActivity, total: n.upload + n.download, speed: n.up_rate == null ? null : n.up_rate + n.down_rate, online: nodeOnly.value ? onlineActivity == null ? -1 : Number(onlineActivity) : n.online_sources?.length ?? null, exit: outMap.value[n.outbound_key]?.exit_ip || '' }
}))
const exits = computed(() => (data.value?.outbounds || []).filter(o => !selected.value || o.instance === selected.value).map(o => ({ ...o, location: o.geo?.location || '', isp: o.geo?.isp || '', precision: o.geo?.precision || '' })))
const sources = computed(() => (data.value?.sources || []).filter(s => s.nodes.some(k => nodes.value.some(n => n.key === k && n.fresh && n.online_sources?.includes(s.ip)))))
const supportedNodes = computed(() => nodes.value.filter(n => n.online_sources != null).length)
const users = computed(() => (data.value?.users || []).filter(u => !selected.value || u.instance === selected.value).map(raw => {
  const u = raw.fresh && !state.xrayError && state.now / 1000 - raw.sampled_at <= 15 ? raw : { ...raw, fresh: false, up_rate: null, down_rate: null, online_ips: null }
  return { ...u, speed: u.up_rate == null || u.down_rate == null ? null : u.up_rate + u.down_rate, online: u.online_ips?.length ?? -1 }
}))
const onlineUsers = computed(() => users.value.some(u => u.online_ips != null) ? users.value.filter(u => u.online_ips?.length).length : null)
const rankedUsers = computed(() => users.value.filter(u => u.total != null).sort((a, b) => b.total - a.total).slice(0, 8))
const outboundRows = computed(() => (data.value?.outbound_stats || []).filter(o => !selected.value || o.instance === selected.value).map(o => ({ ...o, total: o.upload + o.download, today: o.today_upload + o.today_download, speed: o.fresh && o.up_rate != null && o.down_rate != null ? o.up_rate + o.down_rate : null })))
const uniqueExits = computed(() => [...new Set(exits.value.map(o => o.exit_ip).filter(Boolean))])
const since = computed(() => nodes.value.length ? Math.min(...nodes.value.map(n => n.since)) : 0)
const ratesReady = computed(() => !state.xrayError && nodes.value.length > 0 && nodes.value.every(n => n.fresh && n.up_rate != null && n.down_rate != null))
const totals = computed(() => nodes.value.reduce((t, n) => ({ total: t.total + n.upload + n.download, today: t.today + n.today_upload + n.today_download, up: t.up + (n.up_rate || 0), down: t.down + (n.down_rate || 0) }), { total: 0, today: 0, up: 0, down: 0 }))
const outMap = computed(() => Object.fromEntries((data.value?.outbounds || []).map(o => [o.key, o])))
const nodeMap = computed(() => Object.fromEntries((data.value?.nodes || []).map(n => [n.key, n])))
const instanceLabel = id => data.value?.instances.find(i => i.id === id)?.label || id
const nodeLabel = key => nodeMap.value[key]?.label || '历史节点'
const outFor = node => outMap.value[node.outbound_key]
const ranked = computed(() => nodes.value.map(n => ({ ...n, total: n.upload + n.download })).sort((a, b) => b.total - a.total).slice(0, 8))
const minuteRows = computed(() => (detail.value?.minutes || []).filter(r => !selected.value || r.instance === selected.value))
const dailyRows = computed(() => {
  const source = { nodes: detail.value?.daily, users: detail.value?.user_daily, outbounds: detail.value?.outbound_daily }[dailyKind.value] || []
  return source.filter(r => !selected.value || r.instance === selected.value).map(r => ({ ...r, label: dailyKind.value === 'nodes' ? nodeLabel(r.instance + ':' + r.tag) : r.email || r.tag }))
})
const probeRows = computed(() => (detail.value?.probe_history || []).filter(r => !selected.value || r.instance === selected.value))
const stepNote = computed(() => detail.value?.sample_step === 3600 ? '按小时聚合真实分钟增量' : '按分钟记录真实增量')
const rankCols = [{ key: 'label', label: '节点' }, { key: 'total', label: '累计流量' }, { key: 'rate', label: '当前速率' }]
const userRankCols = [{ key: 'email', label: '用户' }, { key: 'total', label: '累计流量' }, { key: 'rate', label: '当前速率' }]
const userCols = [{ key: 'email', label: '用户（email）' }, { key: 'nodes', label: '入站' }, { key: 'online', label: '在线地址' }, { key: 'speed', label: '速率' }, { key: 'today', label: '今日' }, { key: 'total', label: '累计' }]
const outCols = [{ key: 'tag', label: '出站' }, { key: 'protocol', label: '协议' }, { key: 'speed', label: '速率' }, { key: 'today', label: '今日' }, { key: 'total', label: '累计' }]
const nodeCols = computed(() => [{ key: 'label', label: '节点' }, { key: 'transport', label: '传输' }, { key: 'speed', label: '速率' }, { key: 'total', label: '累计 / 今日' }, { key: 'online', label: nodeOnly.value ? '在线状态' : '在线来源（核心口径）' }, { key: 'exit', label: '实测出口' }])
const pathCols = [{ key: 'instance', label: '实例' }, { key: 'label', label: '入口' }, { key: 'outbound', label: '出站' }, { key: 'exit', label: '实测出口' }, { key: 'total', label: '累计入站字节' }]
const sourceCols = [{ key: 'ip', label: '核心观察地址' }, { key: 'nodes', label: '节点' }, { key: 'location', label: '定位' }, { key: 'isp', label: '网络' }, { key: 'sampled_at', label: '采样时间' }]
const dailyCols = computed(() => [{ key: 'day', label: '日期' }, { key: 'instance', label: '实例' }, { key: 'label', label: dailyKinds.value.find(k => k.value === dailyKind.value).label }, { key: 'upload', label: '上传' }, { key: 'download', label: '下载' }])
const historyCols = [{ key: 'ts', label: '采样时段' }, { key: 'instance', label: '实例' }, { key: 'upload', label: '上传增量' }, { key: 'download', label: '下载增量' }]
const probeCols = [{ key: 'at', label: '时间' }, { key: 'label', label: '出口' }, { key: 'exit', label: '回显地址' }, { key: 'media', label: '媒体可达性' }]
const geoCols = [{ key: 'label', label: '出口' }, { key: 'exit_ip', label: '实测地址' }, { key: 'location', label: '定位' }, { key: 'isp', label: '网络' }, { key: 'precision', label: '精度' }]
const settingLabels = { 'alerts.collector_down_seconds': '采集中断告警（秒）', 'alerts.cert_days': '证书剩余（天）', 'alerts.disk_percent': '磁盘使用（%）', 'alerts.probe_failures': '出口连续失败告警（轮，0 关闭）', 'probes.interval_seconds': '出口探测间隔（秒）', 'reachability.interval_seconds': '国内入口检测间隔（秒，至少 600）', 'reachability.failures': '国内入口连续失败告警（轮）' }

function capabilityRows(id) {
  const st = data.value?.instances.find(i => i.id === id) || {}
  if (!st.connected) return []
  if (nodeOnly.value) return [['统计口径', '仅节点入站'], ['在线节点', '近 60 秒采样到真实入站流量'], ['访问控制', data.value?.capabilities?.access_control ? '已启用' : '未启用']]
  return [['用户统计', st.user_stats ? '已开启' : '未开启（叠加文件需开启用户等级统计）'],
    ['出站统计', st.outbound_stats ? '已开启' : '未开启（重新运行 enable-xray-stats.py）'],
    ['在线地址接口', st.users_api ? 'GetUsersStats（v26.10+）' : st.users_api === false ? '逐用户查询（较早版本核心）' : '无用户'],
    ['访问控制', data.value?.capabilities?.access_control ? 'iptables · 公网入站端口' : '未启用']]
}

function lineChart(rows, keys, names, format = bytes, type = 'line') {
  const t = state.tokens
  return { animation: false, color: [t.up, t.down], legend: { data: names, textStyle: { color: t.ink } }, grid: { left: 68, right: 18, top: 34, bottom: 30 }, tooltip: { trigger: 'axis' }, xAxis: { type: 'time', axisLabel: { color: t.muted } }, yAxis: { type: 'value', axisLabel: { color: t.muted, formatter: v => format(v) }, splitLine: { lineStyle: { color: t.grid } } }, series: keys.map((key, i) => ({ name: names[i], type, showSymbol: false, connectNulls: false, stack: type === 'bar' ? 'bytes' : undefined, data: rows.map(row => [row.t, row[key]]) })) }
}
const liveChart = computed(() => lineChart((data.value?.realtime || []).map(r => ({ t: r.t, ...(selected.value ? r.instances?.[selected.value] || { up: null, down: null } : r) })), ['up', 'down'], ['上传', '下载'], rate))
const trafficChart = computed(() => {
  const grouped = new Map()
  for (const r of minuteRows.value) { const a = grouped.get(r.ts) || { t: r.ts * 1000, upload: 0, download: 0 }; a.upload += r.upload; a.download += r.download; grouped.set(r.ts, a) }
  return lineChart([...grouped.values()], ['upload', 'download'], ['上传', '下载'], bytes, 'bar')
})
const dailyChart = computed(() => {
  const grouped = new Map()
  for (const r of dailyRows.value) { const a = grouped.get(r.day) || { t: Date.parse(r.day + 'T00:00:00'), upload: 0, download: 0 }; a.upload += r.upload; a.download += r.download; grouped.set(r.day, a) }
  return lineChart([...grouped.values()].sort((a, b) => a.t - b.t), ['upload', 'download'], ['上传', '下载'], bytes, 'bar')
})
const nicChart = computed(() => lineChart(network.value?.live || [], ['rx', 'tx'], ['网卡接收', '网卡发送'], rate))
const topologyChart = computed(() => {
  const labels = new Map(), edges = new Map()
  function link(a, an, b, bn, value) { labels.set(a, an); labels.set(b, bn); const key = a + '\n' + b; const edge = edges.get(key) || { source: a, target: b, value: 0 }; edge.value += value; edges.set(key, edge) }
  for (const n of nodes.value) {
    const size = n.upload + n.download
    if (!size) continue
    const out = outFor(n), root = 'core:' + n.instance, input = 'in:' + n.key
    link(root, instanceLabel(n.instance), input, n.label, size)
    if (out) { const output = 'out:' + out.key; link(input, n.label, output, out.label, size); if (out.exit_ip) link(output, out.label, 'ip:' + out.exit_ip, out.exit_ip, size) }
  }
  return { animation: false, tooltip: { trigger: 'item', formatter: p => esc(labels.get(p.name) || '流量') + '<br>' + bytes(p.value) }, series: [{ type: 'sankey', data: [...labels.keys()].map(name => ({ name })), links: [...edges.values()], nodeWidth: 15, nodeGap: 12, label: { color: state.tokens.ink, formatter: p => labels.get(p.name) }, lineStyle: { color: 'gradient', opacity: .25 }, emphasis: { focus: 'adjacency' } }] }
})
const mapChart = computed(() => ({
  geo: { map: 'xray-world', roam: true, itemStyle: { areaColor: state.tokens.land, borderColor: state.tokens.landLine }, emphasis: { disabled: true } },
  tooltip: { trigger: 'item', formatter: p => esc(p.data?.label || '') + '<br>' + esc(p.data?.ip || '') },
  series: [{ type: 'scatter', coordinateSystem: 'geo', symbol: 'diamond', symbolSize: 12, itemStyle: { color: state.tokens.accent }, data: exits.value.filter(o => o.geo?.lat != null && o.geo?.lon != null).map(o => ({ name: o.key, label: o.label, ip: o.exit_ip, value: [o.geo.lon, o.geo.lat] })) }],
}))

let detailBusy = false
async function loadDetails() {
  if (detailBusy || !['overview', 'history', 'daily', 'exits'].includes(props.section)) return
  detailBusy = true
  const requested = span.value
  try { const d = await get('api/xray/details', { range: requested }); if (requested === span.value) detail.value = d } catch (e) { toast(e.message, 'error') } finally { detailBusy = false; if (requested !== span.value) loadDetails() }
}
async function loadNetwork() { try { network.value = await get('api/xray/network') } catch { network.value = null } }
async function loadSystem() {
  try {
    const [s, p] = await Promise.all([get('api/system'), get('api/prefs')]); system.value = s
    Object.assign(draftLabels, p.effective['labels.xray'] || {})
    for (const key of [...Object.keys(settingLabels), 'probes.enabled']) settings[key] = p.effective[key]
    quotaGb.value = Math.round((p.effective['alerts.xray_user_daily_bytes'] || 0) / GB * 100) / 100
  } catch (e) { toast(e.message, 'error') }
}
async function probeNow() { try { await post('api/xray/probes/run'); await refreshXray() } catch (e) { toast(e.message, 'error') } }
async function save(body) { saving.value = true; try { await put('api/prefs', body); await refreshXray(); toast('已保存', 'ok') } catch (e) { toast(e.message, 'error') } finally { saving.value = false } }
const saveLabels = () => save({ 'labels.xray': Object.fromEntries(Object.entries(draftLabels).filter(([, v]) => String(v).trim()).map(([k, v]) => [k, String(v).trim()])) })
const saveSettings = () => save({ ...settings, ...(!nodeOnly.value ? { 'alerts.xray_user_daily_bytes': Math.max(0, Math.round(Number(quotaGb.value || 0) * GB)) } : {}) })
let timer, networkTimer, disposed = false
onMounted(async () => {
  loadDetails()
  if (props.section === 'network') { loadNetwork(); networkTimer = setInterval(() => { if (!document.hidden) loadNetwork() }, 2000) }
  if (props.section === 'system') loadSystem()
  if (props.section === 'map') {
    try { const topo = await (await fetch(landUrl)).json(); const land = feature(topo, topo.objects.land); echarts.registerMap('xray-world', land.type === 'FeatureCollection' ? land : { type: 'FeatureCollection', features: [land] }); mapReady.value = true } catch (e) { toast('地图加载失败：' + e.message, 'error') }
  }
  if (!disposed) timer = setInterval(() => { if (!document.hidden) loadDetails() }, 15000)
})
watch(span, loadDetails)
onBeforeUnmount(() => { disposed = true; clearInterval(timer); clearInterval(networkTimer) })
</script>

<style scoped>
.field { display: grid; gap: 6px; }
.field .input { width: 100%; }
</style>
