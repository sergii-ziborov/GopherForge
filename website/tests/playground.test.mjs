import test from "node:test";
import assert from "node:assert/strict";
import { roomAction, sourceDigest, validateFiles } from "../src/lib/playground-core.ts";
import { mcpMessage } from "../src/lib/playground-mcp.ts";
const files = { "go.mod": "module demo\n\ngo 1.27.1\n", "main.go": 'package main\nfunc main() {}\n' };
function room() { return roomAction({ op: "create", files, title: "Contract test", ttlSeconds: 60 }); }
function join(value, kind = "native", cap = value.capabilities.edit) { return roomAction({ op: "join", kind, name: kind + " guest" }, cap); }
test("MCP edits and requests never start a run; only a joined native seat may begin its own run", async () => {
  const r = room(), a = join(r), b = join(r), browser = join(r, "web");
  const changed = { ...files, "main.go": "package main\nfunc main() { println(42) }\n" };
  const rpc = await mcpMessage({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "playground_write", arguments: { capability: r.capabilities.edit, revision: 0, files: changed } } });
  assert.equal(rpc.result.isError, false);
  const request = roomAction({ op: "request_run", revision: 1, phase: "run", targetID: a.participantID }, r.capabilities.edit);
  assert.equal(request.state, "awaiting_local_button");
  assert.equal(roomAction({ op: "read" }, b.participantCapability).runs.length, 0);
  assert.throws(() => roomAction({ op: "begin_run", revision: 1, phase: "run" }, browser.participantCapability), /native device/);
  const started = roomAction({ op: "begin_run", revision: 1, phase: "run", requestID: request.request.id }, a.participantCapability);
  assert.equal(started.run.participantID, a.participantID);
  assert.equal(started.run.sourceDigest, sourceDigest(changed));
  assert.throws(() => roomAction({ op: "finish_run", runID: started.run.id, succeeded: true, stdout: "forged" }, b.participantCapability), /own run/);
  roomAction({ op: "write", revision: 1, files }, r.capabilities.edit);
  roomAction({ op: "finish_run", runID: started.run.id, succeeded: true, stdout: "42\n", stderr: "" }, a.participantCapability);
  const observed = roomAction({ op: "read" }, b.participantCapability);
  assert.equal(observed.revision, 2); assert.equal(observed.runs[0].revision, 1);
  assert.equal(observed.runs[0].stdout, "42\n"); assert.equal(observed.runs[0].participantID, a.participantID);
  assert.equal(observed.requests.length, 0);
  const own = roomAction({ op: "begin_run", revision: 2, phase: "test" }, b.participantCapability);
  assert.equal(own.run.participantID, b.participantID);
  roomAction({ op: "close" }, r.capabilities.owner);
});
test("view, stale revisions, invalid capabilities and path escapes fail without modifying source", () => {
  const r = room(), viewer = join(r, "web", r.capabilities.view);
  assert.throws(() => roomAction({ op: "write", files, revision: 0 }, viewer.participantCapability), /view-only/);
  assert.throws(() => roomAction({ op: "request_run", phase: "run", revision: 0 }, viewer.participantCapability), /view-only/);
  roomAction({ op: "write", files: { ...files, "data.txt": "e\u0301" }, revision: 0 }, r.capabilities.edit);
  assert.throws(() => roomAction({ op: "write", files, revision: 0 }, r.capabilities.edit), /changed elsewhere/);
  assert.equal(roomAction({ op: "read" }, r.capabilities.view).files["data.txt"], "e\u0301");
  assert.throws(() => roomAction({ op: "read" }, r.id + ".invalid"), /invalid/);
  for (const path of ["../main.go", "/main.go", "a//b.go", "a/./b.go", "__proto__/x.go"]) assert.throws(() => validateFiles({ ...files, [path]: "x" }), /relative/);
  assert.throws(() => validateFiles({ ...files, "huge.go": "x".repeat(65537) }), /64 KiB/);
  assert.notEqual(sourceDigest({ ...files, "a": "é" }), sourceDigest({ ...files, "a": "e\u0301" }));
  const visible = roomAction({ op: "read" }, r.capabilities.view);
  assert.ok(!JSON.stringify(visible).includes(r.capabilities.owner));
  assert.throws(() => roomAction({ op: "close" }, viewer.participantCapability), /owner/);
  roomAction({ op: "close" }, r.capabilities.owner);
  assert.throws(() => roomAction({ op: "read" }, r.capabilities.edit), /expired/);
});
test("MCP negotiates, lists tools, handles notifications and returns useful tool errors", async () => {
  const init = await mcpMessage({ jsonrpc: "2.0", id: "init", method: "initialize", params: { protocolVersion: "2025-06-18" } });
  assert.equal(init.result.protocolVersion, "2025-06-18");
  assert.ok(init.result.instructions.includes("only a person"));
  assert.equal(await mcpMessage({ jsonrpc: "2.0", method: "notifications/initialized" }), null);
  const list = await mcpMessage({ jsonrpc: "2.0", id: 2, method: "tools/list" });
  assert.equal(list.result.tools.length, 4);
  const fail = await mcpMessage({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "playground_read", arguments: {} } });
  assert.equal(fail.result.isError, true); assert.match(fail.result.content[0].text, /capability/);
});
test('finishing the same local run is idempotent, final output cannot change, and a room actually expires', () => {
  const r=room(), a=join(r);
  const begun=roomAction({op:'begin_run',revision:0,phase:'run'},a.participantCapability);
  const result={op:'finish_run',runID:begun.run.id,succeeded:true,stdout:'same result',stderr:''};
  roomAction(result,a.participantCapability);
  roomAction(result,a.participantCapability);
  assert.equal(roomAction({op:'read'},r.capabilities.view).runs.length,1);
  assert.throws(()=>roomAction({...result,stdout:'different'},a.participantCapability),/already final/);
  const now=Date.now;
  try { Date.now=()=>now()+61000; assert.throws(()=>roomAction({op:'read'},r.capabilities.edit),/expired/); }
  finally { Date.now=now; }
});
