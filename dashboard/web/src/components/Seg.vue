<template>
  <div class="seg" role="group" :aria-label="label">
    <button v-for="o in options" :key="o.value" type="button" :class="{ on: o.value === modelValue }" :aria-pressed="o.value === modelValue" @click="$emit('update:modelValue', o.value)">{{ o.label }}</button>
  </div>
</template>

<script setup>
defineProps({ modelValue: { type: [String, Number, Boolean], default: '' }, options: { type: Array, required: true }, label: { type: String, default: '' } })
defineEmits(['update:modelValue'])
</script>
