import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const read = (p) => readFile(new URL(p, import.meta.url), "utf8");
test("the app guide explains real capabilities, persistence and sandbox boundaries", async () => {
  const guide = JSON.parse(await read("../src/content/app-guide.json"));
  assert.ok(guide.sections.length >= 12);
  assert.equal(
    new Set(guide.sections.map((s) => s.id)).size,
    guide.sections.length,
  );
  assert.ok(
    guide.sections.reduce((n, s) => n + s.body.split(/\s+/).length, 0) >= 2000,
  );
  const body = guide.sections.map((s) => s.body).join("\n");
  for (const phrase of [
    "Continue",
    "browser storage",
    "WASI",
    "4,000",
    "96 MiB",
    "512 MiB",
    "Codex",
    "SQL",
    "does not",
    "1.27.1",
  ])
    assert.ok(body.includes(phrase), phrase);
  const paths = [...body.matchAll(/\]\((\/[^)]+)\)/g)].map((m) => m[1]);
  const course = JSON.parse(await read("../src/content/course.json")).flatMap(
    (u) => u.lessons,
  );
  const interview = JSON.parse(await read("../src/content/interview.json"));
  for (const p of paths) {
    if (p.startsWith("/learn/") && !p.startsWith("/learn/units/"))
      assert.ok(
        course.some((l) => p === `/learn/${l.id}`),
        p,
      );
    if (p.startsWith("/interview/"))
      assert.ok(
        interview.questions.some((q) => p === `/interview/${q.id}`),
        p,
      );
  }
  assert.ok(guide.faq.length >= 5);
  assert.ok((await read("../src/app/sitemap.ts")).includes('"/guide"'));
});
test("the approved opaque icon stays identical in native, website and favicon", async () => {
  const native = await readFile(
    new URL(
      "../../GopherForge/Resources/Assets.xcassets/AppIcon.appiconset/GopherForgeIcon-1024.png",
      import.meta.url,
    ),
  );
  for (const p of ["../public/images/app-icon.png", "../src/app/icon.png"])
    assert.deepEqual(await readFile(new URL(p, import.meta.url)), native);
});
