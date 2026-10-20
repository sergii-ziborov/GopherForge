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
};
