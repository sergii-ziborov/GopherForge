// Bundled into the app: trusted CRDT logic only. Go execution remains native.
import {
  Y,
  newProject,
  projectFromY,
  replaceText,
  createFile,
  validateUpdate,
  b64url,
  unb64,
  type SharedRun,
  type SharedChange,
} from "./secure-collab.ts";
import {
  Awareness,
  encodeAwarenessUpdate,
  applyAwarenessUpdate,
  removeAwarenessStates,
} from "y-protocols/awareness";
import * as decoding from "lib0/decoding";
import { safeSourcePath } from "./playground-files.ts";
import { nickname } from "./playground-identity.ts";
let doc: Y.Doc, base: Y.Doc, awareness: Awareness;
function init(files?: Record<string, string>) {
  awareness?.destroy();
  doc?.destroy();
  base?.destroy();
  doc = files ? newProject(files) : new Y.Doc();
  base = new Y.Doc();
  awareness = new Awareness(doc);
}
function project() {
  return projectFromY(doc);
}
function view() {
  const p = project();
  const cursors = [...awareness.getStates()].flatMap(([id, state]) => {
    if (id === doc.clientID || !state?.user || !state.cursor) return [];
    try {
      const head = Y.createAbsolutePositionFromRelativePosition(
        Y.createRelativePositionFromJSON(state.cursor.head),
        doc,
      );
      const anchor = Y.createAbsolutePositionFromRelativePosition(
        Y.createRelativePositionFromJSON(state.cursor.anchor),
        doc,
      );
      const path = [...p.texts].find(([, text]) => text === head?.type)?.[0];
      return path && head && anchor && anchor.type === head.type
        ? [
            {
              id: String(id),
              name: nickname(state.user.name),
              color: state.user.color,
              path,
              anchor: anchor.index,
              head: head.index,
            },
          ]
        : [];
    } catch {
      return [];
    }
  });
  return {
    changes: p.changes,
    files: p.files,
    identities: p.identities,
    deleted: p.deleted,
    runs: p.runs,
    conflicts: p.conflicts,
    cursors,
    peers: [...awareness.getStates()].flatMap(([id, s]) =>
      s?.user
        ? [{ id: String(id), name: s.user.name, color: s.user.color }]
        : [],
    ),
  };
}
function presence(updates: string[]) {
  const retained = new Set([doc.clientID]);
  for (const update of updates) {
    try {
      const bytes = unb64(update, 16384),
        decoder = decoding.createDecoder(bytes),
        count = decoding.readVarUint(decoder);
      if (count > 16) continue;
      const ids: number[] = [];
      for (let i = 0; i < count; i++) {
        ids.push(decoding.readVarUint(decoder));
        decoding.readVarUint(decoder);
        const state = JSON.parse(decoding.readVarString(decoder));
        if (
          state !== null &&
          (!state.user ||
            nickname(state.user.name) !== state.user.name ||
            !/^#[a-f0-9]{6}$/i.test(state.user.color))
        )
          throw new Error("Invalid presence");
      }
      applyAwarenessUpdate(awareness, bytes, "remote");
      ids.forEach((id) => retained.add(id));
    } catch {
      /* A cursor must never discard valid source. */
    }
  }
  removeAwarenessStates(
    awareness,
    [...awareness.getStates().keys()].filter((id) => !retained.has(id)),
    "remote",
  );
}
let lastChangeKey = "",
  lastChangeAt = 0;
function record(kind: string, paths: string[]) {
  const name = awareness.getLocalState()?.user?.name;
  if (!name || !paths.length) return;
  const key = JSON.stringify([name, kind, paths]),
    at = Date.now();
  if (lastChangeKey === key && at - lastChangeAt < 2000) return;
  lastChangeKey = key;
  lastChangeAt = at;
  const changes = doc.getArray<SharedChange>("changes");
  doc.transact(() => {
    changes.push([{ id: crypto.randomUUID(), name, at, paths, kind }]);
    if (changes.length > 32) changes.delete(0, changes.length - 32);
  }, "attribution");
}
function sameBytes(a: Uint8Array, b: Uint8Array) {
  return a.length === b.length && a.every((n, i) => n === b[i]);
}
function deletions(bytes: Uint8Array) {
  return JSON.stringify(
    [...Y.decodeUpdate(bytes).ds.clients]
      .sort(([a], [b]) => a - b)
      .map(([id, ranges]) => [
        id,
        ranges.map((range) => [range.clock, range.len]),
      ]),
  );
}
function execute(input: Record<string, any>) {
  switch (input.op) {
    case "init":
      init(input.files);
      if (input.saved) {
        validateUpdate(doc, unb64(input.saved));
        Y.applyUpdate(doc, unb64(input.saved));
      }
      return view();
    case "apply": {
      const candidate = new Y.Doc();
      try {
        if (!input.snapshot)
          Y.applyUpdate(candidate, Y.encodeStateAsUpdate(base));
        if (input.snapshot) Y.applyUpdate(candidate, unb64(input.snapshot));
        for (const update of input.updates ?? [])
          Y.applyUpdate(candidate, unb64(update));
        projectFromY(candidate);
        const next = Y.encodeStateAsUpdate(candidate);
        validateUpdate(doc, next);
        base.destroy();
        base = candidate;
        Y.applyUpdate(doc, next, "remote");
      } catch (error) {
        candidate.destroy();
        throw error;
      }
      if (input.presence) presence(input.presence);
      return view();
    }
    case "edit": {
      const text = project().texts.get(input.path);
      if (!text) throw new Error("Choose an existing file");
      if (
        typeof input.text !== "string" ||
        input.text.includes("\0") ||
        new TextEncoder().encode(input.text).length > 128 * 1024
      )
        throw new Error("Source exceeds the collaborative editor limit");
      const total = [...doc.getMap<Y.Map<any>>("entries").values()].reduce(
        (n, e) => n + new TextEncoder().encode(e.get("text").toString()).length,
        0,
      );
      if (
        total -
          new TextEncoder().encode(text.toString()).length +
          new TextEncoder().encode(input.text).length >
        1024 * 1024
      )
        throw new Error("Collaborative recovery source exceeds 1 MiB");
      doc.transact(() => replaceText(text, input.text), "local");
      record("edit", [input.path]);
      return view();
    }
    case "replace": {
      const names = Object.keys(input.files ?? {});
      if (
        names.length > 64 ||
        names.some(
          (path) =>
            !safeSourcePath(path) ||
            typeof input.files[path] !== "string" ||
            input.files[path].includes("\0") ||
            new TextEncoder().encode(input.files[path]).length > 128 * 1024,
        )
      )
        throw new Error("Invalid shared source");
      if (
        names.some((path) =>
          names.some((other) => other !== path && other.startsWith(path + "/")),
        )
      )
        throw new Error("A file cannot also be a folder");
      const p = project();
      const total = [...doc.getMap<Y.Map<any>>("entries").values()].reduce(
        (n, e) => n + new TextEncoder().encode(e.get("text").toString()).length,
        0,
      );
      let retained = total;
      for (const [path, text] of Object.entries(
        input.files as Record<string, string>,
      ))
        retained +=
          new TextEncoder().encode(text).length -
          new TextEncoder().encode(p.files[path] ?? "").length;
      const additions = names.filter((path) => !p.identities[path]).length;
      if (
        retained > 1024 * 1024 ||
        doc.getMap("entries").size + additions > 128
      )
        throw new Error("Collaborative history exceeds its recovery budget");
      doc.transact(() => {
        for (const [path, id] of Object.entries(p.identities))
          if (!Object.hasOwn(input.files, path))
            doc.getMap<Y.Map<any>>("entries").get(id)!.set("deleted", true);
        for (const [path, text] of Object.entries(
          input.files as Record<string, string>,
        )) {
          const old = p.texts.get(path);
          if (old) replaceText(old, text);
          else createFile(doc, path, text);
        }
      }, "local");
      record("edit", names);
      return view();
    }
    case "rename": {
      if (typeof input.target !== "string" || !safeSourcePath(input.target))
        throw new Error("Use a safe source path");
      const paths = Object.keys(project().files).filter(
        (path) => path !== input.path,
      );
      if (
        paths.some(
          (path) =>
            path === input.target ||
            path.startsWith(input.target + "/") ||
            input.target.startsWith(path + "/"),
        )
      )
        throw new Error("The destination already exists");
      const id = project().identities[input.path];
      if (!id) throw new Error("Choose an existing file");
      doc.getMap<Y.Map<any>>("entries").get(id)!.set("path", input.target);
      record("rename", [input.path, input.target]);
      return view();
    }
    case "delete": {
      const id = project().identities[input.path];
      if (id) doc.getMap<Y.Map<any>>("entries").get(id)!.set("deleted", true);
      record("delete", [input.path]);
      return view();
    }
    case "restore": {
      if (Object.keys(project().files).length >= 64)
        throw new Error("Export recovery copies before restoring more files");
      doc.getMap<Y.Map<any>>("entries").get(input.id)?.set("deleted", false);
      record("restore", [input.id]);
      return view();
    }
    case "identity":
      awareness.setLocalStateField("user", {
        name: nickname(input.name),
        color: input.color,
      });
      return view();
    case "cursor": {
      const text = project().texts.get(input.path);
      awareness.setLocalStateField(
        "cursor",
        text
          ? {
              anchor: Y.createRelativePositionFromTypeIndex(
                text,
                Math.min(text.length, Math.max(0, input.anchor)),
              ),
              head: Y.createRelativePositionFromTypeIndex(
                text,
                Math.min(text.length, Math.max(0, input.head)),
              ),
            }
          : null,
      );
      return {};
    }
    case "run": {
      // Reject an invalid result before mutating the live document.
      const candidate = new Y.Doc();
      try {
        Y.applyUpdate(candidate, Y.encodeStateAsUpdate(doc));
        const results = candidate.getArray<SharedRun>("runs");
        results.push([input.result]);
        if (results.length > 16) results.delete(0, results.length - 16);
        projectFromY(candidate);
      } finally {
        candidate.destroy();
      }
      const runs = doc.getArray<SharedRun>("runs");
      doc.transact(() => {
        runs.push([input.result]);
        if (runs.length > 16) runs.delete(0, runs.length - 16);
      }, "local");
      return view();
    }
    case "export": {
      const state = Y.encodeStateAsUpdate(doc),
        server = Y.encodeStateAsUpdate(base),
        vector = Y.encodeStateVector(base);
      const pending =
        !sameBytes(Y.encodeStateVector(doc), vector) ||
        deletions(state) !== deletions(server);
      return {
        state: b64url(state),
        base: b64url(server),
        delta: b64url(
          pending ? Y.encodeStateAsUpdate(doc, vector) : new Uint8Array([0, 0]),
        ),
        pending,
      };
    }
    case "acknowledge": {
      const next = unb64(input.update);
      validateUpdate(base, next);
      Y.applyUpdate(base, next);
      return {};
    }
    case "presence":
      awareness.setLocalState(awareness.getLocalState());
      return {
        bytes: b64url(encodeAwarenessUpdate(awareness, [doc.clientID])),
      };
    case "view":
      return view();
    default:
      throw new Error("Unknown collaboration operation");
  }
}
export function command(json: string) {
  try {
    return JSON.stringify({ ok: true, value: execute(JSON.parse(json)) });
  } catch (error) {
    return JSON.stringify({
      ok: false,
      error: error instanceof Error ? error.message : "Invalid room data",
    });
  }
}
