<template>
  <div class="grid">
    <section class="card">
      <div class="card-head">
        <div><h2>登录会话</h2><p>会话令牌只以哈希保存；撤销后该设备需要重新登录。</p></div>
        <button class="btn sm danger" type="button" :disabled="sessions.length < 2" @click="revokeAll">退出其他所有会话</button>
      </div>
      <div class="card-body flush">
        <DataTable :columns="sessionCols" :rows="sessions" sort="last_seen" hide-foot>
          <template #cell-agent="{ row }"><span :title="row.agent">{{ agentName(row.agent) }}</span><span v-if="row.current" class="tag on">当前</span></template>
          <template #cell-ip="{ row }"><span class="mono">{{ row.ip || '—' }}</span></template>
          <template #cell-created="{ row }">{{ row.created ? datetime(row.created * 1000) : '升级前' }}</template>
          <template #cell-last_seen="{ row }">{{ row.last_seen ? ago(row.last_seen * 1000) : '—' }}</template>
          <template #cell-expires="{ row }">{{ datetime(row.expires * 1000) }}</template>
          <template #cell-action="{ row }"><button v-if="!row.current" class="btn sm" type="button" @click="revoke(row)">撤销</button></template>
        </DataTable>
      </div>
    </section>
    <section class="card">
      <div class="card-head">
        <div><h2>审计日志</h2><p>登录、封禁、解除、断开连接、设置修改等操作。</p></div>
        <div class="toolbar">
          <select v-model="action" class="input" aria-label="操作类型">
            <option value="">全部操作</option>
            <option v-for="a in actions" :key="a" :value="a">{{ actionName(a) }}</option>
          </select>
          <ExportLink kind="audit" />
        </div>
      </div>
      <div class="card-body flush">
        <DataTable :columns="auditCols" :rows="audit" :total="auditTotal" :page-size="50" @page="e => loadAudit(e.offset)">
          <template #cell-at="{ row }">{{ datetime(row.at * 1000) }}</template>
          <template #cell-action="{ row }"><span class="tag">{{ actionName(row.action) }}</span></template>
          <template #cell-ip="{ row }"><span class="mono">{{ row.ip || '—' }}</span></template>
        </DataTable>
      </div>
    </section>
  </div>
</template>

<script setup>
import ExportLink from '../components/ExportLink.vue'
import { onMounted, ref, watch } from 'vue'
import DataTable from '../components/DataTable.vue'
import Icon from '../components/Icon.vue'
import { get, post } from '../lib/api.js'
import { ago, datetime } from '../lib/format.js'
import { toast } from '../lib/state.js'
import { confirmAction } from '../lib/confirm.js'

const sessions = ref([])
const audit = ref([])
const auditTotal = ref(0)
const action = ref('')
const actions = ['login', 'ban', 'unban', 'unban-expired', 'close-connection', 'revoke-session', 'prefs', 'probe']
const NAMES = { login: '登录', ban: '封禁', unban: '解除封禁', 'unban-expired': '到期解除', 'close-connection': '断开连接', 'revoke-session': '撤销会话', prefs: '修改设置', probe: '手动探测' }
const actionName = a => NAMES[a] || a
const sessionCols = [
  { key: 'user', label: '账户', format: v => v || '主账户（升级前登录）' }, { key: 'agent', label: '设备' }, { key: 'ip', label: '登录 IP' }, { key: 'created', label: '登录时间' }, { key: 'last_seen', label: '最近活动' },
  { key: 'expires', label: '过期' }, { key: 'action', label: '', sortable: false },
]
const auditCols = [{ key: 'at', label: '时间', sortable: false }, { key: 'action', label: '操作', sortable: false }, { key: 'ip', label: '地址 / 来源', sortable: false }, { key: 'detail', label: '说明', class: 'wrap', sortable: false }]

function agentName(ua) {
  if (!ua) return '未知设备（升级前登录）'
  const os = /iPhone|iPad/.test(ua) ? 'iOS' : /Android/.test(ua) ? 'Android' : /Mac OS X/.test(ua) ? 'macOS' : /Windows/.test(ua) ? 'Windows' : /Linux/.test(ua) ? 'Linux' : '其他'
  const br = /Edg\//.test(ua) ? 'Edge' : /Chrome\//.test(ua) ? 'Chrome' : /Firefox\//.test(ua) ? 'Firefox' : /Safari\//.test(ua) ? 'Safari' : /python|curl/i.test(ua) ? '脚本' : '浏览器'
  return br + ' · ' + os
}
async function loadSessions() { sessions.value = (await get('api/sessions')).rows }
async function loadAudit(offset = 0) {
  const d = await get('api/audit', { limit: 50, offset, action: action.value })
  audit.value = d.rows
  auditTotal.value = d.total
}
async function revoke(row) {
  if (!await confirmAction({ title: '撤销会话', message: '该设备（' + agentName(row.agent) + '）需要重新登录。', confirm: '撤销', danger: true })) return
  try { await post('api/sessions/revoke', { id: row.id }); toast('已撤销', 'ok'); loadSessions() } catch (e) { toast(e.message, 'error') }
}
async function revokeAll() {
  if (!await confirmAction({ title: '退出其他会话', message: '除当前浏览器外的所有登录都将失效。', confirm: '全部退出', danger: true })) return
  try { await post('api/sessions/revoke', { id: '*', all: true }); toast('已退出其他会话', 'ok'); loadSessions() } catch (e) { toast(e.message, 'error') }
}
watch(action, () => loadAudit(0))
onMounted(() => { loadSessions(); loadAudit() })
</script>
