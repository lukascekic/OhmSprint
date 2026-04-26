// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  outDir: '../data',
  build: { assets: 'static' },
  server: { port: 4321 }
});