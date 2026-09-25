import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'path'

export default defineConfig(({ command }) => {
  if (command === 'build' && process.env.ALLOW_EMBEDDED_API_KEYS !== '1') {
    const embeddedKeys = Object.entries(process.env).filter(([name, value]) =>
      /^VITE_USER_\d+_API_KEY$/.test(name) &&
      typeof value === 'string' && value.trim().length > 0 &&
      !/^(anything|your-api-key|<.*>)$/i.test(value.trim()),
    )
    if (embeddedKeys.length) {
      throw new Error('Refusing to embed Immich API keys in a production browser bundle. Use the local proxy or explicitly set ALLOW_EMBEDDED_API_KEYS=1 for a private build.')
    }
  }
  return {
  // Relative asset paths so the packaged Electron app can load from file://
  base: './',
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 5173,
    host: true,
  },
  }
})
