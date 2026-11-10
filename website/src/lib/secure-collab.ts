import * as Y from "yjs";
import { validateSource } from "./playground-files.ts";
import type { CipherPacket } from "./secure-relay.ts";
export { Y };
export const b64url = (bytes: Uint8Array) => {
  let text = "";
  for (let i = 0; i < bytes.length; i += 8192)
    text += String.fromCharCode(...bytes.subarray(i, i + 8192));
  return btoa(text)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
};
export function unb64(text: string, max = 2 * 1024 * 1024) {
  if (
    !/^[A-Za-z0-9_-]+$/.test(text) ||
    text.length > Math.ceil((max * 4) / 3) + 4
  )
    throw new Error("Invalid encrypted data");
  const binary = atob(text.replaceAll("-", "+").replaceAll("_", "/"));
  if (binary.length > max) throw new Error("Encrypted data is oversized");
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}
export const encryptionKey = () =>
  b64url(crypto.getRandomValues(new Uint8Array(32)));
async function key(secret: string) {
  const bytes = unb64(secret, 32);
  if (bytes.length !== 32) throw new Error("Invalid room encryption key");
  return crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}
export async function encrypt(
  secret: string,
  data: Uint8Array,
  channel = "doc",
): Promise<CipherPacket> {
  const iv = crypto.getRandomValues(new Uint8Array(12)),
    cipher = await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv,
        additionalData: new TextEncoder().encode(
          "gopherforge-browser-v2:" + channel,
        ),
      },
      await key(secret),
      new Uint8Array(data),
    );
  return { iv: b64url(iv), data: b64url(new Uint8Array(cipher)) };
}
export async function decrypt(
  secret: string,
  p: CipherPacket,
  channel = "doc",
) {
  const iv = unb64(p.iv, 12);
  if (iv.length !== 12) throw new Error("Invalid encryption nonce");
  const data = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv,
      additionalData: new TextEncoder().encode(
        "gopherforge-browser-v2:" + channel,
      ),
    },
    await key(secret),
    unb64(p.data, 1536 * 1024 + 16),
  );
  return new Uint8Array(data);
}
export function replaceText(text: Y.Text, next: string) {
  const previous = text.toString();
  let start = 0,
    end = 0;
  while (
    start < previous.length &&
    start < next.length &&
    previous[start] === next[start]
  )
    start++;
  if (
    start &&
    previous.charCodeAt(start) >= 0xdc00 &&
    previous.charCodeAt(start) <= 0xdfff
  )
    start--;
  while (
    end < previous.length - start &&
    end < next.length - start &&
    previous[previous.length - 1 - end] === next[next.length - 1 - end]
  )
    end++;
  if (
    end &&
    previous.charCodeAt(previous.length - end) >= 0xdc00 &&
    previous.charCodeAt(previous.length - end) <= 0xdfff
  )
    end--;
  if (previous.length - start - end)
    text.delete(start, previous.length - start - end);
  if (next.length - start - end)
    text.insert(start, next.slice(start, next.length - end));
}
export type SharedRun = {
  id: string;
  name: string;
  phase: string;
  sourceHash: string;
  stdout: string;
  stderr: string;
  succeeded: boolean;
  at: number;
};
export type SharedChange = {
  id: string;
  name: string;
  at: number;
  paths: string[];
  kind: string;
};
export function projectFromY(doc: Y.Doc) {
  const entries = doc.getMap<Y.Map<unknown>>("entries");
  if (entries.size > 128)
    throw new Error("Collaborative history exceeds 128 file identities");
  const active: { id: string; path: string; text: string; value: Y.Text }[] =
      [],
    deleted: { id: string; path: string }[] = [];
  let total = 0;
  for (const [id, entry] of entries) {
    if (!/^[a-zA-Z0-9_-]{8,80}$/.test(id) || !(entry instanceof Y.Map))
      throw new Error("Invalid collaborative file");
    const path = entry.get("path"),
      text = entry.get("text"),
      removed = entry.get("deleted");
    if (
      typeof path !== "string" ||
      !/^[a-zA-Z0-9_./-]{1,180}$/.test(path) ||
      path.startsWith("/") ||
      path
        .split("/")
        .some(
          (p) =>
            !p ||
            [".", "..", "__proto__", "constructor", "prototype"].includes(p),
        ) ||
      !(text instanceof Y.Text) ||
      typeof removed !== "boolean"
    )
      throw new Error("Invalid collaborative file metadata");
    const source = text.toString(),
      size = new TextEncoder().encode(source).length;
    total += size;
    if (source.includes("\0") || size > 128 * 1024 || total > 1024 * 1024)
      throw new Error("Collaborative recovery text exceeds its budget");
    if (removed) deleted.push({ id, path });
    else active.push({ id, path, text: source, value: text });
  }
  if (active.length > 64)
    throw new Error("Collaborative project exceeds 64 recovery files");
  const files: Record<string, string> = {},
    identities: Record<string, string> = {},
    texts = new Map<string, Y.Text>();
  let conflicts = 0;
  for (const f of active.sort((a, b) => (a.id < b.id ? -1 : 1))) {
    let path = f.path;
    if (
      Object.hasOwn(files, path) ||
      Object.keys(files).some(
        (p) => path.startsWith(p + "/") || p.startsWith(path + "/"),
      )
    ) {
      const base =
        "__conflict_" + f.id.slice(0, 12) + "_" + path.split("/").at(-1);
      path = base;
      let attempt = 0;
      while (
        Object.hasOwn(files, path) ||
        Object.keys(files).some(
          (p) => path.startsWith(p + "/") || p.startsWith(path + "/"),
        )
      )
        path = "conflict" + ++attempt + "_" + base;
      conflicts++;
    }
    files[path] = f.text;
    identities[path] = f.id;
    texts.set(path, f.value);
  }
  const runs = doc.getArray<SharedRun>("runs").toArray().slice(-16);
  for (const r of runs)
    if (
      !r ||
      typeof r.id !== "string" ||
      typeof r.stdout !== "string" ||
      r.stdout.length > 16000 ||
      typeof r.stderr !== "string" ||
      r.stderr.length > 16000 ||
      typeof r.sourceHash !== "string" ||
      !/^[a-f0-9]{64}$/.test(r.sourceHash) ||
      typeof r.name !== "string" ||
      r.name.length > 80
    )
      throw new Error("Invalid shared result");
  // Concurrent writers can each append to a full history before observing peers.
  // Keep the visible window bounded without rejecting a valid CRDT merge.
  const changes = doc.getArray<SharedChange>("changes").toArray().slice(-32);
  if (
    changes.length > 32 ||
    changes.some(
      (c) =>
        !c ||
        typeof c.id !== "string" ||
        c.id.length > 80 ||
        typeof c.name !== "string" ||
        c.name.length > 80 ||
        !Number.isFinite(c.at) ||
        !Array.isArray(c.paths) ||
        c.paths.length > 64 ||
        c.paths.some((path) => typeof path !== "string" || path.length > 210) ||
        typeof c.kind !== "string" ||
        c.kind.length > 20,
    )
  )
    throw new Error("Invalid shared change history");
  return { files, identities, texts, deleted, runs, conflicts, changes };
}
export function newProject(files: Record<string, string>) {
  validateSource(files);
  const doc = new Y.Doc();
  doc.transact(() => {
    for (const [path, text] of Object.entries(files))
      createFile(doc, path, text);
  }, "initial");
  return doc;
}
export function createFile(doc: Y.Doc, path: string, text: string) {
  const id = crypto.randomUUID(),
    entry = new Y.Map<unknown>();
  entry.set("path", path);
  entry.set("text", new Y.Text(text));
  entry.set("deleted", false);
  doc.getMap<Y.Map<unknown>>("entries").set(id, entry);
  return id;
}
export function validateUpdate(doc: Y.Doc, update: Uint8Array) {
  const candidate = new Y.Doc();
  try {
    Y.applyUpdate(candidate, Y.encodeStateAsUpdate(doc));
    Y.applyUpdate(candidate, update);
    projectFromY(candidate);
  } finally {
    candidate.destroy();
  }
}
export function secureLink(
  origin: string,
  id: string,
  cap: string,
  secret: string,
) {
  return (
    origin +
    "/playground#" +
    new URLSearchParams({ room: id, cap, key: secret }).toString()
  );
}
export function parseSecureLink(raw: string, origin: string) {
  const url = new URL(raw),
    params = new URLSearchParams(url.hash.slice(1));
  const room = params.get("room"),
    cap = params.get("cap"),
    secret = params.get("key");
  if (
    url.origin !== origin ||
    url.pathname !== "/playground" ||
    !room ||
    !/^[a-f0-9]{24}$/.test(room) ||
    !cap ||
    !cap.startsWith(room + ".") ||
    !secret ||
    unb64(secret, 32).length !== 32
  )
    throw new Error("Use an encrypted Playground link from this site");
  return { room, cap, secret };
}
