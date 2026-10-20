import type { MetadataRoute } from "next";
import { lessons } from "@/lib/course";
import { interview, interviewURL } from "@/lib/interview";
import { posts } from "@/lib/posts";
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    "",
    "/learn",
    "/interview",
    ...interview.questions.map((q) => interviewURL(q.id)),
    "/architectures",
    "/blog",
    "/updates",
    "/support",
    "/privacy",
    "/terms",
    ...lessons.map((l) => `/learn/${l.id}`),
    ...posts.map((p) => `/blog/${p.slug}`),
  ].map((path) => ({
    url: `https://gopherforge.app${path}`,
    changeFrequency: "monthly" as const,
    priority: path === "" ? 1 : path.startsWith("/learn") ? 0.8 : 0.6,
  }));
}
