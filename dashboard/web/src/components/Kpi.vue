<template>
  <section class="card kpi" :aria-label="label">
    <span class="k-label"><slot name="icon" />{{ label }}</span>
    <span class="k-value num">{{ value }}</span>
    <span class="k-sub"><slot /></span>
    <div v-if="$slots.spark" class="k-spark"><slot name="spark" /></div>
  </section>
</template>

<script setup>
defineProps({ label: { type: String, required: true }, value: { type: String, default: '—' } })
</script>
