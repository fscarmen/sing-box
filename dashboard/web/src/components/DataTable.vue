<template>
  <div>
    <div class="table-wrap" :class="{ scroll: maxHeight }" :style="maxHeight ? { maxHeight } : null">
      <table class="data">
        <thead>
          <tr>
            <th v-for="c in columns" :key="c.key" :class="[c.align === 'right' ? 'right' : '', sortKey === c.key ? 'sorted' : '']"
                :aria-sort="sortKey === c.key ? (sortDir === 'asc' ? 'ascending' : 'descending') : 'none'">
              <button v-if="c.sortable !== false" type="button" @click="toggle(c.key)">{{ c.label }}<span aria-hidden="true">{{ sortKey === c.key ? (sortDir === 'asc' ? '↑' : '↓') : '' }}</span></button>
              <span v-else>{{ c.label }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, i) in visible" :key="rowKey ? row[rowKey] : i">
            <td v-for="c in columns" :key="c.key" :class="[c.align === 'right' ? 'right' : '', c.class || '']" :title="c.title ? String(row[c.key] ?? '') : null">
              <slot :name="'cell-' + c.key" :row="row" :value="row[c.key]">{{ c.format ? c.format(row[c.key], row) : (row[c.key] ?? '—') }}</slot>
            </td>
          </tr>
          <tr v-if="!visible.length"><td class="empty" :colspan="columns.length">{{ loading ? '加载中…' : empty }}</td></tr>
        </tbody>
      </table>
    </div>
    <div v-if="!hideFoot" class="table-foot">
      <span>{{ footText }}</span>
      <div v-if="pages > 1" class="pager">
        <button class="btn sm" type="button" :disabled="page <= 1" @click="setPage(page - 1)">上一页</button>
        <span class="num">{{ page }} / {{ pages }}</span>
        <button class="btn sm" type="button" :disabled="page >= pages" @click="setPage(page + 1)">下一页</button>
      </div>
      <slot name="foot" />
    </div>
  </div>
</template>

<script setup>
// Client mode sorts/pages locally; server mode (total set) only emits sort/page changes.
import { computed, ref, watch } from 'vue'

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, default: () => [] },
  rowKey: { type: String, default: '' },
  total: { type: Number, default: null },
  pageSize: { type: Number, default: 50 },
  sort: { type: String, default: '' },
  dir: { type: String, default: 'desc' },
  query: { type: String, default: '' },
  searchKeys: { type: Array, default: null },
  empty: { type: String, default: '暂无记录' },
  loading: Boolean,
  hideFoot: Boolean,
  maxHeight: { type: String, default: '' },
  note: { type: String, default: '' },
})
const emit = defineEmits(['sort', 'page'])
const sortKey = ref(props.sort)
const sortDir = ref(props.dir)
const page = ref(1)
const server = computed(() => props.total !== null)

watch(() => props.query, () => { page.value = 1 })
watch(() => props.sort, v => { sortKey.value = v })
watch(() => props.dir, v => { sortDir.value = v })

function toggle(key) {
  if (sortKey.value === key) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = key; sortDir.value = 'desc' }
  page.value = 1
  emit('sort', { key: sortKey.value, dir: sortDir.value })
}

const filtered = computed(() => {
  if (server.value) return props.rows
  const term = props.query.trim().toLowerCase()
  let rows = props.rows
  if (term) {
    rows = rows.filter(r => (props.searchKeys || Object.keys(r)).some(k => String(r[k] ?? '').toLowerCase().includes(term)))
  }
  if (sortKey.value) {
    const k = sortKey.value
    const d = sortDir.value === 'asc' ? 1 : -1
    rows = [...rows].sort((a, b) => {
      const x = a[k] ?? '', y = b[k] ?? ''
      return (typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y), 'zh-CN', { numeric: true })) * d
    })
  }
  return rows
})
const count = computed(() => server.value ? props.total : filtered.value.length)
const pages = computed(() => Math.max(1, Math.ceil(count.value / props.pageSize)))
const visible = computed(() => server.value ? props.rows : filtered.value.slice((page.value - 1) * props.pageSize, page.value * props.pageSize))
const footText = computed(() => (props.note ? props.note + ' · ' : '') + '共 ' + count.value.toLocaleString('zh-CN') + ' 条')

function setPage(p) {
  page.value = Math.min(Math.max(1, p), pages.value)
  if (server.value) emit('page', { page: page.value, offset: (page.value - 1) * props.pageSize })
}
defineExpose({ reset: () => { page.value = 1 } })
</script>
