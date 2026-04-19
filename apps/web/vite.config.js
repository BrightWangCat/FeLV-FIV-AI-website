import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
// 仓库根目录,用于把 monorepo 顶层 shared/ 暴露给本应用
const repoRoot = path.resolve(__dirname, '../..')

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@shared': path.resolve(repoRoot, 'shared'),
    },
  },
  server: {
    fs: {
      // 允许 Vite 读取项目根之外的共享资源目录
      allow: [path.resolve(__dirname), path.resolve(repoRoot, 'shared')],
    },
  },
})
