/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  test: {
    // Almost everything worth testing here is a pure function of state, so the
    // default environment is Node and only the files that touch the DOM pay for
    // jsdom -- they opt in with `@vitest-environment jsdom` at the top.
    environment: 'node',
    include: ['src/**/*.test.{ts,tsx}'],
  },
})
