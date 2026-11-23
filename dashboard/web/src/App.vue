<template>
  <div class="shell">
    <aside class="sidebar" aria-label="导航">
      <div class="brand">
        <span class="brand-mark"><svg viewBox="0 0 32 32" width="18" height="18" aria-hidden="true"><path d="M6 22 L13 10 L19 18 L26 7" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" /></svg></span>
        <span>{{ title }}<small>v{{ state.overview?.version || '2' }}</small></span>
      </div>
      <div v-if="state.overview?.xray?.enabled && state.overview?.singbox_enabled !== false" class="engine-picker">
        <label class="small muted" for="engine">监控来源</label>
        <select id="engine" v-model="state.engine" class="input" aria-label="监控来源">
          <option value="xray" :disabled="state.overview && !state.overview.xray?.enabled">Xray{{ state.overview?.xray?.enabled ? '（主要）' : '（未配置）' }}</option><option value="singbox" :disabled="state.overview?.singbox_enabled === false">sing-box{{ state.overview?.singbox_enabled === false ? '（未启用）' : state.overview?.xray?.enabled ? '（次要）' : '' }}</option>
        </select>
      </div>
      <nav v-for="g in groups" :key="g.name" class="nav-group">
        <span>{{ g.name }}</span>
        <NavLink v-for="r in g.routes" :key="r.name" :to="r.name" class="nav-item" :class="{ active: route.name === r.name }" :aria-current="route.name === r.name ? 'page' : null">
          <Icon :name="r.icon" />{{ r.title }}
          <span v-if="r.name === 'alerts' && unread" class="count">{{ unread }}</span>
        </NavLink>
      </nav>
      <div class="sidebar-foot">
        <span>{{ state.engine === 'xray' ? 'Xray 原生统计 · 入站口径' : 'sing-box 连接事件' }}</span>
        <span>时区 {{ state.overview?.timezone || '—' }}</span>
      </div>
    </aside>
    <div class="main">
      <header class="topbar">
        <h1>{{ current.title }}</h1>
        <span class="pill" :class="linkClass" :title="linkTitle"><i></i>{{ linkText }}</span>
        <span class="spacer"></span>
        <button class="icon-btn" type="button" :aria-label="state.theme === 'dark' ? '切换浅色' : '切换深色'" @click="toggleTheme"><Icon :name="state.theme === 'dark' ? 'sun' : 'moon'" /></button>
        <button class="icon-btn" type="button" aria-label="刷新数据" @click="reload"><Icon name="refresh" /></button>
        <span v-if="state.overview?.user" class="small muted nowrap">{{ state.overview.user }}</span>
        <button class="btn sm" type="button" @click="logout"><Icon name="logout" :size="14" />退出</button>
      </header>
      <main class="content">
        <div v-if="notice" class="notice" :class="notice.kind"><Icon name="warn" /><span>{{ notice.text }}</span></div>
        <component :is="resolvedView" :section="route.name" :key="state.engine + route.name + reloadKey" />
      </main>
    </div>
    <IpDrawer v-if="route.ip && state.engine === 'singbox'" :ip="route.ip" />
    <ConfirmDialog />
    <div class="toasts" role="status" aria-live="polite">
      <div v-for="t in state.toasts" :key="t.id" class="toast" :class="t.kind">{{ t.message }}</div>
    </div>
  </div>
</template>

<script setup>
import { computed, defineAsyncComponent, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import Icon from './components/Icon.vue'
import ConfirmDialog from './components/ConfirmDialog.vue'
import IpDrawer from './components/IpDrawer.vue'
import Overview from './views/Overview.vue'
import { ROUTES, route, go } from './lib/router.js'
import { state, refreshOverview, refreshXray, toast } from './lib/state.js'
import { startLive, stopLive } from './lib/live.js'
import { engineStatus } from './lib/engines.js'
import { toggleTheme } from './lib/theme.js'
import NavLink from './components/NavLink.vue'
import { BASE, post } from './lib/api.js'

const lazy = loader => defineAsyncComponent(loader)
const views = {
  rules: lazy(() => import('./views/Rules.vue')),
  manage: lazy(() => import('./views/Manage.vue')),
  xray: lazy(() => import('./views/Xray.vue')),
  overview: Overview,
  live: lazy(() => import('./views/Live.vue')),
  topology: lazy(() => import('./views/Topology.vue')),
  map: lazy(() => import('./views/GeoMap.vue')),
  network: lazy(() => import('./views/Network.vue')),
  clients: lazy(() => import('./views/Clients.vue')),
  history: lazy(() => import('./views/History.vue')),
  daily: lazy(() => import('./views/Daily.vue')),
  exits: lazy(() => import('./views/Exits.vue')),
  bans: lazy(() => import('./views/Bans.vue')),
  alerts: lazy(() => import('./views/Alerts.vue')),
  security: lazy(() => import('./views/Security.vue')),
  system: lazy(() => import('./views/System.vue')),
}
const XrayMain = lazy(() => import('./views/XrayMain.vue'))
const shared = new Set(['alerts', 'security', 'manage', 'rules'])
// Bans are engine-neutral firewall rules: Xray uses the shared page once access control is enabled.
const resolvedView = computed(() => state.engine === 'xray' && !shared.has(route.name) && !(route.name === 'bans' && state.overview?.features?.xray_bans) ? XrayMain : views[route.name])
const activeRoutes = computed(() => ROUTES.filter(r =>
  (state.engine === 'xray' || r.name !== 'xray') &&
  (r.name !== 'manage' || state.overview?.features?.management) &&
  (r.name !== 'rules' || state.overview?.features?.client_rules)
).map(r => {
  if (state.engine !== 'xray') return r
  if (r.name === 'xray') return { ...r, title: '节点列表' }
  if (r.name === 'clients' && state.xray?.node_only) return { ...r, title: '在线节点' }
  return { ...r, title: r.xrayTitle || r.title }
}))
const groups = computed(() => ['监控', '数据', '管理'].map(name => ({ name, routes: activeRoutes.value.filter(r => r.group === name) })))
const current = computed(() => activeRoutes.value.find(r => r.name === route.name) || activeRoutes.value[0])
const title = computed(() => state.overview?.title || '网络节点监控')
const reloadKey = ref(0)

const health = computed(() => engineStatus(state.engine, state.overview, state.xray, state.xrayError, state.link, state.now))
const linkClass = computed(() => health.value.kind)
const linkText = computed(() => health.value.text)
const linkTitle = computed(() => state.engine === 'xray' ? '来自 Xray 原生入站计数，每 2 秒刷新，未知速率留空' : 'sing-box 连接事件')
const notice = computed(() => {
  const o = state.overview
  if (state.engine === 'singbox' && o?.features?.management && !o.topology?.inbounds?.length) return { kind: 'warn', text: '尚未连接节点，请到服务器管理中选择 sing-box 或 Xray 安装。' }
  return health.value.notice ? { kind: health.value.kind, text: health.value.notice } : null
})
const unread = computed(() => state.engine === 'xray' ? state.overview?.alerts_xray || 0 : state.overview?.alerts || 0)

watch(title, t => { document.title = t + ' · ' + current.value.title }, { immediate: true })
watch(current, () => { document.title = title.value + ' · ' + current.value.title })
watch(() => state.engine, engine => {
  route.ip = ''
  stopLive()
  if (engine === 'xray') refreshXray()
  else { if (route.name === 'xray') go('overview'); startLive() }
}, { immediate: true })

let timer = null
let xrayTimer = null
const becameVisible = () => { state.now = Date.now(); if (!document.hidden) { refreshOverview(); if (state.engine === 'xray') refreshXray() } }
onMounted(() => {
  refreshOverview().then(o => { if (o?.singbox_enabled !== false && !o?.xray?.enabled && o?.features?.management && !o.topology?.inbounds?.length && !location.hash) go('manage') })
  timer = setInterval(() => { if (!document.hidden) refreshOverview() }, 15000)
  xrayTimer = setInterval(() => { state.now = Date.now(); if (state.engine === 'xray' && !document.hidden) refreshXray() }, 2000)
  document.addEventListener('visibilitychange', becameVisible)
})
onBeforeUnmount(() => { clearInterval(timer); clearInterval(xrayTimer); document.removeEventListener('visibilitychange', becameVisible); stopLive() })

function reload() {
  refreshOverview()
  if (state.engine === 'xray') refreshXray()
  reloadKey.value += 1
}

async function logout() {
  try { await post('logout') } catch (e) { toast(e.message, 'error') }
  location.href = BASE + '/login'
}
</script>

<style scoped>
.engine-picker { padding: 0 14px 12px; display: grid; gap: 6px; }
.engine-picker .input { width: 100%; }
</style>
