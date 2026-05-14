import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        paper: "#fffaf0",
        linen: "#e8e2d8",
        ink: "#2d241b",
        muted: "#75685c",
        clay: "#bf7430",
        moss: "#3f7f72",
      },
    },
  },
  plugins: [],
} satisfies Config;
