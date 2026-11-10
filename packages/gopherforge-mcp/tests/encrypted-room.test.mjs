import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createContext, runInContext } from "node:vm";
import { EncryptedRoomClient, parseRoomLink } from "../dist/index.mjs";
import { fixture, files, Y, decrypt } from "./fixtures.mjs";
import { replaceText, projectFromY } from "../../../website/src/lib/secure-collab.ts";

test("own encrypted MCP interoperates with the shipped native CRDT, including names, cursor, edits, requests and output", async () => {
  const f = await fixture(), agent = new EncryptedRoomClient({ roomLink: f.link("edit"), name: "Go helper", fetchImpl: f.fetch, pollMs: 0 });
  const native = f.join(), token = native.participantCapability;
  const sandbox = createContext({ crypto, TextEncoder, TextDecoder, atob, btoa, console, setInterval: () => 0, clearInterval() {}, setTimeout: () => 0, clearTimeout() {} });
  runInContext(await readFile(new URL("../../../GopherForge/Resources/PlaygroundCRDT.js", import.meta.url), "utf8"), sandbox);
  const command = value => { const result = JSON.parse(sandbox.GopherForgeCRDT.command(JSON.stringify(value))); assert.equal(result.ok, true, result.error); return result.value; };
  async function nativeSync() {
    const reply = f.state(token), input = { op: "apply", updates: [], presence: [] };
    if (reply.snapshot) input.snapshot = Buffer.from(await decrypt(f.secret, reply.snapshot)).toString("base64url");
    for (const event of reply.events) input.updates.push(Buffer.from(await decrypt(f.secret, event.packet)).toString("base64url"));
    for (const peer of reply.participants) if (peer.packet) input.presence.push(Buffer.from(await decrypt(f.secret, peer.packet, "presence")).toString("base64url"));
    return command(input);
  }
  try {
    command({ op: "init" });
    const before = await agent.read();
    assert.deepEqual(before.files, files); assert.equal(before.role, "edit");
    await agent.cursor("main.go", files["main.go"].indexOf("fmt.Println"));
    let view = await nativeSync();
    assert.ok(view.peers.some(p => p.name === "Go helper"));
    assert.ok(view.cursors.some(c => c.name === "Go helper" && c.path === "main.go"));
    const next = { ...files, "main.go": files["main.go"].replace("private Go draft", "agent changed safely") };
    const published = await agent.write(before.sourceHash, next);
    assert.equal(published.executed, false);
    view = await nativeSync();
    assert.equal(view.files["main.go"], next["main.go"]);
    assert.ok(view.changes.some(c => c.name === "Go helper" && c.kind === "agent edit"));
    const requested = await agent.requestRun(published.sourceHash, "test");
    assert.equal(requested.requestState, "awaiting_local_button"); assert.equal(requested.executed, false);
    view = await nativeSync();
    assert.ok(view.changes.some(c => c.name === "Go helper" && c.kind === "request test"));
    // A separate device reports a result; the agent has no execution path.
    const remote = await f.document(token);
    remote.doc.getArray("runs").push([{ id: crypto.randomUUID(), name: "Person's iPad", phase: "test", sourceHash: published.sourceHash, stdout: "PASS", stderr: "", succeeded: true, at: Date.now() }]);
    await f.publish(token, remote.doc, remote.head); remote.doc.destroy();
    const report = await agent.read();
    assert.ok(report.results.some(r => r.name === "Person's iPad" && r.stdout === "PASS" && r.currentSource && r.evidence === "participant_reported_not_attested"));
    assert.equal(report.requests.find(r => r.id === requested.requestId).status, "result_reported");
    const network = JSON.stringify(f.calls);
    for (const plaintext of [f.secret, "private Go draft", "agent changed safely", "Go helper", "Person's iPad", '"sourceHash"']) assert.equal(network.includes(plaintext), false, plaintext);
    assert.ok(f.calls.every(c => c.url === "https://gopherforge.app/api/playground/secure" && c.options.redirect === "error"));
  } finally { await agent.leave(); f.close(); }
});

test("stale source and a publish race preserve the human's draft", async () => {
  const f = await fixture(), agent = new EncryptedRoomClient({ roomLink: f.link("edit"), name: "Assistant", fetchImpl: f.fetch, pollMs: 0 }), human = f.join();
  try {
    const before = await agent.read();
    f.beforePublish = async () => {
      const p = await f.document(human.participantCapability);
      replaceText(projectFromY(p.doc).texts.get("main.go"), files["main.go"] + "// human edit\n");
      await f.publish(human.participantCapability, p.doc, p.head); p.doc.destroy();
    };
    await assert.rejects(agent.write(before.sourceHash, { ...files, "main.go": files["main.go"] + "// stale agent edit\n" }), e => e.code === "source_conflict");
    const current = await agent.read(); assert.match(current.files["main.go"], /human edit/); assert.doesNotMatch(current.files["main.go"], /stale agent edit/);
    await assert.rejects(agent.write(before.sourceHash, files), e => e.code === "source_conflict");
  } finally { await agent.leave(); f.close(); }
});

test("View and Owner links cannot publish; wrong keys do not retain a participant", async () => {
  const f = await fixture(), view = new EncryptedRoomClient({ roomLink: f.link("view"), name: "Reader", fetchImpl: f.fetch, pollMs: 0 });
  const owner = new EncryptedRoomClient({ roomLink: f.link("owner"), name: "Owner attempt", fetchImpl: f.fetch, pollMs: 0 });
  const bad = new URL(f.link("edit")), params = new URLSearchParams(bad.hash.slice(1)); params.set("key", Buffer.alloc(32, 1).toString("base64url")); bad.hash = params.toString();
  const wrong = new EncryptedRoomClient({ roomLink: bad.href, name: "Wrong key", fetchImpl: f.fetch, pollMs: 0 });
  try {
    const read = await view.read(); assert.deepEqual(read.files, files);
    await assert.rejects(view.write(read.sourceHash, files), e => e.code === "permission_denied");
    await assert.rejects(view.requestRun(read.sourceHash, "run"), e => e.code === "permission_denied");
    await assert.rejects(owner.join(), e => e.code === "permission_denied");
    await assert.rejects(wrong.join(), e => e.code === "invalid_ciphertext");
    assert.equal(wrong.token, undefined);
  } finally { await Promise.all([view.leave(), owner.leave(), wrong.leave()]); f.close(); }
});

test("malformed authenticated updates, paths, budgets and cursor offsets do not alter valid local source", async () => {
  const f = await fixture(), agent = new EncryptedRoomClient({ roomLink: f.link("edit"), name: "Helper", fetchImpl: f.fetch, pollMs: 0 }), peer = f.join();
  try {
    const before = await agent.read();
    await assert.rejects(agent.cursor("main.go", 100000), e => e.code === "invalid_cursor");
    assert.throws(() => agent.write(before.sourceHash, { ...files, "../escape.go": "text" }), /safe relative/);
    assert.throws(() => agent.write(before.sourceHash, { ...files, "big.txt": "a".repeat(65537) }), /64 KiB/);
    assert.throws(() => agent.write(before.sourceHash, { ...files, "broken.txt": "\ud800" }), /Unicode/);
    const state = await f.document(peer.participantCapability);
    const id = projectFromY(state.doc).identities["main.go"];
    state.doc.getMap("entries").get(id).set("path", "../escape.go");
    await f.publish(peer.participantCapability, state.doc, state.head); state.doc.destroy();
    await assert.rejects(agent.read(), e => e.code === "invalid_ciphertext");
    // Treat the companion and website as independent Yjs installations:
    // exchange encoded state, never use cross-install instanceof checks.
    const retained = new Y.Doc();
    Y.applyUpdate(retained, Y.encodeStateAsUpdate(agent.doc));
    assert.deepEqual(projectFromY(retained).files, files); retained.destroy();
  } finally { await agent.leave(); f.close(); }
});

test("nicknames are required and link parsing binds every call to one selected GopherForge origin", async () => {
  const f = await fixture(), agent = new EncryptedRoomClient({ roomLink: f.link("edit"), fetchImpl: f.fetch, pollMs: 0 });
  try {
    await assert.rejects(agent.read(), e => e.code === "nickname_required");
    await agent.join("Named agent"); assert.equal((await agent.read()).nickname, "Named agent");
    for (const bad of [f.link("edit").replace("gopherforge.app", "gopherforge.app.evil.example"), f.link("edit").replace("https:", "http:"), f.link("edit") + "&key=duplicate", "https://gopherforge.app/playground#cap=" + f.room.capabilities.edit])
      assert.throws(() => parseRoomLink(bad), e => e.code === "invalid_link");
  } finally { await agent.leave(); f.close(); }
});
