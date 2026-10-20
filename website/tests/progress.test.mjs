import test from "node:test";
import assert from "node:assert/strict";
import {
  readProgress,
  saveProgress,
  progressKey,
} from "../src/lib/progress.ts";

test("progress handles malformed and unknown storage without breaking lessons", () => {
  for (const value of [
    "not json",
    '{"version":2}',
    '{"version":1,"completed":3}',
  ]) {
    globalThis.localStorage = { getItem: () => value };
    assert.deepEqual(readProgress(), { version: 1, completed: [], last: null });
  }
  globalThis.localStorage = {
    getItem: () =>
      JSON.stringify({
        version: 1,
        completed: ["clean.errors", 3, null],
        last: 42,
      }),
  };
  assert.deepEqual(readProgress(), {
    version: 1,
    completed: ["clean.errors"],
    last: null,
  });
});

test("storage failure is reported and valid completion round-trips", () => {
  globalThis.localStorage = {
    setItem: () => {
      throw new Error("storage blocked");
    },
  };
  assert.equal(saveProgress({ version: 1, completed: [], last: null }), false);
  const stored = new Map();
  globalThis.window = new EventTarget();
  globalThis.localStorage = {
    setItem: (key, value) => stored.set(key, value),
    getItem: (key) => stored.get(key),
  };
  const expected = {
    version: 1,
    completed: ["clean.errors"],
    last: "clean.errors",
  };
  assert.equal(saveProgress(expected), true);
  assert.ok(stored.has(progressKey));
  assert.deepEqual(readProgress(), expected);
});

const {
  readStudy,
  visitStudy,
  studyURL,
  readAssessments,
  saveAssessment,
  assessmentKey,
} = await import("../src/lib/study.ts");
test("returning learners resume each area and keep their marks", () => {
  const stored = new Map([
    [
      assessmentKey,
      JSON.stringify({
        "language.values": "understood",
        "redis.load": "revisit",
        invalid: 3,
      }),
    ],
    [
      progressKey,
      JSON.stringify({
        version: 1,
        completed: ["clean.errors"],
        last: "clean.errors",
      }),
    ],
  ]);
  globalThis.window = new EventTarget();
  globalThis.localStorage = {
    getItem: (key) => stored.get(key),
    setItem: (key, value) => stored.set(key, value),
  };
  assert.equal(visitStudy("interview", "redis.load", "exercise"), true);
  assert.equal(visitStudy("course", "modules.cache", "section-2"), true);
  assert.equal(readStudy().area, "course");
  assert.deepEqual(readStudy().interview, {
    id: "redis.load",
    section: "exercise",
  });
  assert.equal(
    studyURL("interview", readStudy().interview),
    "/interview/redis.load#exercise",
  );
  assert.deepEqual(readProgress().completed, ["clean.errors"]);
  assert.deepEqual(readAssessments(), {
    "language.values": "understood",
    "redis.load": "revisit",
  });
  assert.equal(saveAssessment("redis.load", "understood"), true);
  assert.equal(saveAssessment("language.values", ""), true);
  assert.deepEqual(readAssessments(), { "redis.load": "understood" });
  assert.equal(readStudy().interview.id, "redis.load");
});
test("malformed bookmarks, unknown schemas and blocked storage are safe", () => {
  for (const value of [
    "bad json",
    '{"version":2}',
    '{"version":1,"area":"elsewhere","course":null,"interview":42}',
  ]) {
    globalThis.localStorage = { getItem: () => value };
    assert.deepEqual(readStudy(), {
      version: 1,
      area: null,
      course: null,
      interview: null,
    });
  }
  globalThis.localStorage = {
    getItem: () =>
      JSON.stringify({
        version: 1,
        area: "interview",
        interview: { id: "language.values", section: "<script>" },
      }),
    setItem: () => {
      throw new Error("blocked");
    },
  };
  assert.deepEqual(readStudy().interview, {
    id: "language.values",
    section: "",
  });
  assert.equal(visitStudy("interview", "language.values", "exercise"), false);
  assert.equal(saveAssessment("language.values", "revisit"), false);
});
