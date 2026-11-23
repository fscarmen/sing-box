// ECharts, tree-shaken to the parts the panel uses, plus shared option builders.
import * as echarts from 'echarts/core'
import { LineChart, BarChart, SankeyChart, ScatterChart, EffectScatterChart, LinesChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent, GeoComponent, DataZoomComponent, MarkLineComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { esc } from './format.js'

echarts.use([LineChart, BarChart, SankeyChart, ScatterChart, EffectScatterChart, LinesChart, GridComponent, TooltipComponent,
  LegendComponent, GeoComponent, DataZoomComponent, MarkLineComponent, CanvasRenderer])

export { echarts }

// Categorical color follows the entity's position in a stable list (config order), never its rank.
export function colorFor(tokens, list, key) {
  const i = list.indexOf(key)
  if (i < 0 || i >= 8) return tokens.muted
  return tokens.series[i]
}

// Tooltip markup uses classes and SVG presentation attributes only (strict CSP: no inline styles).
export function dot(color) {
  return '<svg class="tip-dot" width="10" height="10" viewBox="0 0 10 10" aria-hidden="true"><circle cx="5" cy="5" r="4" fill="' + esc(color) + '"/></svg>'
}

export function tipRows(title, rows) {
  return '<div class="tip-title">' + esc(title) + '</div>' + rows.map(r =>
    '<div class="tip-row">' + (r.color ? dot(r.color) : '') + '<span class="tip-name">' + esc(r.name) + '</span><b class="tip-value">' + esc(r.value) + '</b></div>'
  ).join('')
}

export function tooltipBase(tokens, extra = {}) {
  return {
    className: 'viz-tip',
    backgroundColor: tokens.surface,
    borderColor: tokens.border || tokens.grid,
    borderWidth: 1,
    padding: [8, 10],
    textStyle: { color: tokens.ink, fontSize: 12 },
    confine: true,
    ...extra,
  }
}

export function axisBase(tokens) {
  return {
    axisLine: { lineStyle: { color: tokens.axis } },
    axisTick: { show: false },
    axisLabel: { color: tokens.muted, fontSize: 11 },
    splitLine: { lineStyle: { color: tokens.grid, width: 1 } },
  }
}

export function legendBase(tokens, extra = {}) {
  return { top: 0, right: 0, icon: 'roundRect', itemWidth: 10, itemHeight: 10, itemGap: 14, textStyle: { color: tokens.ink2, fontSize: 12 }, ...extra }
}
