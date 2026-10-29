import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { parseSnapshot, publishProgress, readSharedProgress, revokeProgress } from "../src/lib/progress-share.ts";
import { mcpMessage } from "../src/lib/playground-mcp.ts";
test("published progress is readable without an account, whitelisted and revocable; local records are not changed", async () => {
  const dir = await mkdtemp(join(tmpdir(), "gopherforge-share-test-")); process.env.GOPHERFORGE_SHARE_DIR = dir;
  const local = { schemaVersion: 1, source: "app", completed: ["core.short-declaration"], compilerVerified: ["core.short-declaration"], assessments: { "language.zero-values": "revisit" }, lastLessonID: "core.short-declaration", lastInterviewID: null, code: "private", capability: "secret" };
  try {
    const before = JSON.stringify(local), published = await publishProgress(local), value = await readSharedProgress(published.shareID);
    assert.equal(JSON.stringify(local), before);
    assert.deepEqual(value.snapshot.completed, local.completed);
    assert.ok(!JSON.stringify(value).includes("private")); assert.ok(!JSON.stringify(value).includes("secret"));
    assert.ok(!JSON.stringify(value).includes(published.revokeToken));
    const ai = await mcpMessage({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "learning_progress_read", arguments: { shareID: published.shareID } } });
    assert.equal(ai.result.isError, false);
    await assert.rejects(() => revokeProgress(published.shareID, "wrong"), /revocation/);
    await revokeProgress(published.shareID, published.revokeToken);
    assert.equal(await readSharedProgress(published.shareID), null);
    assert.equal(await readSharedProgress("../../etc/passwd"), null);
    assert.equal(JSON.stringify(local), before);
  } finally { await rm(dir, { recursive: true, force: true }); delete process.env.GOPHERFORGE_SHARE_DIR; }
});
test("web progress cannot claim a compiler pass, and malformed or excessive marks are rejected", () => {
  const value = { schemaVersion: 1, source: "web", completed: ["go.a"], compilerVerified: [], assessments: {}, lastLessonID: null, lastInterviewID: null };
  assert.equal(parseSnapshot(value).source, "web");
  assert.throws(() => parseSnapshot({ ...value, compilerVerified: ["go.a"] }), /self-reported/);
  assert.throws(() => parseSnapshot({ ...value, source: "app", compilerVerified: ["go.other"] }), /completed/);
  assert.throws(() => parseSnapshot({ ...value, completed: Array(1001).fill("go.a") }), /IDs/);
  assert.throws(() => parseSnapshot({ ...value, assessments: { "go.a": "certified" } }), /marks/);
});
