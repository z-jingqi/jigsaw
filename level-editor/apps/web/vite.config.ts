import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    proxy: {
      "/api": "http://localhost:8888",
      "/levels": "http://localhost:8888",
      "/assets": "http://localhost:8888",
    },
  },
});
