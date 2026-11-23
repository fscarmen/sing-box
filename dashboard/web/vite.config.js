import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Relative base: the bundle works under any configured base path (site.base_path).
export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    outDir: '../static/app',
    emptyOutDir: true,
    assetsDir: 'assets',
    chunkSizeWarningLimit: 1200,
    modulePreload: { polyfill: false },
  },
})
