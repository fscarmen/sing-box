<template>
  <span class="status" :class="kind">
    <Icon :name="kind === 'good' ? 'check' : kind === 'bad' ? 'x' : 'warn'" :size="14" />
    <slot>{{ text }}</slot>
  </span>
</template>

<script setup>
import Icon from './Icon.vue'
defineProps({ kind: { type: String, default: 'good' }, text: { type: String, default: '' } })
</script>
