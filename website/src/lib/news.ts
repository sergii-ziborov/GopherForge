import data from "@/content/news.json";
import images from "@/content/news-images.json";
export type News = (typeof data)[number];
export const news = [...data].sort(
  (a, b) => Date.parse(b.eventDate) - Date.parse(a.eventDate),
);
export const newsURL = (slug: string) => `/news/${slug}`;
export const newsImage = (id: string) => images[id as keyof typeof images];
export const dateLabel = (date: string) =>
  new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(date));
export const imageCaption: Record<string, string> = {
  launch:
    "Learn → Try → Check → Continue. Browser and app save progress separately.",
  vscode:
    "Edit → Inspect → Test → Review. Editor assistance still needs engineering judgment.",
  security:
    "Inventory → Rebuild → Test → Rollout. Updating a toolchain does not redeploy binaries.",
  dapr: "Go app → Sidecar → Service. Share one deadline budget, bound retries, use idempotency and measure failures.",
  gopls:
    "Select → Answer → Review → Apply → Test. A recommended workflow, not a universal editor feature.",
  rebuild:
    "Pin inputs → Build twice → Compare → Record. Matching artifacts are evidence, not a complete security audit.",
  http: "Share client → Set deadline → Close body → Trace reuse. HTTP/1 cleanup is bounded; measure the real workload.",
  simd: "Profile → Compare results → Benchmark → Keep fallback. CPU features and workload shape decide the result.",
  alloc:
    "Pin workload → Count allocations → Profile memory → Check latency. Faster allocation does not fix retained objects.",
  leaks:
    "Capture → Find owner → Fix exit → Test shutdown. An empty leak profile is not proof of no leaks.",
};
