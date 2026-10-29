import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import {
  NEWS_PAGE_SIZE,
  newsPageBounds,
  newsPageCount,
  newsPageURL,
} from "../src/lib/news-pagination.ts";

test("news page boundaries cover the archive once and reject invalid pages", () => {
  for (const total of [1, 8, 9, 10, 18, 33, 40]) {
    const positions = [];
    for (let page = 1; page <= newsPageCount(total); page++) {
      const { start, end } = newsPageBounds(total, page);
      assert.ok(end - start > 0 && end - start <= NEWS_PAGE_SIZE);
      positions.push(
        ...Array.from({ length: end - start }, (_, i) => start + i),
      );
    }
    assert.deepEqual(
      positions,
      Array.from({ length: total }, (_, i) => i),
    );
    for (const invalid of [0, -1, 1.5, NaN, Infinity, newsPageCount(total) + 1])
      assert.equal(newsPageBounds(total, invalid), null);
  }
  assert.equal(newsPageURL(1), "/news");
  assert.equal(newsPageURL(2), "/news/page/2");
  assert.equal(newsPageCount(33), 4);
});

test("every news card uses a declared original image that exists", async () => {
  const news = JSON.parse(
    await readFile(new URL("../src/content/news.json", import.meta.url)),
  );
  const images = JSON.parse(
    await readFile(new URL("../src/content/news-images.json", import.meta.url)),
  );
  for (const n of news) {
    const image = images[n.imagePrefix + "-hero"];
    assert.ok(image && image.width > 0 && image.height > 0, n.slug);
    assert.ok(
      (await stat(new URL("../public" + image.src, import.meta.url))).size >
        10000,
      n.slug,
    );
  }
});
