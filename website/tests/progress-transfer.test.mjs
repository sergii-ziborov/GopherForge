import test from "node:test";
import assert from "node:assert/strict";
import {
  exportTransfer,
  parseTransfer,
  previewTransfer,
  importTransfer,
} from "../src/lib/progress-transfer.ts";
import {
  readProgress,
  saveProgress,
  progressKey,
} from "../src/lib/progress.ts";
import {
  readStudy,
  clearStudyArea,
  readAssessments,
  saveAssessment,
  studyKey,
  assessmentKey,
} from "../src/lib/study.ts";
import { transferOverlayKey } from "../src/lib/progress-overlay.ts";
const catalog = {
  lessons: ["go.a", "go.b", "go.c"],
  interview: ["runtime.a", "runtime.b"],
};
function storage(entries = []) {
  const values = new Map(entries);
  let writes = 0;
  globalThis.window = new EventTarget();
  globalThis.localStorage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => {
      writes++;
      values.set(key, value);
    },
  };
  return { values, writes: () => writes };
}
function backup() {
  return {
    application: "GopherForge web learning",
    schemaVersion: 1,
    exportedAt: "2026-10-28T12:00:00Z",
    contentRevision: "2026-10-27",
    progress: {
      version: 1,
      completed: ["go.a", "go.b", "unknown.old"],
      last: "go.b",
    },
    study: {
      version: 1,
      area: "course",
      course: { id: "go.b", section: "exercise" },
      interview: { id: "runtime.b", section: "answer" },
    },
    assessments: { "runtime.a": "understood", "runtime.b": "revisit" },
  };
}
test("portable export contains only learning records, with no unrelated storage or secrets", () => {
  storage([
    [
      progressKey,
      JSON.stringify({ version: 1, completed: ["go.a"], last: "go.a" }),
    ],
    ["room-capability", "secret-link"],
    ["git-token", "private-token"],
  ]);
  const exported = exportTransfer("catalog-revision");
  assert.deepEqual(parseTransfer(JSON.stringify(exported)), exported);
  assert.equal(exported.schemaVersion, 1);
  assert.deepEqual(exported.progress.completed, ["go.a"]);
  assert.ok(!JSON.stringify(exported).includes("secret-link"));
  assert.ok(!JSON.stringify(exported).includes("private-token"));
});
test("preview is read-only, explains unknown IDs, and merge preserves marks and saved places", () => {
  const s = storage([
    [
      progressKey,
      JSON.stringify({ version: 1, completed: ["go.a"], last: "go.a" }),
    ],
    [assessmentKey, JSON.stringify({ "runtime.a": "revisit" })],
  ]);
  const incoming = parseTransfer(JSON.stringify(backup()));
  const preview = previewTransfer(incoming, catalog);
  assert.equal(preview.addedLessons, 1);
  assert.equal(preview.matchingLessons, 1);
  assert.equal(preview.keptAssessmentConflicts, 1);
  assert.deepEqual(preview.unknownIDs, ["unknown.old"]);
  assert.equal(s.writes(), 0);
  saveProgress({ version: 1, completed: ["go.a", "go.c"], last: "go.c" }); // between preview and apply
  const before = s.writes();
  importTransfer(incoming, catalog);
  assert.equal(
    s.writes() - before,
    1,
    "the complete transfer is one atomic storage mutation",
  );
  assert.deepEqual(
    new Set(readProgress().completed),
    new Set(["go.a", "go.b", "go.c"]),
  );
  assert.equal(readProgress().last, "go.c");
  assert.equal(readAssessments()["runtime.a"], "revisit");
  assert.equal(readStudy().course.id, "go.b");
  importTransfer(
    {
      ...incoming,
      progress: { version: 1, completed: [], last: null },
      assessments: {},
    },
    catalog,
  );
  assert.equal(
    readProgress().completed.length,
    3,
    "a poorer backup cannot clear current progress",
  );
});
test("undoing an imported mark to the exact old value does not resurrect the import", () => {
  const s = storage([
    [progressKey, JSON.stringify({ version: 1, completed: [], last: null })],
    [
      studyKey,
      JSON.stringify({ version: 1, area: null, course: null, interview: null }),
    ],
    [assessmentKey, "{}"],
  ]);
  importTransfer(parseTransfer(JSON.stringify(backup())), catalog);
  assert.equal(readProgress().completed.length, 2);
  saveProgress({ version: 1, completed: [], last: null });
  assert.deepEqual(readProgress().completed, []);
  clearStudyArea("course");
  clearStudyArea("interview");
  assert.equal(readStudy().course, null);
  assert.equal(readStudy().interview, null);
  saveAssessment("runtime.a", "");
  saveAssessment("runtime.b", "");
  assert.deepEqual(readAssessments(), {});
  const persisted = [...s.values];
  storage(persisted); // a new browser session
  assert.deepEqual(readProgress().completed, []);
  assert.equal(readStudy().area, null);
  assert.deepEqual(readAssessments(), {});
});
test("quota failure leaves all previous slices intact, including a previous import", () => {
  const s = storage();
  importTransfer(parseTransfer(JSON.stringify(backup())), catalog);
  const before = [...s.values];
  globalThis.localStorage.setItem = () => {
    throw new Error("QuotaExceeded");
  };
  assert.throws(
    () => importTransfer(parseTransfer(JSON.stringify(backup())), catalog),
    /QuotaExceeded/,
  );
  assert.deepEqual([...s.values], before);
  assert.deepEqual(readProgress().completed, ["go.a", "go.b"]);
});
test("future schemas and malicious or oversized input never mutate progress", () => {
  const s = storage();
  for (const mutate of [
    (x) => (x.schemaVersion = 99),
    (x) => (x.progress.completed = ["<script>"]),
    (x) => (x.study.course.section = "../../private"),
    (x) => (x.assessments["runtime.a"] = "compilerVerified"),
  ]) {
    const value = backup();
    mutate(value);
    assert.throws(() => parseTransfer(JSON.stringify(value)));
  }
  assert.throws(
    () => parseTransfer(" ".repeat(2 * 1024 * 1024 + 1)),
    /smaller/,
  );
  s.values.set(transferOverlayKey, '{"schemaVersion":99}');
  const before = [...s.values];
  assert.throws(
    () => importTransfer(parseTransfer(JSON.stringify(backup())), catalog),
    /unsupported format/,
  );
  assert.deepEqual([...s.values], before);
});
test("combined record limits refuse import instead of dropping existing records", () => {
  const existing = Array.from({ length: 1000 }, (_, i) => `old.${i}`);
  const s = storage([
    [
      progressKey,
      JSON.stringify({ version: 1, completed: existing, last: null }),
    ],
  ]);
  assert.throws(
    () => importTransfer(parseTransfer(JSON.stringify(backup())), catalog),
    /record limit/,
  );
  assert.equal(s.writes(), 0);
  assert.deepEqual(readProgress().completed, existing);
});
