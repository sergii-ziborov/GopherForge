import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
const read = async (path) =>
  JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
const news = await read("../src/content/news.json");
const images = await read("../src/content/news-images.json");
// Date-only editorial fields use the publication desk's calendar, not UTC midnight.
const editorialToday = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Jerusalem",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
}).format(new Date());
test("the eMudhra report separates event and publication dates and contains 2000 prose words", () => {
  const n = news.find(
    (n) => n.slug === "go-emudhra-urgent-tls-incident-response",
  );
  assert.ok(n);
  assert.equal(n.eventDate, "2026-10-26");
  assert.equal(n.publishedAt, "2026-10-29");
  const prose = n.sections
    .map((s) => s.body)
    .join(" ")
    .replace(/```[\s\S]*?```/g, "");
  assert.ok(prose.split(/\s+/).length >= 2000);
  assert.ok(
    n.sources.some((s) => new URL(s.url).hostname === "blog.mozilla.org"),
  );
  assert.ok(
    n.sources.some((s) => new URL(s.url).hostname === "blog.cloudflare.com"),
  );
  assert.ok(n.sections.some((s) => s.body.includes("```go\n")));
  assert.ok(
    n.sections.some((s) => s.body.includes("/learn/security.tls-trust")),
  );
});
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
      assert.ok(date.slice(0, 10) <= editorialToday, n.slug);
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
test("sync release record separates the public version from the next native update", async () => {
  const r = await read("../src/content/releases.json"),
    c = await read("../src/content/course-version.json");
  assert.equal(c.publicAppVersion, r.public.version);
  assert.equal(
    c.appVersion,
    r.curriculum.version + " — " + r.curriculum.status,
  );
  if (r.next.reviewSubmitted === true) {
    const review = await read(
      `../../docs/releases/${r.next.version}-build${r.next.build}-submission.json`,
    );
    assert.equal(r.next.version, review.version);
    assert.equal(r.next.build, Number(review.build));
    assert.equal(review.releaseType, "AFTER_APPROVAL");
  } else {
    assert.equal(r.next.reviewSubmitted, false);
  }
  const receipt = await read(
    `../../docs/releases/${r.public.version}-build${r.public.build}-release.json`,
  );
  assert.equal(r.public.version, receipt.version);
  assert.equal(r.public.build, Number(receipt.build));
  assert.equal(receipt.state, "READY_FOR_SALE");
  assert.ok(r.next.build > r.public.build);
});

test("October additions fill unused editions without inventing publication dates", async () => {
  const added = news.filter((n) =>
    ["survey", "slices", "buffers", "errors", "gopls24"].includes(
      n.imagePrefix,
    ),
  );
  // Compare this historical edition with the archive that existed at publication.
  const earlier = news.filter((n) => n.publishedAt < "2026-10-23");
  assert.equal(added.length, 5);
  assert.equal(added.filter((n) => n.kind === "news").length, 2);
  assert.equal(added.filter((n) => n.kind === "guide").length, 3);
  const previousLargest = Math.max(...earlier.map((n) => n.wordCount));
  assert.ok(added.every((n) => n.wordCount >= Math.max(2000, previousLargest)));
  assert.deepEqual(added.map((n) => n.editionDate).sort(), [
    "2026-10-15",
    "2026-10-17",
    "2026-10-18",
    "2026-10-22",
    "2026-10-23",
  ]);
  for (const n of added) {
    assert.equal(n.publishedAt, "2026-10-23");
    assert.ok(n.modifiedAt >= n.publishedAt);
    assert.ok(!earlier.some((x) => x.editionDate === n.editionDate));
    const bodies = n.sections.map((s) => s.body).join("\n");
    for (const fence of bodies.matchAll(/```([^\n]*)\n/g))
      assert.ok(["go", "sh", ""].includes(fence[1]));
    for (const match of bodies.matchAll(/\]\((\/[^)#]+)(?:#[^)]*)?\)/g)) {
      const path = match[1].split("?")[0];
      if (path.startsWith("/news/"))
        assert.ok(
          news.some((x) => "/news/" + x.slug === path),
          path,
        );
      if (path.startsWith("/learn/")) {
        const units = await read("../src/content/course.json");
        assert.ok(
          units
            .flatMap((u) => u.lessons)
            .some((l) => "/learn/" + l.id === path),
          path,
        );
      }
      if (path.startsWith("/interview/")) {
        const bank = await read("../src/content/interview.json");
        assert.ok(
          bank.questions.some((q) => "/interview/" + q.id === path),
          path,
        );
      }
    }
  }
});

test("24, 25 and 28 October editions each contain 2000 prose words and three distinct generated assets", async () => {
  const editions = ["2026-10-24", "2026-10-25", "2026-10-28"];
  const posts = news.filter((n) => editions.includes(n.editionDate));
  assert.equal(posts.length, 3);
  assert.equal(new Set(posts.map((n) => n.editionDate)).size, 3);
  const manifest = await read(
    "../../docs/website/archive-20261029/assets.json",
  );
  assert.equal(manifest.assets.length, 9);
  assert.equal(new Set(manifest.assets.map((a) => a.sha256)).size, 9);
  for (const n of posts) {
    assert.equal(n.kind, "guide");
    assert.equal(n.publishedAt, "2026-10-29");
    const prose = n.sections
      .map((s) => s.body)
      .join(" ")
      .replace(/```[\s\S]*?```/g, "");
    assert.ok(prose.split(/\s+/).length >= 2000, n.slug);
    assert.ok(n.sources.length >= 6);
    assert.ok(n.sections.some((s) => s.body.includes("```go\n")));
    assert.ok(n.sections.some((s) => s.body.includes("](/learn/")));
    assert.ok(
      n.sections.some((s) =>
        s.body.includes("/downloads/go-engineering-examples-20261029.zip"),
      ),
    );
    for (const suffix of ["hero", "detail", "infographic"]) {
      const a = manifest.assets.find(
        (a) => a.id === `${n.imagePrefix}-${suffix}`,
      );
      assert.ok(a);
      assert.equal(a.mode, "built-in image_gen");
      assert.equal(images[a.id].width, a.width);
    }
  }
});
