/** @type {import('next').NextConfig} */

// Where the NestJS API actually runs (server-side only).
// Глобальный префикс бэкенда — /app-api (backend/src/main.ts: setGlobalPrefix).
// 78.17.156.139 — живой IP после миграции; morokvpn.com не используем: домен
// припаркован регистратором (verification-hold → 127.0.0.1), см. docs/RISK_ASSESSMENT_RF.md §9.
const API_ORIGIN = process.env.API_PROXY_ORIGIN ?? 'http://78.17.156.139:3000';

const nextConfig = {
  reactStrictMode: true,

  // Same-origin proxy for the browser.
  //
  // Set NEXT_PUBLIC_API_URL=/api and the admin talks to its own origin, and
  // Next forwards to the backend. That is what makes the panel usable from a
  // remote/preview host, where the visitor's "localhost" is their own machine
  // and not the server. Local dev keeps working unchanged: without that env
  // var the client still calls http://localhost:3000/api directly.
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${API_ORIGIN}/app-api/:path*`,
      },
      {
        // Картинки баннеров. Бэкенд кладёт их в ./uploads и раздаёт как
        // статику СВОИМ процессом, поэтому в базе лежит относительный
        // '/uploads/xxx.png'. Без этого правила <img src='/uploads/…'> в
        // панели означал бы «ищи файл рядом с index.html панели», т.е. 404.
        source: '/uploads/:path*',
        destination: `${API_ORIGIN}/uploads/:path*`,
      },
    ];
  },
};

export default nextConfig;
