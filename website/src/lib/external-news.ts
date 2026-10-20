import { cache } from "react";
import { readFile } from "node:fs/promises";
import seed from "@/content/external-news.json";
export type ExternalEntry = (typeof seed.entries)[number];
export type ExternalFeed = typeof seed & {
  cacheStatus?: "live" | "fallback";
  refreshFailed?: boolean;
};
export const externalFeed = cache(async (): Promise<ExternalFeed> => {
  try {
    const root =
      process.env.GOPHERFORGE_FEED_DIR ?? "/tmp/gopherforge-news-feed";
    const raw = await readFile(root + "/feed.json", "utf8");
    if (raw.length > 12 * 1024 * 1024) throw Error("Cache exceeds limit");
    const feed = JSON.parse(raw) as ExternalFeed;
    if (
      feed.schema !== 1 ||
      !Array.isArray(feed.entries) ||
      feed.entries.length > 100
    )
      throw Error("Invalid cache");
    if (
      !feed.entries.every(
        (e) =>
          /^[a-f0-9]{16}$/.test(e.id) &&
          new URL(e.sourceURL).hostname === "go.dev" &&
          Array.isArray(e.blocks),
      )
    )
      throw Error("Invalid source");
    let refreshFailed = false;
    try {
      const status = JSON.parse(await readFile(root + "/status.json", "utf8"));
      refreshFailed = status.ok === false;
    } catch {}
    return { ...feed, cacheStatus: "live", refreshFailed };
  } catch {
    return { ...seed, cacheStatus: "fallback" };
  }
});
