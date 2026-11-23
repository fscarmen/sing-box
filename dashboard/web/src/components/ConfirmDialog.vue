<template>
  <dialog ref="el" @close="settle(false)" @cancel.prevent="settle(false)">
    <form method="dialog" @submit.prevent="settle(true)">
      <div class="dialog-body">
        <h2>{{ current.title }}</h2>
        <p>{{ current.message }}</p>
      </div>
      <div class="dialog-actions">
        <button class="btn" type="button" @click="settle(false)">取消</button>
        <button class="btn" :class="current.danger ? 'danger' : 'primary'" type="submit">{{ current.confirm || '确定' }}</button>
      </div>
    </form>
  </dialog>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { registerConfirm } from '../lib/confirm.js'

const el = ref(null)
const current = reactive({ title: '', message: '', confirm: '', danger: false })
let resolver = null

registerConfirm(options => new Promise(resolve => {
  Object.assign(current, { title: '', message: '', confirm: '', danger: false }, options)
  resolver = resolve
  el.value.showModal()
}))

function settle(value) {
  if (!resolver) return
  const r = resolver
  resolver = null
  if (el.value.open) el.value.close()
  r(value)
}
</script>
