import type { MetadataRoute } from "next";
import { lessons, units } from "@/lib/course";
import { interview, interviewURL } from "@/lib/interview";
import { posts } from "@/lib/posts";
import { news, newsURL, newsImage } from "@/lib/news";
import {
  curriculumUpdatedOn,
  lessonUpdatedOn,
  changedUnits,
  changedInterview,
} from "@/lib/curriculum-revision";
export default function sitemap(): MetadataRoute.Sitemap {
  const origin = "https://gopherforge.app";
  const illustratedPages: Record<string, string[]> = {
    "": ["slices-hero", "gopls24-detail", "rebuild-hero"],
    "/learn": ["launch-hero"],
    "/interview": ["survey-detail"],
    "/architectures": ["dapr-hero"],
  };
  const paths = [
    "",
    "/learn",
    "/interview",
    "/architectures",
    "/blog",
    "/updates",
    "/guide",
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
      lastModified:
        path === "/news"
          ? news[0].modifiedAt
          : [
                "",
                "/guide",
                "/learn",
                "/interview",
                "/updates",
                "/support",
              ].includes(path)
            ? curriculumUpdatedOn
            : path.startsWith("/learn/units/")
              ? changedUnits.has(path.split("/").pop()!)
                ? curriculumUpdatedOn
                : "2026-10-23"
              : path.startsWith("/learn/")
                ? lessonUpdatedOn(path.slice(7))
                : path.startsWith("/interview/")
                  ? changedInterview.has(decodeURIComponent(path.slice(11)))
                    ? curriculumUpdatedOn
                    : "2026-10-20"
                  : "2026-10-25",
      ...(path === "/guide"
        ? {
            images: [
              origin + "/images/app-icon.png",
              origin + "/images/workbench.png",
            ],
          }
        : illustratedPages[path]
          ? {
              images: illustratedPages[path].map(
                (id) => origin + newsImage(id).src,
              ),
            }
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
