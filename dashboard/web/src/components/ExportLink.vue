<template>
  <a class="btn sm" :href="exportUrl(kind, params)"><Icon name="download" :size="14" /><slot>CSV</slot></a>
</template>

<script setup>
import Icon from './Icon.vue'
import { exportUrl } from '../lib/api.js'

defineProps({ kind: { type: String, required: true }, params: { type: Object, default: () => ({}) } })
</script>
