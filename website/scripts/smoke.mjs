import { newsPageCount, newsPageURL } from "../src/lib/news-pagination.ts";
import { readFile, writeFile } from "node:fs/promises";
import assert from "node:assert/strict";
const base = process.env.SITE_URL ?? "http://127.0.0.1:3047";
for (let attempt = 0; ; attempt++) {
  try {
    const health = await fetch(base + "/api/health", {
      signal: AbortSignal.timeout(1500),
    });
    if (health.ok) break;
  } catch {
    // A newly started container may not have bound its socket yet.
  }
  if (attempt >= 19) throw new Error("Preview did not become healthy");
  await new Promise((resolve) => setTimeout(resolve, 250));
}
const course = JSON.parse(
  await readFile(
    new URL("../src/content/course.json", import.meta.url),
    "utf8",
  ),
);
const posts = JSON.parse(
  await readFile(new URL("../src/content/posts.json", import.meta.url), "utf8"),
);
const interview = JSON.parse(
  await readFile(
    new URL("../src/content/interview.json", import.meta.url),
    "utf8",
  ),
);
const news = JSON.parse(
  await readFile(new URL("../src/content/news.json", import.meta.url), "utf8"),
);
const feed = JSON.parse(
  await readFile(
    new URL("../src/content/external-news.json", import.meta.url),
    "utf8",
  ),
);
const paths = [
  "/news",
  "/news/feed",
  "/register",
  "/login",
  ...news.map((n) => `/news/${n.slug}`),
  ...feed.entries.map((e) => `/news/feed/${e.id}`),
  ...course.map((u) => `/learn/units/${u.id}`),
  "/",
  "/learn",
  "/interview",
  ...interview.questions.map((q) => `/interview/${q.id}`),
  "/architectures",
  "/blog",
  "/updates",
  "/guide",
  "/downloads",
  "/guide/mcp",
  "/playground",
  ...Array.from({ length: newsPageCount(news.length) }, (_, i) =>
    newsPageURL(i + 1),
  ),
  "/support",
  "/privacy",
  "/terms",
  ...course.flatMap((u) => u.lessons.map((l) => `/learn/${l.id}`)),
  ...posts.map((p) => `/blog/${p.slug}`),
];
const html = new Map();
let cursor = 0;
async function worker() {
  while (cursor < paths.length) {
    const path = paths[cursor++];
    const r = await fetch(base + path);
    assert.equal(r.status, 200, path);
    assert.equal(r.headers.get("x-content-type-options"), "nosniff", path);
    const text = await r.text();
    assert.match(text, /<h1[ >]/, path);
    assert.match(text, /<title>/, path);
    html.set(path, text);
  }
}
await Promise.all(Array.from({ length: 4 }, worker));
// The live community feed can advance beyond the bundled seed between releases.
// Resolve those links as real pages before checking the complete internal graph.
const liveFeedRoutes = new Set(
  [
    ...(html.get("/news/feed") ?? "").matchAll(
      /href="(\/news\/feed\/[a-f0-9]{16})"/g,
    ),
  ].map((match) => match[1]),
);
for (const path of liveFeedRoutes) {
  if (html.has(path)) continue;
  const response = await fetch(base + path);
  assert.equal(response.status, 200, path);
  assert.equal(response.headers.get("x-content-type-options"), "nosniff", path);
  const text = await response.text();
  assert.match(text, /<h1[ >]/, path);
  html.set(path, text);
}

const broken = [];
const downloads = new Set();
for (const [path, text] of html)
  for (const m of text.matchAll(/href="(\/[^"<>]*)"/g)) {
    const url = new URL(m[1].replaceAll("&amp;", "&"), base);
    if (
      url.pathname.startsWith("/_next/") ||
      url.pathname.startsWith("/images/") ||
      url.pathname.startsWith("/licenses/") ||
      /\.(svg|png|xml|ico)$/.test(url.pathname) ||
      url.pathname.includes("opengraph-image")
    )
      continue;
    if (url.pathname.startsWith("/downloads/")) {
      downloads.add(url.pathname);
      continue;
    }
    if (!html.has(url.pathname)) broken.push({ from: path, to: url.pathname });
    else if (
      url.hash &&
      !new RegExp(
        `id="${url.hash.slice(1).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`,
      ).test(html.get(url.pathname))
    )
      broken.push({ from: path, to: url.pathname + url.hash });
  }
assert.deepEqual(broken, [], "Internal routes and anchors");
for (const path of downloads)
  assert.equal((await fetch(base + path)).status, 200, path);
const missing = await fetch(base + "/learn/not-a-real-lesson");
assert.equal(missing.status, 404);
const health = await fetch(base + "/api/health");
assert.equal(health.status, 200);
assert.equal((await health.json()).status, "ok");
const sitemap = await fetch(base + "/sitemap.xml");
assert.equal(sitemap.status, 200);
assert.ok((await sitemap.text()).includes("/learn/architecture.cqrs"));
const sitemapText = await (await fetch(base + "/sitemap.xml")).text();
for (const n of news) {
  const path = `/news/${n.slug}`,
    text = html.get(path);
  assert.ok(text.includes("application/ld+json"), path);
  assert.ok(
    text.includes(n.kind === "guide" ? "TechArticle" : "NewsArticle"),
    path,
  );
  assert.ok(
    text.includes('rel="canonical" href="https://gopherforge.app' + path + '"'),
    path,
  );
  assert.ok(sitemapText.includes(path), path);
  for (const suffix of ["hero", "detail", "infographic"]) {
    const im = await fetch(
      base + `/images/news/${n.imagePrefix}-${suffix}.webp`,
    );
    assert.equal(im.status, 200);
    assert.ok(im.headers.get("content-type")?.includes("image/webp"));
  }
}
for (const u of course) {
  assert.ok(sitemapText.includes(`/learn/units/${u.id}`));
}
assert.ok(!sitemapText.includes("/register"));
assert.ok(!sitemapText.includes("/login"));
assert.ok(!sitemapText.includes("/news/feed/" + feed.entries[0].id));
for (const e of feed.entries) {
  const text = html.get("/news/feed/" + e.id);
  assert.ok(text.includes("noindex"));
  assert.ok(text.includes('href="' + e.sourceURL + '"'));
  assert.ok(text.includes("Creative Commons Attribution 4.0"));
}
for (const path of ["/register", "/login"]) {
  const redirect = await fetch(base + path, { redirect: "manual" });
  assert.equal(redirect.status, 308);
  assert.equal(
    new URL(redirect.headers.get("location"), base).pathname,
    "/learn",
  );
}
const home = html.get("/").replace(/<!--.*?-->/g, "");
assert.match(home, /<del[^>]*>\$9\.99<\/del>/);
assert.match(home, /Sale price[^>]*>\$6\.99 USD/);
assert.ok(html.get("/updates").includes("1.1.5"));
assert.ok(html.get("/guide").includes("/learn/ai.go-workflow"));
assert.ok(html.get("/learn/core.zero-values").includes("LearningResource"));
const rss = await fetch(base + "/news/rss.xml");
assert.equal(rss.status, 200);
assert.match(rss.headers.get("content-type"), /rss/);
assert.equal(((await rss.text()).match(/<item>/g) || []).length, news.length);
const license = await fetch(base + "/licenses/go-code.txt");
assert.equal(license.status, 200);
const licenseText = await license.text();
assert.ok(licenseText.startsWith("Copyright 2009 The Go Authors."));
assert.ok(licenseText.includes("THIS SOFTWARE IS PROVIDED"));
const result = {
  pages: html.size,
  internalLinksAndAnchors: "passed",
  unknownLesson: 404,
  health: "passed",
  sitemap: "passed",
  newsAssetsAndSchema: "passed",
  fullExternalAttributionAndCanonical: "passed",
  legacyAccountRedirects: "passed",
  releasePricingAndAgentLinks: "passed",
  rssItems: news.length,
  checkedAt: new Date().toISOString(),
};
if (process.env.REPORT_PATH)
  await writeFile(
    process.env.REPORT_PATH,
    JSON.stringify(result, null, 2) + "\n",
  );
console.log(JSON.stringify(result, null, 2));
