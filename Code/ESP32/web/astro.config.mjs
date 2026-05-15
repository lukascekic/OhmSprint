// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  outDir: '../data',
  build: { assets: 'static' },
  server: { port: 4321 },

  vite: {
    plugins: [tailwindcss()]
  }
});