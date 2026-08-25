/** @type {import('next').NextConfig} */

// Where the NestJS API actually runs (server-side only).
const API_ORIGIN = process.env.API_PROXY_ORIGIN ?? 'http://localhost:3000';

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
        destination: `${API_ORIGIN}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
