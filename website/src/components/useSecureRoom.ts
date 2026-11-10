"use client";
import { useEffect, useRef, useState } from "react";
import {
  Awareness,
  encodeAwarenessUpdate,
  applyAwarenessUpdate,
  removeAwarenessStates,
} from "y-protocols/awareness";
import * as decoding from "lib0/decoding";
import {
  Y,
  b64url,
  unb64,
  encryptionKey,
  encrypt,
  decrypt,
  newProject,
  projectFromY,
  createFile,
  replaceText,
  validateUpdate,
  secureLink,
  parseSecureLink,
  type SharedRun,
  type SharedChange,
} from "@/lib/secure-collab";
import { nickname } from "@/lib/playground-identity";
import type { CipherPacket } from "@/lib/secure-relay";
type Reply = {
  id: string;
  role: "owner" | "edit" | "view";
  peer: string;
  head: number;
  expiresAt: number;
  snapshot?: CipherPacket;
  snapshotSequence?: number;
  events: { sequence: number; id: string; packet: CipherPacket }[];
  participants: { id: string; role: string; packet?: CipherPacket }[];
  participantCapability?: string;
  capabilities?: { owner: string; edit: string; view: string };
};
type Session = {
  id: string;
  role: Reply["role"];
  peer: string;
  head: number;
  expiresAt: number;
  secret: string;
  token: string;
  links: Partial<Record<"owner" | "edit" | "view", string>>;
  doc: Y.Doc;
  base: Y.Doc;
  awareness: Awareness;
  pending: { id: string; bytes: Uint8Array; packet?: CipherPacket }[];
  lastSnapshot: number;
  busy: boolean;
  presenceDirty: boolean;
  presenceClock: number;
  epoch: number;
  listener?: () => void;
  renderKey?: string;
  sourceKey?: string;
  lastFiles?: Record<string, string>;
  lastChange?: { key: string; at: number };
};
export type SecureView = ReturnType<typeof projectFromY> & {
  id: string;
  role: Reply["role"];
  expiresAt: number;
  connected: boolean;
  peers: { name: string; color: string }[];
  links: Session["links"];
};
const colors = ["#63b8c4", "#f1b46b", "#a799ef", "#8bce93"];
function validatePresence(bytes: Uint8Array) {
  const d = decoding.createDecoder(bytes),
    count = decoding.readVarUint(d);
  if (count > 16) throw new Error("Too many cursors");
  for (let i = 0; i < count; i++) {
    decoding.readVarUint(d);
    decoding.readVarUint(d);
    const state = JSON.parse(decoding.readVarString(d));
    if (
      state !== null &&
      (!state.user ||
        typeof state.user.name !== "string" ||
        state.user.name.length > 60 ||
        !/^#[a-f0-9]{6}$/i.test(state.user.color ?? ""))
    )
      throw new Error("Invalid cursor identity");
  }
}
export function useSecureRoom(options: {
  onFiles: (
    files: Record<string, string>,
    identities: Record<string, string>,
    id: string,
  ) => void;
  onMessage: (message: string) => void;
}) {
  const callbacks = useRef(options);
  callbacks.current = options;
  const current = useRef<Session | null>(null),
    epoch = useRef(0),
    name = useRef("Browser " + Math.floor(Math.random() * 900 + 100));
  const [view, setView] = useState<SecureView | null>(null);
  function announce(message: string) {
    callbacks.current.onMessage(message);
  }
  function active(s: Session) {
    return current.current === s && s.epoch === epoch.current;
  }
  function emit(s: Session, connected = true) {
    if (!active(s)) return;
    const project = projectFromY(s.doc),
      peers = [...s.awareness.getStates().values()].flatMap((v) =>
        v?.user && typeof v.user.name === "string"
          ? [{ name: v.user.name, color: v.user.color }]
          : [],
      );
    const sourceKey = JSON.stringify([project.files, project.identities]),
      renderKey = JSON.stringify([
        sourceKey,
        project.deleted,
        project.runs,
        project.changes,
        peers,
        connected,
      ]);
    if (s.renderKey !== renderKey) {
      s.renderKey = renderKey;
      setView({
        ...project,
        id: s.id,
        role: s.role,
        expiresAt: s.expiresAt,
        connected,
        peers,
        links: s.links,
      });
    }
    if (s.sourceKey !== sourceKey) {
      s.sourceKey = sourceKey;
      callbacks.current.onFiles(project.files, project.identities, s.id);
    }
  }
  function persist(s: Session) {
    try {
      localStorage.setItem(
        "gopherforge.secure.draft." + s.id,
        b64url(Y.encodeStateAsUpdate(s.doc)),
      );
    } catch {
      announce(
        "Browser storage is unavailable. Export your current source before leaving.",
      );
    }
  }
  async function api(body: Record<string, unknown>, token = "") {
    const response = await fetch("/api/playground/secure", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: "Bearer " + token } : {}),
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
      cache: "no-store",
    });
    const data = await response.json();
    if (!response.ok)
      throw new Error(data.error ?? "Encrypted relay unavailable");
    return data as Reply;
  }
  async function apply(s: Session, response: Reply) {
    if (!active(s)) return;
    const updates: Uint8Array[] = [];
    if (response.snapshot)
      updates.push(await decrypt(s.secret, response.snapshot));
    for (const e of response.events)
      updates.push(await decrypt(s.secret, e.packet));
    if (!active(s)) return;
    // Validate combined source before mutating the visible document.
    const candidate = new Y.Doc();
    try {
      Y.applyUpdate(candidate, Y.encodeStateAsUpdate(s.base));
      for (const bytes of updates) Y.applyUpdate(candidate, bytes);
      projectFromY(candidate);
    } finally {
      candidate.destroy();
    }
    if (response.snapshot) {
      s.base.destroy();
      s.base = new Y.Doc();
    }
    for (const bytes of updates) {
      Y.applyUpdate(s.base, bytes, "remote");
      validateUpdate(s.doc, bytes);
      Y.applyUpdate(s.doc, bytes, "remote");
    }
    s.head = response.head;
    s.expiresAt = response.expiresAt;
    const retained = new Set<number>([s.doc.clientID]);
    for (const peer of response.participants) {
      if (!peer.packet || peer.id === s.peer) continue;
      try {
        const bytes = await decrypt(s.secret, peer.packet, "presence");
        validatePresence(bytes);
        applyAwarenessUpdate(s.awareness, bytes, "remote");
        const d = decoding.createDecoder(bytes),
          count = decoding.readVarUint(d);
        for (let i = 0; i < count; i++) {
          retained.add(decoding.readVarUint(d));
          decoding.readVarUint(d);
          decoding.readVarString(d);
        }
      } catch {
        /* A malformed cursor never discards valid source. */
      }
    }
    removeAwarenessStates(
      s.awareness,
      [...s.awareness.getStates().keys()].filter((id) => !retained.has(id)),
      "remote",
    );
    emit(s);
    persist(s);
  }
  function attach(s: Session) {
    current.current = s;
    s.lastFiles = projectFromY(s.doc).files;
    const updated = (bytes: Uint8Array, origin: unknown) => {
      if (!active(s)) return;
      if (origin !== "remote" && origin !== "initial" && s.role !== "view")
        s.pending.push({
          id: crypto.randomUUID(),
          bytes: new Uint8Array(bytes),
        });
      try {
        const files = projectFromY(s.doc).files,
          previous = s.lastFiles ?? files;
        const paths = [
          ...new Set([...Object.keys(previous), ...Object.keys(files)]),
        ].filter((path) => previous[path] !== files[path]);
        s.lastFiles = files;
        if (
          origin !== "remote" &&
          origin !== "initial" &&
          origin !== "attribution" &&
          s.role !== "view" &&
          paths.length
        ) {
          const key = JSON.stringify([name.current, paths]),
            at = Date.now();
          if (s.lastChange?.key !== key || at - s.lastChange.at > 2000) {
            s.lastChange = { key, at };
            const changes = s.doc.getArray<SharedChange>("changes");
            s.doc.transact(() => {
              changes.push([
                {
                  id: crypto.randomUUID(),
                  name: name.current,
                  at,
                  paths,
                  kind: "edit",
                },
              ]);
              if (changes.length > 32) changes.delete(0, changes.length - 32);
            }, "attribution");
          }
        }
        emit(s);
        persist(s);
      } catch (e) {
        announce(e instanceof Error ? e.message : "Invalid source change");
      }
    };
    s.doc.on("update", updated);
    s.listener = () => s.doc.off("update", updated);
    s.awareness.setLocalStateField("user", {
      name: name.current,
      color: colors[s.doc.clientID % colors.length],
    });
    s.awareness.on(
      "update",
      (
        _: { added: number[]; updated: number[]; removed: number[] },
        origin: unknown,
      ) => {
        if (origin !== "remote") {
          s.presenceDirty = true;
          s.presenceClock++;
        }
      },
    );
    emit(s);
  }
  function release(s: Session) {
    s.listener?.();
    s.awareness.destroy();
    s.doc.destroy();
    s.base.destroy();
  }
  function reset() {
    const prior = current.current;
    epoch.current++;
    current.current = null;
    setView(null);
    if (prior) release(prior);
  }
  async function join(raw: string, recover = true, displayName?: string) {
    if (displayName !== undefined) name.current = nickname(displayName);
    const parsed = parseSecureLink(raw, location.origin);
    reset();
    const generation = epoch.current;
    const response = await api({ op: "join" }, parsed.cap);
    if (generation !== epoch.current) return;
    const doc = new Y.Doc(),
      base = new Y.Doc(),
      awareness = new Awareness(doc);
    const s: Session = {
      id: response.id,
      role: response.role,
      peer: response.peer,
      head: 0,
      expiresAt: response.expiresAt,
      secret: parsed.secret,
      token: response.participantCapability!,
      links: response.role === "view" ? { view: raw } : { edit: raw },
      doc,
      base,
      awareness,
      pending: [],
      lastSnapshot: Date.now(),
      busy: false,
      presenceDirty: true,
      presenceClock: 0,
      epoch: generation,
    };
    try {
      const owner = JSON.parse(
        sessionStorage.getItem("gopherforge.secure.owner." + s.id) ?? "null",
      );
      if (owner?.owner) s.links = owner;
    } catch {}
    current.current = s;
    let saved: string | null = null;
    try {
      if (recover && s.role !== "view")
        saved = localStorage.getItem("gopherforge.secure.draft." + s.id);
    } catch {}
    try {
      await apply(s, response);
      if (recover && s.role !== "view") {
        if (saved) {
          const bytes = unb64(saved);
          validateUpdate(doc, bytes);
          Y.applyUpdate(doc, bytes, "recover");
          const missing = Y.encodeStateAsUpdate(doc, Y.encodeStateVector(base));
          if (missing.length > 2)
            s.pending.push({ id: crypto.randomUUID(), bytes: missing });
        }
      }
      attach(s);
      history.replaceState(null, "", raw);
      announce("Encrypted room joined. Source stays encrypted on the relay.");
    } catch (e) {
      if (active(s)) reset();
      throw e;
    }
  }
  async function create(
    files: Record<string, string>,
    ttlSeconds = 3600,
    displayName?: string,
  ) {
    if (displayName !== undefined) name.current = nickname(displayName);
    reset();
    const generation = epoch.current,
      doc = newProject(files),
      secret = encryptionKey();
    const initial = await encrypt(secret, Y.encodeStateAsUpdate(doc));
    const response = await api({ op: "create", snapshot: initial, ttlSeconds });
    if (generation !== epoch.current) {
      doc.destroy();
      return;
    }
    const caps = response.capabilities!;
    const links = Object.fromEntries(
      Object.entries(caps).map(([role, cap]) => [
        role,
        secureLink(location.origin, response.id, cap, secret),
      ]),
    );
    try {
      sessionStorage.setItem(
        "gopherforge.secure.owner." + response.id,
        JSON.stringify(links),
      );
    } catch {}
    doc.destroy();
    await join(links.edit, false);
  }
  async function sync(s: Session) {
    if (!active(s) || s.busy) return;
    s.busy = true;
    try {
      // Poll first, so a fresh server-only replica can compact even when an append is full.
      const read = await api({ op: "sync", after: s.head }, s.token);
      await apply(s, read);
      if (!active(s)) return;
      if (
        Date.now() - s.lastSnapshot > 5000 &&
        s.role !== "view" &&
        s.head > 0
      ) {
        const packet = await encrypt(s.secret, Y.encodeStateAsUpdate(s.base));
        if (!active(s)) return;
        try {
          await api({ op: "compact", head: s.head, snapshot: packet }, s.token);
          s.lastSnapshot = Date.now();
        } catch {
          /* Another editor advanced the room; the next poll retries. */
        }
      }
      // A long offline session can exceed a single delta packet. Publish a merged
      // full snapshot with compare-and-swap, preserving concurrent server edits.
      if (
        s.role !== "view" &&
        s.pending.some((item) => item.bytes.length > 256 * 1024)
      ) {
        const ids = new Set(s.pending.map((item) => item.id));
        const merged = await encrypt(s.secret, Y.encodeStateAsUpdate(s.doc));
        const published = await api(
          { op: "publish", head: s.head, snapshot: merged },
          s.token,
        );
        if (!active(s)) return;
        s.pending = s.pending.filter((item) => !ids.has(item.id));
        const refreshed = await api({ op: "sync" }, s.token);
        await apply(s, refreshed);
        if (!active(s)) return;
        s.head = Math.max(s.head, published.head);
        s.lastSnapshot = Date.now();
      }
      const batch: Session["pending"] = [];
      let bytes = 0;
      for (const item of s.pending) {
        if (!item.packet) item.packet = await encrypt(s.secret, item.bytes);
        if (bytes + item.packet.data.length > 1400 * 1024 && batch.length)
          break;
        batch.push(item);
        bytes += item.packet.data.length;
        if (batch.length >= 16) break;
      }
      const presenceClock = s.presenceClock;
      const presence = s.presenceDirty
        ? await encrypt(
            s.secret,
            encodeAwarenessUpdate(s.awareness, [s.doc.clientID]),
            "presence",
          )
        : undefined;
      if (!batch.length && !presence) return;
      if (!active(s)) return;
      const result = await api(
        {
          op: "sync",
          after: s.head,
          updates: batch.map((x) => ({ id: x.id, packet: x.packet })),
          ...(presence ? { presence } : {}),
        },
        s.token,
      );
      await apply(s, result);
      if (!active(s)) return;
      const ids = new Set(batch.map((x) => x.id));
      s.pending = s.pending.filter((x) => !ids.has(x.id));
      if (s.presenceClock === presenceClock) s.presenceDirty = false;
    } catch (e) {
      if (active(s)) {
        emit(s, false);
        announce(
          (e instanceof Error ? e.message : "Offline") +
            ". Your local edits are kept.",
        );
      }
    } finally {
      s.busy = false;
    }
  }
  useEffect(() => {
    const timer = setInterval(() => {
      const s = current.current;
      if (s) void sync(s);
    }, 700);
    return () => {
      clearInterval(timer);
      const s = current.current;
      current.current = null;
      epoch.current++;
      if (s) release(s);
    };
  }, []);
  function change(action: (s: Session) => void) {
    const s = current.current;
    if (!s) return;
    try {
      if (s.role === "view") throw new Error("This room is read-only");
      s.doc.transact(() => action(s), "local");
      projectFromY(s.doc);
    } catch (e) {
      announce(
        e instanceof Error ? e.message : "Could not edit encrypted room",
      );
    }
  }
  function editFile(path: string, text: string) {
    const s = current.current;
    if (!s) return;
    const project = projectFromY(s.doc);
    const y = project.texts.get(path);
    if (y && s.role !== "view")
      s.doc.transact(() => replaceText(y, text), "local");
  }
  function replaceFiles(files: Record<string, string>) {
    change((s) => {
      const project = projectFromY(s.doc),
        entries = s.doc.getMap<Y.Map<unknown>>("entries");
      for (const [path, id] of Object.entries(project.identities))
        if (!Object.hasOwn(files, path)) entries.get(id)!.set("deleted", true);
      for (const [path, text] of Object.entries(files)) {
        const existing = project.texts.get(path);
        if (existing) replaceText(existing, text);
        else createFile(s.doc, path, text);
      }
    });
  }
  function rename(from: string, to: string) {
    change((s) => {
      const project = projectFromY(s.doc),
        entries = s.doc.getMap<Y.Map<unknown>>("entries");
      for (const [path, id] of Object.entries(project.identities))
        if (path === from || path.startsWith(from + "/"))
          entries.get(id)!.set("path", to + path.slice(from.length));
    });
  }
  function deletePath(path: string) {
    change((s) => {
      const project = projectFromY(s.doc),
        entries = s.doc.getMap<Y.Map<unknown>>("entries");
      for (const [name, id] of Object.entries(project.identities))
        if (name === path || name.startsWith(path + "/"))
          entries.get(id)!.set("deleted", true);
    });
  }
  function restore(id: string) {
    change((s) =>
      s.doc.getMap<Y.Map<unknown>>("entries").get(id)?.set("deleted", false),
    );
  }
  function publishRun(run: SharedRun) {
    change((s) => {
      const runs = s.doc.getArray<SharedRun>("runs");
      runs.push([run]);
      if (runs.length > 16) runs.delete(0, runs.length - 16);
    });
  }
  async function leave() {
    const s = current.current;
    if (!s) return;
    persist(s);
    reset();
    history.replaceState(null, "", "/playground");
    try {
      await api({ op: "leave" }, s.token);
    } catch {}
    announce(
      "Room left. Local source and encrypted-room recovery drafts are kept.",
    );
  }
  async function close() {
    const s = current.current;
    if (!s?.links.owner)
      throw new Error("Keep the creating tab to close this room");
    const parsed = parseSecureLink(s.links.owner, location.origin);
    await api({ op: "close" }, parsed.cap);
    await leave();
    announce("Encrypted room closed. Independent source copies remain.");
  }
  return {
    view,
    doc: current.current?.doc,
    awareness: current.current?.awareness,
    create,
    join,
    setName: (value: string) => {
      name.current = nickname(value);
      const s = current.current;
      if (s) {
        const user = s.awareness.getLocalState()?.user;
        s.awareness.setLocalStateField("user", { ...user, name: name.current });
        emit(s);
      }
    },
    editFile,
    replaceFiles,
    rename,
    deletePath,
    restore,
    publishRun,
    leave,
    close,
  };
}
