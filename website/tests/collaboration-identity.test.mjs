import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createContext, runInContext } from "node:vm";
import { nickname } from "../src/lib/playground-identity.ts";
import { roomAction } from "../src/lib/playground-core.ts";
import { mcpMessage } from "../src/lib/playground-mcp.ts";
import {
  Y,
  newProject,
  projectFromY,
  b64url,
  unb64,
} from "../src/lib/secure-collab.ts";
const source = {
  "main.go": "package main\n// e\u0301 👩‍💻\nfunc main() {}\n",
  "go.mod": "module playground\n\ngo 1.27.1\n",
};
test("nicknames preserve Unicode display labels and reject blank, oversized or directional/control input", () => {
  assert.equal(nickname("  Ａlex  Go  "), "Alex Go");
  assert.equal(nickname("Zoë 👩‍💻"), "Zoë 👩‍💻");
  for (const text of [
    "",
    "   ",
    "a".repeat(33),
    "Alex\nAdmin",
    "Alex\u202eAdmin",
  ])
    assert.throws(() => nickname(text));
});
test("compatible people have named cursors and edit history; stale presence never blocks receiving a newer revision", () => {
  const room = roomAction({ op: "create", files: source }),
    a = roomAction(
      { op: "join", kind: "native", name: "Alex" },
      room.capabilities.edit,
    ),
    b = roomAction(
      { op: "join", kind: "web", name: "Reader" },
      room.capabilities.view,
    );
  try {
    const present = roomAction(
      {
        op: "presence",
        cursor: { path: "main.go", anchor: 2, head: 4, revision: 0 },
      },
      a.participantCapability,
    );
    assert.equal(
      present.participants.find((p) => p.id === a.participantID).cursor.head,
      4,
    );
    const update = roomAction(
      {
        op: "write",
        revision: 0,
        files: { ...source, "main.go": source["main.go"] + "// edit\n" },
      },
      a.participantCapability,
    );
    assert.equal(update.changes.at(-1).name, "Alex");
    assert.deepEqual(update.changes.at(-1).paths, ["main.go"]);
    const stale = roomAction(
      {
        op: "presence",
        cursor: { path: "main.go", anchor: 99999, head: 99999, revision: 0 },
      },
      b.participantCapability,
    );
    assert.equal(stale.revision, 1);
    assert.equal(
      stale.participants.find((p) => p.id === b.participantID).cursor,
      undefined,
    );
    assert.throws(
      () =>
        roomAction(
          { op: "write", revision: 1, files: source },
          b.participantCapability,
        ),
      /view-only/,
    );
    assert.throws(
      () =>
        roomAction(
          { op: "presence", name: "x\nAdmin" },
          a.participantCapability,
        ),
      /control/,
    );
  } finally {
    roomAction({ op: "close" }, room.capabilities.owner);
  }
});
test("MCP joins with a nickname and stays within the configured room and role", async () => {
  const room = roomAction({ op: "create", files: source });
  const call = (name, args, bearer = room.capabilities.edit) =>
    mcpMessage(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name, arguments: args },
      },
      bearer,
    );
  try {
    const joined = await call("playground_join", { nickname: "Code helper" });
    assert.equal(joined.result.isError, false);
    const seat = JSON.parse(
      joined.result.content[0].text,
    ).participantCapability;
    const write = await call("playground_write", {
      capability: seat,
      revision: 0,
      files: { ...source, "main.go": source["main.go"] + "// assistant\n" },
    });
    assert.equal(write.result.isError, false);
    assert.equal(
      JSON.parse(write.result.content[0].text).changes.at(-1).name,
      "Code helper",
    );
    const denied = await call(
      "playground_write",
      { capability: seat, revision: 1, files: source },
      room.capabilities.view,
    );
    assert.equal(denied.result.isError, true);
  } finally {
    roomAction({ op: "close" }, room.capabilities.owner);
  }
});
test("the actual bundled native Yjs engine merges concurrent browser edits and exposes relative cursor positions", async () => {
  const bundle = await readFile(
    new URL("../../GopherForge/Resources/PlaygroundCRDT.js", import.meta.url),
    "utf8",
  );
  const native = createContext({
    crypto,
    TextEncoder,
    TextDecoder,
    atob,
    btoa,
    console,
    setInterval: () => 0,
    clearInterval: () => {},
    setTimeout: () => 0,
    clearTimeout: () => {},
  });
  runInContext(bundle, native);
  const command = (input) => {
    const reply = JSON.parse(
      native.GopherForgeCRDT.command(JSON.stringify(input)),
    );
    assert.ok(reply.ok, reply.error);
    return reply.value;
  };
  const web = newProject(source);
  try {
    command({ op: "init" });
    command({ op: "apply", snapshot: b64url(Y.encodeStateAsUpdate(web)) });
    command({ op: "identity", name: "Native Alex", color: "#63b8c4" });
    projectFromY(web).texts.get("main.go").insert(0, "// browser\n");
    command({
      op: "edit",
      path: "main.go",
      text: source["main.go"] + "// native\n",
    });
    command({ op: "apply", updates: [b64url(Y.encodeStateAsUpdate(web))] });
    const exported = command({ op: "export" });
    Y.applyUpdate(web, unb64(exported.state));
    assert.deepEqual(command({ op: "view" }).files, projectFromY(web).files);
    assert.match(projectFromY(web).files["main.go"], /browser/);
    assert.match(projectFromY(web).files["main.go"], /native/);
    command({ op: "acknowledge", update: exported.state });
    assert.equal(command({ op: "export" }).pending, false);
    command({ op: "rename", path: "main.go", target: "renamed.go" });
    command({ op: "delete", path: "renamed.go" });
    const deleted = command({ op: "export" });
    assert.equal(deleted.pending, true);
    command({ op: "acknowledge", update: deleted.delta });
    assert.equal(command({ op: "export" }).pending, false);
    assert.deepEqual([...unb64(command({ op: "export" }).delta)], [0, 0]);
    const recovery = command({ op: "view" }).deleted[0].id;
    command({ op: "restore", id: recovery });
    const before = command({ op: "view" }).files;
    assert.throws(() =>
      command({ op: "run", result: { stdout: "x".repeat(16001) } }),
    );
    assert.deepEqual(command({ op: "view" }).files, before);
    command({ op: "cursor", path: "renamed.go", anchor: 2, head: 5 });
    assert.ok(command({ op: "presence" }).bytes);
  } finally {
    web.destroy();
  }
});

test("concurrent writers can append to a full change history without blocking source merges", () => {
  const a = newProject(source),
    b = new Y.Doc();
  try {
    const change = (id) => ({
      id,
      name: "Alex",
      at: 1,
      paths: ["main.go"],
      kind: "edit",
    });
    a.getArray("changes").push(
      Array.from({ length: 32 }, (_, i) => change(String(i))),
    );
    Y.applyUpdate(b, Y.encodeStateAsUpdate(a));
    a.getArray("changes").push([change("a")]);
    a.getArray("changes").delete(0, 1);
    b.getArray("changes").push([change("b")]);
    b.getArray("changes").delete(0, 1);
    Y.applyUpdate(a, Y.encodeStateAsUpdate(b));
    assert.equal(projectFromY(a).changes.length, 32);
    assert.ok(projectFromY(a).changes.some((c) => c.id === "a"));
    assert.ok(projectFromY(a).changes.some((c) => c.id === "b"));
  } finally {
    a.destroy();
    b.destroy();
  }
});
