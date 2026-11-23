<template>
  <div ref="el" class="chart" :style="{ height }" role="img" :aria-label="label"></div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { echarts } from '../lib/charts.js'

const props = defineProps({
  option: { type: Object, required: true },
  height: { type: String, default: '260px' },
  label: { type: String, default: '图表' },
  replace: { type: Boolean, default: false },
})
const emit = defineEmits(['chart-click'])
const el = ref(null)
let chart = null
let observer = null

onMounted(() => {
  chart = echarts.init(el.value, null, { renderer: 'canvas' })
  chart.setOption(props.option, true)
  chart.on('click', p => emit('chart-click', p))
  observer = new ResizeObserver(() => chart && chart.resize())
  observer.observe(el.value)
})

watch(() => props.option, option => {
  if (chart) chart.setOption(option, { notMerge: props.replace, lazyUpdate: true })
})

onBeforeUnmount(() => {
  observer && observer.disconnect()
  chart && chart.dispose()
  chart = null
})

defineExpose({ instance: () => chart })
</script>
