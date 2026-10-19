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
