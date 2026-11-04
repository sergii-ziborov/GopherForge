import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { createHash } from "node:crypto";
import {
  newsDetailSection,
  newsExtraFigures,
} from "../src/lib/news-image-layout.ts";
const json = async (path) =>
  JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
const news = await json("../src/content/news.json");
const prefixes = [
  "genericfit",
  "embedsite",
  "cacheflight",
  "mongocursor",
  "traceflow",
  "fuzzcraft",
];
const added = news.filter((n) => prefixes.includes(n.imagePrefix));

test("six November editions fill the calendar with 2000-word sourced guides and valid interlinks", async () => {
  assert.equal(added.length, 6);
  assert.deepEqual(added.map((n) => n.editionDate).sort(), [
    "2026-10-30",
    "2026-10-31",
    "2026-11-01",
    "2026-11-02",
    "2026-11-03",
    "2026-11-04",
  ]);
  const lessons = (await json("../src/content/course.json")).flatMap(
    (u) => u.lessons,
  );
  const questions = (await json("../src/content/interview.json")).questions;
  const posts = await json("../src/content/posts.json");
  for (const n of added) {
    assert.equal(n.kind, "guide");
    assert.equal(n.publishedAt, "2026-11-04");
    assert.equal(n.sourceCheckedAt, "2026-11-04");
    assert.ok(n.sections.every((s) => s.body.length > 100));
    const body = n.sections.map((s) => s.body).join("\n");
    const prose = body
      .replace(/```[\s\S]*?```/g, "")
      .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
    assert.ok(prose.split(/\s+/).filter(Boolean).length >= 2000, n.slug);
    assert.ok(n.sources.length >= 3);
    assert.ok(body.includes("/downloads/go-engineering-lab-20261104.zip"));
    for (const m of body.matchAll(
      /\]\((\/(?:learn|interview|news|blog)\/[^)#]+)(?:#[^)]*)?\)/g,
    )) {
      const [kind, id] = m[1].slice(1).split("/");
      assert.ok(
        kind === "learn"
          ? lessons.some((l) => l.id === id)
          : kind === "interview"
            ? questions.some((q) => q.id === id)
            : kind === "blog"
              ? posts.some((p) => p.slug === id)
              : news.some((n) => n.slug === id),
        m[1],
      );
    }
    for (const slug of n.related)
      assert.ok(news.find((x) => x.slug === slug).related.includes(n.slug));
    if (newsDetailSection[n.imagePrefix])
      assert.ok(
        n.sections.some((s) => s.id === newsDetailSection[n.imagePrefix]),
      );
    for (const figure of newsExtraFigures[n.imagePrefix] ?? [])
      assert.ok(n.sections.some((s) => s.id === figure.afterSection));
  }
});

test("the six editions have eighteen real distinct images and bounded experimental evidence", async () => {
  const manifest = await json(
    "../../docs/website/november-20261104/assets.json",
  );
  const images = await json("../src/content/news-images.json");
  assert.equal(manifest.assets.length, 18);
  assert.equal(new Set(manifest.assets.map((a) => a.sha256)).size, 18);
  for (const n of added)
    for (const suffix of ["hero", "infographic", "detail"]) {
      const a = manifest.assets.find(
        (a) => a.id === n.imagePrefix + "-" + suffix,
      );
      assert.equal(a.mode, "built-in image_gen");
      assert.ok(a.prompt.length > 100);
      assert.ok(images[a.id].alt.length > 30);
      const path = new URL("../public" + a.src, import.meta.url);
      assert.ok((await stat(path)).size > 10000);
      assert.equal(
        createHash("sha256")
          .update(await readFile(path))
          .digest("hex"),
        a.sha256,
      );
    }
  const controls = await json(
    "../../docs/website/november-20261104/negative-controls.json",
  );
  assert.equal(controls.length, 6);
  assert.ok(controls.every((c) => c.expectedFailure));
});
