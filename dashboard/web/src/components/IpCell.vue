<template>
  <span>
    <button class="ip-link" type="button" @click.stop="open(ip)">{{ ip }}</button>
    <span v-if="banned" class="tag bad">已封禁</span>
    <span v-if="sub" class="sub">{{ sub }}</span>
  </span>
</template>

<script setup>
import { openIp } from '../lib/router.js'
defineProps({ ip: { type: String, required: true }, banned: Boolean, sub: { type: String, default: '' } })
const open = ip => openIp(ip)
</script>
