import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import ViteRuby from 'vite-plugin-ruby'
import ui from '@nuxt/ui/vite'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [
    vue(),
    ViteRuby(),
    ui({
      inertia: true,
      ui: {
        colors: {
          primary: 'blue',
          neutral: 'slate',
        },
      },
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/javascript', import.meta.url)),
    },
  },
})
