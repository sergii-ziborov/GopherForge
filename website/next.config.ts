import type { NextConfig } from "next";
const config: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  turbopack: { root: process.cwd() },
  experimental: { cpus: 2 },
  async redirects() {
    const legacy = ["/login", "/register"];
    return [
      ...legacy.map((source) => ({
        source,
        has: [{ type: "query" as const, key: "from", value: "news" }],
        destination: "/news/feed",
        permanent: true,
      })),
      ...legacy.map((source) => ({
        source,
        destination: "/learn",
        permanent: true,
      })),
    ];
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "DENY" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
      {
        source: "/playground",
        headers: [{ key: "Referrer-Policy", value: "no-referrer" }],
      },
      {
        source: "/progress/:path*",
        headers: [
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
        ],
      },
    ];
  },
};
export default config;
