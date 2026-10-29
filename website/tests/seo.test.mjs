import test from "node:test";
import assert from "node:assert/strict";
import { metadataDate } from "../src/lib/seo-dates.ts";
import { readFile } from "node:fs/promises";

test("Google article metadata includes timezone without moving legacy editorial days", async () => {
  const news = JSON.parse(
    await readFile(new URL("../src/content/news.json", import.meta.url)),
  );
  for (const article of news) {
    for (const day of [article.publishedAt, article.modifiedAt]) {
      const value = metadataDate(day);
      assert.match(
        value,
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$/,
      );
      assert.equal(value.slice(0, 10), day.slice(0, 10));
      assert.ok(Number.isFinite(Date.parse(value)));
    }
  }
  assert.equal(
    metadataDate("2026-10-29T11:33:37+03:00"),
    "2026-10-29T11:33:37+03:00",
  );
});
