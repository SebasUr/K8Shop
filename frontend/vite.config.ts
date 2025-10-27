import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react()],
    define: {
      __APP_CONFIG__: JSON.stringify({
        catalogApi: env.VITE_CATALOG_API ?? "",
        cartApi: env.VITE_CART_API ?? "",
        orderApi: env.VITE_ORDER_API ?? "",
      }),
    },
    server: {
      port: 5173,
      host: "0.0.0.0",
    },
  };
});
