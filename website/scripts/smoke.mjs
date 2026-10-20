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
const paths = [
  "/",
  "/learn",
  "/interview",
  ...interview.questions.map((q) => `/interview/${q.id}`),
  "/architectures",
  "/blog",
  "/updates",
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
const broken = [];
for (const [path, text] of html)
  for (const m of text.matchAll(/href="(\/[^"<>]*)"/g)) {
    const url = new URL(m[1].replaceAll("&amp;", "&"), base);
    if (
      url.pathname.startsWith("/_next/") ||
      url.pathname.startsWith("/images/") ||
      /\.(svg|png|xml|ico)$/.test(url.pathname) ||
      url.pathname.includes("opengraph-image")
    )
      continue;
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
const missing = await fetch(base + "/learn/not-a-real-lesson");
assert.equal(missing.status, 404);
const health = await fetch(base + "/api/health");
assert.equal(health.status, 200);
assert.equal((await health.json()).status, "ok");
const sitemap = await fetch(base + "/sitemap.xml");
assert.equal(sitemap.status, 200);
assert.ok((await sitemap.text()).includes("/learn/architecture.cqrs"));
const result = {
  pages: html.size,
  internalLinksAndAnchors: "passed",
  unknownLesson: 404,
  health: "passed",
  sitemap: "passed",
  checkedAt: new Date().toISOString(),
};
if (process.env.REPORT_PATH)
  await writeFile(
    process.env.REPORT_PATH,
    JSON.stringify(result, null, 2) + "\n",
  );
console.log(JSON.stringify(result, null, 2));
