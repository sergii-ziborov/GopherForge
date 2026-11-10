import test from "node:test";
import assert from "node:assert/strict";
import {
  Y,
  newProject,
  projectFromY,
  replaceText,
  createFile,
  validateUpdate,
  encryptionKey,
  encrypt,
  decrypt,
} from "../src/lib/secure-collab.ts";
import { secureAction } from "../src/lib/secure-relay.ts";
const source = {
  "main.go": "package main\nfunc main(){}\n",
  "go.mod": "module playground\n\ngo 1.27.1\n",
};
const clone = (doc) => {
  const copy = new Y.Doc();
  Y.applyUpdate(copy, Y.encodeStateAsUpdate(doc));
  return copy;
};
test("concurrent source edits and rename/edit preserve both writers and stable file identity", () => {
  const base = newProject(source),
    a = clone(base),
    b = clone(base);
  try {
    const pa = projectFromY(a),
      pb = projectFromY(b);
    replaceText(pa.texts.get("main.go"), "// writer A\n" + source["main.go"]);
    replaceText(pb.texts.get("main.go"), source["main.go"] + "// writer B\n");
    const id = pa.identities["main.go"];
    a.getMap("entries").get(id).set("path", "renamed.go");
    Y.applyUpdate(a, Y.encodeStateAsUpdate(b));
    Y.applyUpdate(b, Y.encodeStateAsUpdate(a));
    assert.deepEqual(projectFromY(a).files, projectFromY(b).files);
    assert.match(projectFromY(a).files["renamed.go"], /writer A/);
    assert.match(projectFromY(a).files["renamed.go"], /writer B/);
    assert.equal(projectFromY(a).identities["renamed.go"], id);
  } finally {
    base.destroy();
    a.destroy();
    b.destroy();
  }
});
test("concurrent file names preserve conflict copies, deletion keeps recoverable source, invalid updates do not mutate the live doc", () => {
  const base = newProject(source),
    a = clone(base),
    b = clone(base);
  try {
    createFile(a, "note.txt", "A");
    createFile(b, "note.txt", "B");
    Y.applyUpdate(a, Y.encodeStateAsUpdate(b));
    const project = projectFromY(a);
    assert.equal(project.conflicts, 1);
    assert.ok(Object.values(project.files).includes("A"));
    assert.ok(Object.values(project.files).includes("B"));
    const id = project.identities["main.go"];
    a.getMap("entries").get(id).set("deleted", true);
    assert.ok(projectFromY(a).deleted.some((x) => x.id === id));
    a.getMap("entries").get(id).set("deleted", false);
    assert.equal(projectFromY(a).files["main.go"], source["main.go"]);
    const evil = clone(a);
    evil.getMap("entries").get(id).set("path", "../escape.go");
    const before = projectFromY(a).files;
    assert.throws(
      () => validateUpdate(a, Y.encodeStateAsUpdate(evil)),
      /metadata/,
    );
    assert.deepEqual(projectFromY(a).files, before);
    evil.destroy();
  } finally {
    base.destroy();
    a.destroy();
    b.destroy();
  }
});
test("AES-GCM rejects wrong keys/tampering and the relay stores ciphertext with enforced Edit/View/Owner rights", async () => {
  const key = encryptionKey(),
    doc = newProject(source);
  try {
    const initial = await encrypt(key, Y.encodeStateAsUpdate(doc)),
      created = secureAction({
        op: "create",
        snapshot: initial,
        ttlSeconds: 60,
      }),
      owner = created.capabilities.owner;
    const edit = secureAction({ op: "join" }, created.capabilities.edit),
      view = secureAction({ op: "join" }, created.capabilities.view);
    assert.ok(!JSON.stringify(created).includes("package main"));
    assert.ok(!JSON.stringify(edit).includes("package main"));
    assert.deepEqual(await decrypt(key, initial), Y.encodeStateAsUpdate(doc));
    await assert.rejects(decrypt(encryptionKey(), initial));
    await assert.rejects(
      decrypt(key, { ...initial, data: initial.data.slice(0, -4) + "AAAA" }),
    );
    const update = await encrypt(key, Y.encodeStateAsUpdate(doc));
    assert.throws(
      () =>
        secureAction(
          {
            op: "sync",
            after: 0,
            updates: [{ id: "update_123", packet: update }],
          },
          view.participantCapability,
        ),
      /view-only/,
    );
    const sent = secureAction(
      { op: "sync", after: 0, updates: [{ id: "update_123", packet: update }] },
      edit.participantCapability,
    );
    assert.equal(sent.head, 1);
    const duplicate = secureAction(
      { op: "sync", after: 0, updates: [{ id: "update_123", packet: update }] },
      edit.participantCapability,
    );
    assert.equal(duplicate.head, 1);
    assert.throws(
      () =>
        secureAction(
          { op: "compact", head: 0, snapshot: initial },
          edit.participantCapability,
        ),
      /advanced/,
    );
    secureAction(
      { op: "compact", head: 1, snapshot: initial },
      edit.participantCapability,
    );
    const reset = secureAction(
      { op: "sync", after: 0 },
      view.participantCapability,
    );
    assert.ok(reset.snapshot);
    assert.equal(reset.snapshotSequence, 1);
    const published = secureAction(
      { op: "publish", head: 1, snapshot: initial },
      edit.participantCapability,
    );
    assert.equal(published.head, 2);
    const offlineReset = secureAction(
      { op: "sync", after: 1 },
      view.participantCapability,
    );
    assert.ok(offlineReset.snapshot);
    assert.equal(offlineReset.snapshotSequence, 2);
    assert.throws(
      () =>
        secureAction(
          { op: "publish", head: 1, snapshot: initial },
          edit.participantCapability,
        ),
      /advanced/,
    );
    assert.throws(
      () =>
        secureAction(
          { op: "publish", head: 2, snapshot: initial },
          view.participantCapability,
        ),
      /view-only/,
    );
    assert.throws(
      () => secureAction({ op: "close" }, created.capabilities.edit),
      /owner/,
    );
    secureAction({ op: "close" }, owner);
    assert.throws(
      () => secureAction({ op: "sync", after: 0 }, view.participantCapability),
      /expired/,
    );
  } finally {
    doc.destroy();
  }
});
