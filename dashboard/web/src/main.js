import { createApp } from 'vue'
import App from './App.vue'
import './styles.css'
import { BASE } from './lib/api.js'
import { initTheme } from './lib/theme.js'
import { initRouter } from './lib/router.js'

const icon = document.createElement('link')
icon.rel = 'icon'
icon.type = 'image/svg+xml'
icon.href = BASE + '/static/favicon.svg'
document.head.appendChild(icon)

async function boot() {
  await initTheme()
  initRouter()
  createApp(App).mount('#app')
}

boot().catch(error => {
  console.error(error)
  document.getElementById('app').textContent = '页面加载失败，请刷新重试。'
})
