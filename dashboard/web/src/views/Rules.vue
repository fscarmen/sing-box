<template>
  <div class="grid">
    <section class="card">
      <div class="card-head"><div><h2>客户端代理规则</h2><p>{{ data?.scope || '统一管理客户端订阅中的目标规则' }}</p></div><div class="toolbar"><button class="btn sm" :disabled="busy" @click="load">刷新</button><button class="btn primary sm" :disabled="busy || !data" @click="editor = {initial: {}}">添加规则</button></div></div>
      <div class="card-body grid">
        <p v-if="error" class="notice bad" role="alert">{{ error }}</p>
        <p class="small muted">规则保存后立即用于后续下载，不会自动推送到手机。客户端需要更新并启用对应配置；本地覆写和全局模式可能覆盖规则。页面不代表设备已经同步。</p>
        <div class="toolbar" v-if="data"><label class="field grow">未命中时的策略<select class="input" :value="data.policy.default_action" :disabled="busy" @change="changeDefault($event)"><option value="inherit">保留各客户端基础规则</option><option value="proxy">默认代理</option><option value="direct">默认直连</option><option value="reject">默认拒绝</option></select></label><span class="small muted">已发布版本 <code>{{ data.revision.slice(0, 12) }}</code></span></div>
        <p class="small muted">“默认策略”替换基础配置的最终兜底，基础中的具体匹配规则仍然保留。Shadowrocket 新生成的远程配置没有手机本地基础规则，保留策略时最终走 PROXY。</p>
      </div>
      <div class="table-wrap" v-if="data"><table class="data"><thead><tr><th>顺序</th><th>匹配</th><th>目标</th><th>动作</th><th>启用</th><th>备注</th><th>操作</th></tr></thead><tbody><tr v-for="(row, index) in data.policy.rules" :key="row.id"><td>{{ index + 1 }}</td><td>{{ ruleTypes[row.type] }}</td><td class="mono">{{ row.target }}</td><td>{{ ruleActions[row.action] }}</td><td><input type="checkbox" :checked="row.enabled" :disabled="busy" :aria-label="'启用 ' + row.target" @change="toggle(row, $event)"></td><td>{{ row.note || '—' }}</td><td><div class="toolbar"><button class="btn sm" :disabled="busy || index === 0" @click="move(index, -1)" :aria-label="'上移 ' + row.target">上移</button><button class="btn sm" :disabled="busy || index === data.policy.rules.length - 1" @click="move(index, 1)" :aria-label="'下移 ' + row.target">下移</button><button class="btn sm" :disabled="busy" @click="editor = {initial: row, existingId: row.id}">编辑</button><button class="btn danger sm" :disabled="busy" @click="remove(row)">删除</button></div></td></tr><tr v-if="!data.policy.rules.length"><td colspan="7" class="empty">尚无统一规则。可手动添加，或从 sing-box 连接历史的目标添加。</td></tr></tbody></table></div>
    </section>
    <section class="card" v-if="data"><div class="card-head"><div><h2>各客户端更新方式</h2><p>规则来自同一份列表，按客户端支持的格式下发。</p></div></div><div class="card-body grid"><div v-for="cap in data.capabilities" :key="cap.client"><strong>{{ cap.client }}</strong><p class="small muted">{{ cap.message }}</p></div></div></section>
    <section class="card" v-if="data">
      <div class="card-head"><div><h2>当前下发规则与预览</h2><p>基础规则与最终规则均从当前订阅生成。无法读取设备本地配置；远程规则集内容不会在服务器上展开。</p></div></div>
      <div class="card-body grid">
        <p v-if="!data.clients.length" class="small muted">尚未发布客户端配置。可先设置统一规则，安装并生成订阅后自动应用。</p>
        <template v-else><label class="field">配置来源<select v-model="selected" class="input"><option v-for="(c, index) in data.clients" :key="c.engine + c.format" :value="index">{{ c.engine === 'xray' ? 'Xray' : 'sing-box' }} · {{ clientFormats[c.format] }}</option></select></label>
          <div class="toolbar"><input readonly class="input grow mono" :value="current?.url" aria-label="对应配置链接"><button class="btn" @click="copy">复制链接</button></div>
          <p class="small muted">配置链接含订阅密钥，请私密保存。</p>
          <p v-if="current?.error" class="notice bad">{{ current.error }}</p>
          <template v-else-if="current"><label class="field">预览内容<select v-model="showBase" class="input"><option :value="false">最终下发规则</option><option :value="true">原始基础规则</option></select></label><p class="small muted">{{ current.format === 'shadowrocket.conf' ? '此配置需要在 Shadowrocket 的“配置”中导入并启用；启用后将替换当前规则配置。' : current.format === 'rules-v2rayn.json' ? '这是单独导入的路由 JSON，节点订阅不会更新它。' : '请使用完整配置订阅并重新加载；节点提供者订阅不包含规则。' }}</p><pre class="rule-preview mono small">{{ JSON.stringify(showBase ? current.base : current.effective, null, 2) }}</pre></template>
        </template>
      </div>
    </section>
    <ClientRuleDialog v-if="editor" v-bind="editor" @close="editor = null" @saved="saved" />
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import ClientRuleDialog from '../components/ClientRuleDialog.vue'
import { get } from '../lib/api.js'
import { toast } from '../lib/state.js'
import { confirmAction } from '../lib/confirm.js'
import { ruleActions, ruleTypes, clientFormats, moveRule, publishRules } from '../lib/clientRules.js'
const data = ref(null), error = ref(''), busy = ref(false), selected = ref(-1), showBase = ref(false), editor = ref(null)
const current = computed(() => data.value?.clients[selected.value])
async function load() { try { data.value = await get('api/manage/rules'); if (selected.value < 0 || selected.value >= data.value.clients.length) selected.value = Math.max(0, data.value.clients.findIndex(c => c.format === 'clash2')); error.value = '' } catch (e) { error.value = e.message } }
async function commit(policy) { busy.value = true; try { await publishRules(policy, data.value.revision); toast('规则已发布，请在客户端更新配置'); await load() } catch (e) { error.value = e.message } finally { busy.value = false } }
function changeDefault(event) { const action = event.target.value; event.target.value = data.value.policy.default_action; const policy = JSON.parse(JSON.stringify(data.value.policy)); policy.default_action = action; commit(policy) }
function toggle(row, event) { event.target.checked = row.enabled; const policy = JSON.parse(JSON.stringify(data.value.policy)); policy.rules.find(r => r.id === row.id).enabled = !row.enabled; commit(policy) }
function move(index, step) { commit(moveRule(data.value.policy, index, step)) }
async function remove(row) { if (!await confirmAction({title: '删除客户端规则', message: row.target + ' 将恢复使用后续规则，客户端更新配置后生效。', danger: true})) return; const policy = JSON.parse(JSON.stringify(data.value.policy)); policy.rules = policy.rules.filter(r => r.id !== row.id); commit(policy) }
async function copy() { try { await navigator.clipboard.writeText(current.value.url); toast('已复制配置链接') } catch { error.value = '复制失败，请选中链接手动复制' } }
function saved() { toast('规则已发布，请在客户端更新配置'); load() }
onMounted(load)
</script>
<style scoped>
.rule-preview { max-height: 500px; overflow: auto; white-space: pre-wrap; overflow-wrap: anywhere; }
.grow { flex: 1; min-width: 220px; }
</style>
