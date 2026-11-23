<template>
  <dialog ref="dialog" aria-labelledby="client-rule-title" @cancel.prevent="close">
    <form @submit.prevent="save">
      <div class="dialog-body grid">
        <h2 id="client-rule-title">{{ existingId ? '编辑代理规则' : '添加目标规则' }}</h2>
        <p v-if="fromHistory">从连接历史选择目标。设置为直连后，后续请求由客户端本地直连，通常不会再出现在 VPS 历史中。</p>
        <p v-if="matched">当前命中：{{ ruleTypes[matched.type] }} {{ matched.target }} → {{ ruleActions[matched.action] }}。新建规则放在列表最前。</p>
        <p v-if="error" class="notice bad" role="alert">{{ error }}</p>
        <label class="field">匹配方式<select class="input" v-model="form.type"><option v-for="(name, type) in ruleTypes" :key="type" :value="type">{{ name }}</option></select></label>
        <label class="field">目标域名 / IP 网段<input class="input" v-model="form.target" required maxlength="300" placeholder="example.com 或 203.0.113.10/32" autofocus></label>
        <p class="small muted" v-if="form.type === 'domain_suffix'">匹配此域名本身和它的子域名。请填写希望覆盖的域名，不会自动扩大到主域名。</p>
        <label class="field">动作<select class="input" v-model="form.action"><option v-for="(name, action) in ruleActions" :key="action" :value="action">{{ name }}</option></select></label>
        <label class="field">备注<input class="input" v-model="form.note" maxlength="200"></label>
        <label class="check"><input type="checkbox" v-model="form.enabled">启用此规则</label>
        <p class="small muted">统一应用到两种内核的客户端配置。Clash / sing-box 更新完整配置生效；Shadowrocket 需更新已启用的远程配置，单独更新节点订阅不会更新规则。</p>
      </div>
      <div class="dialog-actions"><button class="btn" type="button" :disabled="saving" @click="close">取消</button><button class="btn" type="button" :disabled="saving" @click="load">重新载入规则版本</button><button class="btn primary" :disabled="saving || !data" type="submit">{{ saving ? '正在发布…' : '保存并发布' }}</button></div>
    </form>
  </dialog>
</template>
<script setup>
import { onMounted, onBeforeUnmount, reactive, ref } from 'vue'
import { get } from '../lib/api.js'
import { ruleActions, ruleTypes, mergeRule, publishRules } from '../lib/clientRules.js'
const props = defineProps({ initial: {type: Object, default: () => ({})}, existingId: {type: String, default: ''}, matched: Object, fromHistory: Boolean })
const emit = defineEmits(['close', 'saved'])
const dialog = ref(null), data = ref(null), saving = ref(false), error = ref('')
const form = reactive({type: 'domain', target: '', action: 'proxy', enabled: true, note: '', ...props.initial})
async function load() { try { data.value = await get('api/manage/rules'); error.value = '' } catch (e) { error.value = e.message } }
function close() { if (!saving.value) emit('close') }
async function save() {
  saving.value = true; error.value = ''
  try {
    if (props.existingId && !data.value.policy.rules.some(r => r.id === props.existingId)) throw new Error('此规则已被删除，请关闭后刷新')
    await publishRules(mergeRule(data.value.policy, form, props.existingId), data.value.revision)
    emit('saved'); emit('close')
  } catch (e) { error.value = e.message }
  finally { saving.value = false }
}
onMounted(() => { dialog.value.showModal(); load() })
onBeforeUnmount(() => { if (dialog.value?.open) dialog.value.close() })
</script>
<style scoped>
dialog { width: min(620px, calc(100vw - 30px)); max-height: calc(100vh - 40px); overflow: auto; }
.check { display: flex; align-items: center; gap: 8px; }
</style>
