import type { MetadataRoute } from "next";
import { lessons, units } from "@/lib/course";
import { interview, interviewURL } from "@/lib/interview";
import { posts } from "@/lib/posts";
import { news, newsURL, newsImage } from "@/lib/news";
export default function sitemap(): MetadataRoute.Sitemap {
  const origin = "https://gopherforge.app";
  const paths = [
    "",
    "/learn",
    "/interview",
    "/architectures",
    "/blog",
    "/updates",
    "/support",
    "/privacy",
    "/terms",
    "/news",
    "/news/feed",
    ...interview.questions.map((q) => interviewURL(q.id)),
    ...lessons.map((l) => `/learn/${l.id}`),
    ...units.map((u) => `/learn/units/${u.id}`),
  ];
  return [
    ...paths.map((path) => ({
      url: origin + path,
      ...(["/", "/learn", "/updates", "/support", "/news"].includes(
        path || "/",
      ) ||
      path.startsWith("/learn/") ||
      path.startsWith("/interview")
        ? { lastModified: "2026-10-20" }
        : {}),
      changeFrequency:
        path === "/news/feed" ? ("daily" as const) : ("monthly" as const),
      priority: path === "" ? 1 : path.startsWith("/learn") ? 0.8 : 0.6,
    })),
    ...posts.map((p) => ({
      url: origin + `/blog/${p.slug}`,
      lastModified: p.date,
      changeFrequency: "monthly" as const,
      priority: 0.6,
    })),
    ...news.map((n) => ({
      url: origin + newsURL(n.slug),
      lastModified: n.modifiedAt,
      images: ["hero", "detail", "infographic"].map(
        (s) => origin + newsImage(n.imagePrefix + "-" + s).src,
      ),
      changeFrequency: "monthly" as const,
      priority: 0.8,
    })),
  ];
}
