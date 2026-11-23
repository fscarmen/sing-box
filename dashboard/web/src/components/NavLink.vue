<template>
  <a :href="href" @click.prevent="navigate"><slot /></a>
</template>

<script setup>
import { computed } from 'vue'
import { go } from '../lib/router.js'

const props = defineProps({ to: { type: String, required: true }, query: { type: Object, default: () => ({}) } })
const emit = defineEmits(['navigate'])
const href = computed(() => {
  const qs = new URLSearchParams(Object.entries(props.query).filter(([, v]) => v)).toString()
  return '#/' + props.to + (qs ? '?' + qs : '')
})
function navigate() {
  emit('navigate')
  go(props.to, props.query)
}
</script>
