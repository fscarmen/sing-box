<template>
  <div class="grid">
    <div v-if="error" class="notice bad" role="alert">{{ error }}</div>
    <section class="card">
      <div class="card-head">
        <div><h2>服务器管理</h2><p>选择要管理的内核，安装节点、调整配置和获取订阅。两种内核独立运行。</p></div>
        <div class="toolbar"><label class="field">管理内核<select v-model="engine" class="input" :disabled="busy" aria-label="管理内核"><option value="singbox">sing-box</option><option value="xray">Xray</option></select></label><button class="btn sm" @click="load">刷新</button></div>
      </div>
      <div class="card-body" v-if="status">
        <p v-if="status.configuration_error" class="notice bad">{{ status.configuration_error }}</p>
        <div class="toolbar">
          <span class="pill" :class="status.service === 'active' ? 'good' : 'warn'">{{ status.installed ? (status.service === 'active' ? '运行中' : '已停止') : '尚未安装' }}</span>
          <span class="mono small">{{ status.version }}</span>
          <span class="spacer"></span>
          <template v-if="status.installed">
            <button v-if="engine === 'singbox'" class="btn sm" :disabled="busy" @click="submit('adopt', {}, '接管并连接监控', '将备份配置，添加本机监控 API 并重启 sing-box，代理连接可能短暂中断。')">接管 / 连接监控</button>
            <button class="btn sm" :disabled="busy" @click="submit('start')">启动</button>
            <button class="btn sm" :disabled="busy" @click="submit('restart', {}, '重启服务', '现有代理连接可能短暂中断。')">重启</button>
            <button class="btn danger sm" :disabled="busy" @click="submit('stop', {}, '停止服务', '代理连接将断开；面板仍保持可用。')">停止</button>
          </template>
        </div>
        <div v-if="status.inbounds.length" class="node-list">
          <div v-for="i in status.inbounds" :key="i.tag" class="node-row"><strong>{{ i.tag }}</strong><span>{{ i.type }}</span><span class="mono">{{ i.port }}</span></div>
        </div>
      </div>
    </section>

    <section class="card" v-if="status && !status.installed">
      <div class="card-head"><div><h2>安装向导</h2><p>使用此 fork 的部署脚本；任务在后台执行，关闭网页也会继续。</p></div></div>
      <form class="card-body grid" @submit.prevent="submit('install', install, '安装 ' + coreName, '将安装所选协议及依赖，并配置节点防火墙。面板端口应与节点端口不同。')">
        <div class="grid cols-2">
          <label class="field">服务器 IP / 域名<input v-model="install.server" class="input" required placeholder="服务器公网地址"></label>
          <label class="field">节点名称<input v-model="install.name" class="input" required pattern="[A-Za-z0-9_-]{1,40}"></label>
          <label class="field">起始端口<input v-model.number="install.start_port" type="number" class="input" min="100" max="65520" required></label>
        </div>
        <fieldset v-if="engine === 'singbox'" class="protocol-grid"><legend>选择协议（按选择顺序分配连续端口）</legend>
          <label v-for="(label, key) in status.protocols" :key="key" class="check"><input type="checkbox" :value="key" v-model="install.protocols">{{ label }}</label>
        </fieldset>
        <div class="grid cols-2" v-if="engine === 'singbox' && (install.protocols.includes('h') || install.protocols.includes('i'))">
          <label class="field" v-if="install.protocols.includes('h')">VMess WS 域名<input v-model="install.vmess_host_domain" class="input" required></label>
          <label class="field" v-if="install.protocols.includes('i')">VLESS WS 域名<input v-model="install.vless_host_domain" class="input" required></label>
        </div>
        <label v-if="engine === 'xray'" class="field">Reality SNI / 目标域名<input v-model="install.sni" class="input" required placeholder="www.apple.com"></label>
        <p v-if="engine === 'xray'" class="small muted">部署 VLESS + Reality + Vision，无需自己的域名或证书。默认 TCP 443；若已被 sing-box 使用，请改用 9443 等空闲端口。SNI 目标需支持 TLS 1.3 并能从 VPS 访问，安装后仍需客户端验证。</p>
        <p v-else class="small muted">默认 Reality TCP 443 + Hysteria2 UDP 444。WebSocket 的域名与 CDN 回源需预先配置；其他参数可在安装后编辑配置。</p>
        <button class="btn primary" type="submit" :disabled="busy || (engine === 'singbox' && !install.protocols.length)">开始安装</button>
      </form>
    </section>

    <template v-if="status?.installed">
      <section class="card">
        <div class="card-head"><div><h2>节点与配置</h2><p>配置由服务器实时读取；保存前会备份、校验，失败时尝试恢复。</p></div>
          <button class="btn sm" :disabled="busy" @click="readConfig">加载配置</button>
        </div>
        <div class="card-body grid" v-if="config">
          <label v-if="engine === 'xray'" class="field">客户端连接的服务器 IP / 域名<input v-model="config.server" class="input" required></label>
          <div class="toolbar"><label class="field grow">配置文件<select v-model="selected" class="input"><option v-for="(_, name) in config.files" :key="name">{{ name }}</option></select></label>
            <label v-if="engine === 'singbox'" class="field grow">新增文件名<input v-model="newFile" class="input" placeholder="例如 23_custom_inbounds.json"></label>
            <button v-if="engine === 'singbox'" class="btn sm" @click="addFile">新增</button><button v-if="engine === 'singbox'" class="btn danger sm" @click="removeFile">删除当前文件</button>
          </div>
          <div v-if="selectedInbound" class="grid cols-2">
            <label class="field">节点端口<input v-model.number="nodePort" class="input" type="number" min="100" max="65535"></label>
            <label class="field" v-if="selectedInbound.tls?.reality?.enabled || selectedInbound.streamSettings?.security === 'reality'">Reality SNI<input v-model="sni" class="input"></label>
            <label class="field" v-if="selectedInbound.type === 'hysteria2'">Hysteria2 上行 Mbps<input v-model.number="hyUp" type="number" min="0" class="input"></label>
            <label class="field" v-if="selectedInbound.type === 'hysteria2'">Hysteria2 下行 Mbps<input v-model.number="hyDown" type="number" min="0" class="input"></label>
            <button class="btn sm" @click="updateFields">更新到下方配置草稿</button>
          </div>
          <label class="field">配置内容（含节点凭据，请私密保存）<textarea class="input editor mono" v-if="selected" v-model="config.files[selected]" spellcheck="false" aria-label="配置内容"></textarea></label>
          <p v-if="engine === 'xray'" class="small muted">当前支持 Reality RAW/TCP 入站。端口和 SNI 可用表单调整；在 JSON 中复制入站或增加 clients 可添加节点/用户，每个用户 email 必须唯一。统计 API 固定为回环 8311，由项目维护。</p>
          <p v-else class="small muted">保留顶部 // 元数据注释。监控 API 配置由面板维护；增加协议可新增对应入站文件，出站与路由也可在这里调整。复杂 Nginx/Argo 变更暂需命令行。</p>
          <button class="btn primary" :disabled="busy" @click="submit('apply', config, '应用配置', '将校验并应用所有配置文件，同步订阅与防火墙。现有代理连接可能短暂中断；校验不通过不会应用。')">校验并应用</button>
        </div>
      </section>
      <section class="card">
        <div class="card-head"><div><h2>客户端配置与订阅</h2><p>Clash Meta 和 Shadowrocket 可使用同一条自动识别链接；也可下载配置文件导入。</p></div><div class="toolbar">
          <button class="btn sm" @click="go('rules')">管理代理规则</button><button class="btn sm" :disabled="busy" @click="submit('export')">重新生成</button><button class="btn sm" @click="readSubscriptions">查看配置</button>
        </div></div>
        <div class="card-body grid" v-if="subscriptions">
          <template v-if="subscriptions.links && Object.keys(subscriptions.links).length">
            <label class="field">订阅链接格式<select v-model="subscriptionLinkName" class="input"><option v-for="(_, name) in subscriptions.links" :key="name" :value="name">{{ formatNames[name] || name }}</option></select></label>
            <div class="toolbar"><input class="input grow mono" readonly :value="subscriptions.links[subscriptionLinkName]" aria-label="订阅链接"><button class="btn primary" @click="copyLink">复制订阅链接</button></div>
            <p class="small muted">链接包含节点访问密钥，请私密保存。默认面板使用自签名证书；客户端不信任时，先下载配置导入，或接入固定 HTTPS 域名。</p>
            <details><summary>设置固定订阅域名（可选）</summary>
              <form class="grid" @submit.prevent="submit('subscription', {origin: subscriptionOrigin}, '保存订阅域名', '请先完成域名和固定隧道接入。此操作仅更改订阅下载地址，节点服务器地址保持不变。')">
                <label class="field">已接入的 HTTPS 地址<input v-model="subscriptionOrigin" class="input" type="url" required placeholder="https://sub.example.com"></label>
                <p class="small muted">隧道回源填写 http://127.0.0.1:8308。该入口只提供订阅下载；域名配置步骤见仓库的固定订阅说明。</p>
                <button class="btn" :disabled="busy">保存固定地址</button>
              </form>
            </details>
          </template>
          <select v-model="subscriptionName" class="input" aria-label="客户端格式"><option v-for="(_, name) in subscriptions.files" :key="name">{{ name }}</option></select>
          <div class="toolbar"><button class="btn sm" @click="copySubscription">复制</button><button class="btn sm" @click="downloadSubscription">下载</button></div>
          <pre class="client-output mono small">{{ subscriptions.files[subscriptionName] }}</pre>
        </div>
      </section>
      <div class="grid cols-2">
        <section class="card"><div class="card-head"><div><h2>备份与恢复</h2><p>保留配置、证书和订阅；流量账本不受影响。</p></div><button class="btn sm" :disabled="busy" @click="submit('backup')">创建备份</button></div>
          <div class="card-body grid"><select v-model="backupName" class="input" aria-label="选择备份"><option value="">选择备份</option><option v-for="b in status.backups" :key="b">{{ b }}</option></select>
            <button class="btn danger" :disabled="busy || !backupName" @click="submit('restore', {backup: backupName}, '恢复备份', '当前配置会先备份，然后恢复选定配置并重启服务；代理连接可能短暂中断。')">恢复选定备份</button>
          </div></section>
        <section class="card"><div class="card-head"><div><h2>升级 {{ coreName }}</h2><p>指定版本，验证官方 SHA256 与现有配置兼容性。</p></div></div>
          <div class="card-body grid"><label class="field">目标版本<input v-model="version" class="input" :placeholder="engine === 'xray' ? '例如 26.10.21' : '例如 1.14.3'"></label>
            <button class="btn" :disabled="busy || !version" @click="submit('upgrade', {version}, '升级内核', '将备份旧二进制并检查配置。升级需要重启服务，失败时尝试恢复旧版本。')">检查并升级</button>
          </div></section>
      </div>
    </template>

    <section class="card" v-if="status"><div class="card-head"><div><h2>任务记录</h2><p>每台服务器串行执行任务；这里只显示阶段与结果，凭据不会写入任务日志。</p></div></div>
      <div class="card-body grid"><details v-for="j in status.jobs" :key="j.id" :open="j.state === 'running' || j.state === 'failed'">
        <summary>{{ j.engine === 'xray' ? 'Xray' : 'sing-box' }} · {{ names[j.operation] || j.operation }} · {{ states[j.state] || j.state }} · {{ new Date(j.created * 1000).toLocaleString('zh-CN') }}</summary>
        <ol class="job-events"><li v-for="(e, index) in j.events" :key="index">{{ e.message }}</li></ol>
        <p v-if="j.error" class="notice bad">{{ j.error }}</p>
      </details><p v-if="!status.jobs.length" class="small muted">暂无任务</p></div>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { get, post } from '../lib/api.js'
import { go } from '../lib/router.js'
import { confirmAction } from '../lib/confirm.js'
import { state, toast } from '../lib/state.js'
const engine = ref(state.engine === 'xray' ? 'xray' : 'singbox')
const coreName = computed(() => engine.value === 'xray' ? 'Xray' : 'sing-box')
const status = ref(null), error = ref(''), config = ref(null), selected = ref(''), newFile = ref('')
const subscriptions = ref(null), subscriptionName = ref(''), backupName = ref(''), version = ref('')
const subscriptionLinkName = ref('auto'), subscriptionOrigin = ref('')
const formatNames = { 'shadowrocket.conf': 'Shadowrocket 远程规则配置', 'rules-clash': 'Clash 规则片段', 'rules-sing-box': 'sing-box 路由片段', 'rules-v2rayn.json': 'v2rayN 路由 JSON', auto: '自动识别（Clash / Shadowrocket）', clash: 'Clash（在线节点列表）', clash2: 'Clash（完整配置）', proxies: 'Clash 节点列表', shadowrocket: 'Shadowrocket', 'sing-box': 'sing-box', v2rayn: 'v2rayN', throne: 'Throne' }
const install = ref({ server: '', name: engine.value === 'xray' ? 'xray' : 'sing-box', start_port: 443, protocols: ['b', 'c'], vmess_host_domain: '', vless_host_domain: '', sni: 'www.apple.com' })
const nodePort = ref(443), sni = ref(''), hyUp = ref(0), hyDown = ref(0)
const busy = computed(() => status.value?.jobs.some(j => ['queued', 'running'].includes(j.state)))
const names = { install: '安装', adopt: '接管', apply: '应用配置', start: '启动', stop: '停止', restart: '重启', backup: '备份', restore: '恢复', export: '生成订阅', upgrade: '升级', subscription: '设置订阅域名' }
const states = { queued: '等待中', running: '执行中', succeeded: '成功', failed: '失败', interrupted: '已中断' }
const selectedInbound = computed(() => { try { return JSON.parse((config.value?.files[selected.value] || '{}').replace(/^\s*\/\/.*$/gm, '')).inbounds?.[0] } catch { return null } })
watch(selectedInbound, i => { if (!i) return; nodePort.value = engine.value === 'xray' ? i.port : i.listen_port; sni.value = i.streamSettings?.realitySettings?.serverNames?.[0] || i.tls?.server_name || ''; hyUp.value = i.up_mbps || 0; hyDown.value = i.down_mbps || 0 })
watch(engine, () => { status.value = null; config.value = null; subscriptions.value = null; subscriptionOrigin.value = ''; version.value = ''; backupName.value = ''; install.value.name = engine.value === 'xray' ? 'xray' : 'sing-box'; load() })
async function load() { const requestedEngine = engine.value; try { const before = status.value?.jobs[0]; const previous = before?.id + ':' + before?.state; const result = await get('api/manage/status', {engine: requestedEngine}); if (engine.value !== requestedEngine) return; status.value = result; if (!install.value.server) install.value.server = status.value.server; error.value = ''; const latest = status.value.jobs[0]; if (status.value.installed && (!subscriptions.value || (latest?.state === 'succeeded' && previous !== latest.id + ':' + latest.state))) await readSubscriptions() } catch (e) { error.value = e.message } }
async function submit(op, body = {}, title = '', message = '') {
  if (title && !await confirmAction({ title, message, danger: ['stop', 'restore'].includes(op) })) return
  try { await post('api/manage/' + op, {...body, engine: engine.value}); toast('任务已创建'); await load() } catch (e) { error.value = e.message }
}
async function readConfig() { const requestedEngine = engine.value; try { const result = await get('api/manage/config', {engine: requestedEngine}); if (engine.value !== requestedEngine) return; config.value = result; selected.value = Object.keys(config.value.files)[0] || '' } catch (e) { error.value = e.message } }
function addFile() { if (!/^[0-9]{2}_[A-Za-z0-9_.-]+\.json$/.test(newFile.value) || newFile.value === '09_dashboard_api.json' || config.value.files[newFile.value]) { error.value = '文件名无效、已存在或受保护'; return }; config.value.files[newFile.value] = '{\n  "inbounds": []\n}\n'; selected.value = newFile.value; newFile.value = '' }
async function removeFile() { if (!selected.value || !await confirmAction({ title: '从草稿移除文件', message: '点击“校验并应用”后才会在服务器删除。', danger: true })) return; delete config.value.files[selected.value]; selected.value = Object.keys(config.value.files)[0] || '' }
function updateFields() {
  try { const text = config.value.files[selected.value]; const comments = text.split('\n').filter(l => l.trimStart().startsWith('//')).join('\n'); const doc = JSON.parse(text.replace(/^\s*\/\/.*$/gm, '')); const i = doc.inbounds[0]; if (engine.value === 'xray') { i.port = Number(nodePort.value); if (i.streamSettings?.realitySettings) { i.streamSettings.realitySettings.serverNames = [sni.value]; i.streamSettings.realitySettings.target = sni.value + ':443' } } else { i.listen_port = Number(nodePort.value) }; if (i.tls?.reality?.enabled) { i.tls.server_name = sni.value; i.tls.reality.handshake.server = sni.value }; if (i.type === 'hysteria2') { i.up_mbps = Number(hyUp.value); i.down_mbps = Number(hyDown.value) }; config.value.files[selected.value] = (comments ? comments + '\n' : '') + JSON.stringify(doc, null, 2) + '\n'; toast('已更新草稿，请校验并应用') } catch { error.value = '配置格式错误，请先修复 JSON' }
}
async function readSubscriptions() { const requestedEngine = engine.value; try { const result = await get('api/manage/subscriptions', {engine: requestedEngine}); if (engine.value !== requestedEngine) return; subscriptions.value = result; if (!subscriptions.value.files[subscriptionName.value]) subscriptionName.value = subscriptions.value.files.clash2 ? 'clash2' : Object.keys(subscriptions.value.files)[0] || ''; if (!subscriptionOrigin.value) subscriptionOrigin.value = subscriptions.value.origin || '' } catch (e) { error.value = e.message } }
async function copyLink() { try { await navigator.clipboard.writeText(subscriptions.value.links[subscriptionLinkName.value]); toast('订阅链接已复制') } catch { error.value = '复制失败，请长按或选中订阅链接手动复制' } }
async function copySubscription() { try { await navigator.clipboard.writeText(subscriptions.value.files[subscriptionName.value]); toast('已复制') } catch { error.value = '复制失败，请选中配置文本手动复制' } }
function downloadSubscription() { const url = URL.createObjectURL(new Blob([subscriptions.value.files[subscriptionName.value]], { type: 'text/plain;charset=utf-8' })); const link = document.createElement('a'); link.href = url; link.download = subscriptionName.value + (subscriptionName.value.endsWith('.conf') || subscriptionName.value.endsWith('.json') ? '' : subscriptionName.value.includes('clash') ? '.yaml' : subscriptionName.value.includes('sing-box') ? '.json' : '.txt'); link.click(); URL.revokeObjectURL(url) }
let timer
onMounted(() => { load(); timer = setInterval(() => { if (!document.hidden) load() }, 2500) })
onBeforeUnmount(() => clearInterval(timer))
</script>

<style scoped>
.protocol-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 14px; border: 1px solid var(--border); border-radius: 8px; padding: 18px; }
.check { display: flex; align-items: center; gap: 9px; font-size: 13px; }
.editor { min-height: 360px; resize: vertical; line-height: 1.6; tab-size: 2; }
.client-output { white-space: pre-wrap; overflow-wrap: anywhere; max-height: 400px; overflow-y: auto; }
.node-list { margin-top: 18px; }
.node-row { display: grid; grid-template-columns: 1fr 110px 70px; padding: 10px 0; border-top: 1px solid var(--border); font-size: 13px; }
.job-events { padding-left: 20px; font-size: 13px; line-height: 1.9; }
summary { cursor: pointer; font-size: 13px; padding: 8px 0; }
.grow { flex: 1; min-width: 180px; }
</style>
