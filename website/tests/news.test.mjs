import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
const read = async (path) =>
  JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
const news = await read("../src/content/news.json");
const images = await read("../src/content/news-images.json");
test("substantive original articles have sources, interlinks and three generated assets each", async () => {
  assert.ok(news.length >= 10);
  assert.equal(new Set(news.map((n) => n.slug)).size, news.length);
  for (const n of news) {
    const prose = n.sections
      .map((s) => s.title + " " + s.body)
      .join(" ")
      .replace(/```[\s\S]*?```/g, "");
    assert.ok(prose.split(/\s+/).length >= 1500, n.slug);
    assert.ok(n.sources.length >= 3);
    assert.ok(n.sources.every((s) => new URL(s.url).protocol === "https:"));
    assert.ok(n.related.every((slug) => news.some((x) => x.slug === slug)));
    assert.equal(new Set(n.sections.map((s) => s.id)).size, n.sections.length);
    for (const date of [
      n.eventDate,
      n.publishedAt,
      n.modifiedAt,
      n.sourceCheckedAt,
    ]) {
      assert.ok(Number.isFinite(Date.parse(date)), n.slug);
      assert.ok(Date.parse(date) <= Date.now(), n.slug);
    }
    assert.ok(n.eventDate <= n.publishedAt, n.slug);
    assert.ok(n.publishedAt <= n.modifiedAt, n.slug);
    assert.ok(n.sourceCheckedAt <= n.modifiedAt, n.slug);
    assert.ok(n.keywords.length >= 2, n.slug);
    for (const suffix of ["hero", "detail", "infographic"]) {
      const im = images[n.imagePrefix + "-" + suffix];
      assert.ok(im.width >= 1000);
      assert.ok(
        (await stat(new URL("../public" + im.src, import.meta.url))).size >
          10000,
      );
    }
  }
});
test("the new edition puts today’s report first and four historical events before the launch", () => {
  const added = news.filter((n) =>
    ["rebuild", "http", "simd", "alloc", "leaks"].includes(n.imagePrefix),
  );
  assert.equal(added.length, 5);
  assert.ok(added.every((n) => n.publishedAt === "2026-10-21"));
  assert.equal(
    added.find((n) => n.imagePrefix === "rebuild").eventDate,
    "2026-10-21",
  );
  const launch = news.find((n) => n.imagePrefix === "launch");
  assert.equal(added.filter((n) => n.eventDate < launch.eventDate).length, 4);
  assert.equal(launch.publishedAt, "2026-10-20");
});
test("full external seed carries attribution, code and publication dates without active HTML", async () => {
  const f = await read("../src/content/external-news.json");
  assert.equal(f.entries.length, 10);
  assert.ok(f.entries.some((e) => e.wordCount > 4000));
  for (const e of f.entries) {
    assert.equal(new URL(e.sourceURL).hostname, "go.dev");
    assert.equal(e.license, "CC BY 4.0");
    assert.ok(e.author);
    assert.ok(e.blocks.length > 5);
    assert.ok(Number.isFinite(Date.parse(e.publishedAt)));
    assert.ok(
      e.blocks.every((b) => ["p", "pre", "h2", "h3", "li"].includes(b.kind)),
    );
  }
});
test("sync release record matches reviewed native release receipts", async () => {
  const r = await read("../src/content/releases.json"),
    c = await read("../src/content/course-version.json");
  assert.equal(c.publicAppVersion, r.public.version);
  assert.equal(c.appVersion, r.next.version + " TestFlight");
  assert.equal(r.public.version, "1.1.4");
  const receipt = await read("../../docs/releases/1.1.5-submission.json");
  assert.equal(r.next.version, receipt.version);
  assert.equal(r.next.build, Number(receipt.build));
});
