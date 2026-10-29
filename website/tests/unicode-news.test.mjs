import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { createHash } from "node:crypto";
import {
  newsExtraFigures,
  newsImageSuffixes,
  newsDetailSection,
} from "../src/lib/news-image-layout.ts";
const json = async (path) =>
  JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
const news = await json("../src/content/news.json");
const article = news.find((n) => n.imagePrefix === "unicodefield");

test("8 October Unicode guide has 4000 prose words, valid interlinks and truthful implementation scope", async () => {
  assert.ok(article);
  assert.equal(article.editionDate, "2026-10-08");
  assert.equal(article.publishedAt, "2026-10-29");
  assert.equal(article.kind, "guide");
  const body = article.sections.map((s) => s.body).join("\n");
  const prose = body
    .replace(/```[\s\S]*?```/g, "")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
  assert.ok(prose.split(/\s+/).filter(Boolean).length >= 4000);
  assert.ok(article.sources.length >= 10);
  const lessons = (await json("../src/content/course.json")).flatMap(
    (u) => u.lessons,
  );
  const questions = (await json("../src/content/interview.json")).questions;
  for (const m of body.matchAll(
    /\]\((\/(?:learn|interview|news)\/[^)#]+)(?:#[^)]*)?\)/g,
  )) {
    const [kind, id] = m[1].slice(1).split("/");
    assert.ok(
      kind === "learn"
        ? lessons.some((l) => l.id === id)
        : kind === "interview"
          ? questions.some((q) => q.id === id)
          : news.some((n) => n.slug === id),
      m[1],
    );
  }
  for (const related of article.related)
    assert.ok(
      news.find((n) => n.slug === related).related.includes(article.slug),
    );
  const evidence = await json(
    "../../docs/website/unicode-20261029/research.json",
  );
  assert.equal(evidence.observedUnicodeTables["norm.Version"], "17.0.0");
  assert.ok(
    body.includes("does not implement") ||
      body.includes("stops short of implementing"),
  );
  assert.ok(body.includes("/downloads/go-unicode-lab-20261029.zip"));
  const controls = await json(
    "../../docs/website/unicode-20261029/negative-controls.json",
  );
  assert.equal(controls.length, 6);
  assert.ok(controls.every((c) => c.expectedFailure));
});

test("five distinct Unicode figures have reachable placements, while older guides retain three", async () => {
  const manifest = await json(
    "../../docs/website/unicode-20261029/assets.json",
  );
  const images = await json("../src/content/news-images.json");
  assert.equal(manifest.assets.length, 5);
  assert.equal(new Set(manifest.assets.map((a) => a.sha256)).size, 5);
  assert.equal(newsImageSuffixes(article.imagePrefix).length, 5);
  assert.ok(
    article.sections.some(
      (s) => s.id === newsDetailSection[article.imagePrefix],
    ),
  );
  for (const figure of newsExtraFigures[article.imagePrefix])
    assert.ok(article.sections.some((s) => s.id === figure.afterSection));
  for (const a of manifest.assets) {
    assert.equal(a.mode, "built-in image_gen");
    assert.ok(a.prompt.length > 100);
    assert.equal(images[a.id].width, 1536);
    assert.equal(images[a.id].height, 1024);
    const path = new URL("../public" + a.src, import.meta.url);
    assert.ok((await stat(path)).size > 10000);
    assert.equal(
      createHash("sha256")
        .update(await readFile(path))
        .digest("hex"),
      a.sha256,
    );
  }
  for (const n of news.filter((n) => n.imagePrefix !== article.imagePrefix))
    assert.deepEqual(newsImageSuffixes(n.imagePrefix), [
      "hero",
      "detail",
      "infographic",
    ]);
});
