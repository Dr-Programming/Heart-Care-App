import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// In dev, /api is proxied to the Monitoring API so the browser sees one origin, the same as the
// nginx setup in Docker. Override the target with VITE_PROXY_TARGET if it runs elsewhere.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5175,
    proxy: {
      '/api': process.env.VITE_PROXY_TARGET ?? 'http://localhost:8090',
    },
  },
})
