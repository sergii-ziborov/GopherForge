import { randomUUID } from "node:crypto";
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate, removeAwarenessStates } from "y-protocols/awareness";
import * as decoding from "lib0/decoding";
import { Y, decrypt, encrypt, projectFromY, replaceText, createFile, validateUpdate } from "../../../website/src/lib/secure-collab.ts";
import { validateSource } from "../../../website/src/lib/playground-files.ts";
import { nickname, peerColor } from "../../../website/src/lib/playground-identity.ts";
import { sourceFingerprint } from "../../../website/src/lib/source-fingerprint.ts";

export class RoomFailure extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (code, message) => { throw new RoomFailure(code, message); };

export function parseRoomLink(raw, origin = "https://gopherforge.app") {
  try {
    const base = new URL(origin), url = new URL(raw);
    const local = base.protocol === "http:" && ["127.0.0.1", "[::1]"].includes(base.hostname);
    if ((!local && base.protocol !== "https:") || base.username || base.password || base.pathname !== "/" || base.search || base.hash)
      throw Error();
    if (url.origin !== base.origin || url.pathname !== "/playground" || url.search || url.username || url.password)
      throw Error();
    const params = new URLSearchParams(url.hash.slice(1));
    if (["room", "cap", "key"].some(k => params.getAll(k).length !== 1)) throw Error();
    const room = params.get("room"), cap = params.get("cap"), secret = params.get("key");
    if (!/^[a-f0-9]{24}$/.test(room) || !/^[a-f0-9]{24}\.[A-Za-z0-9_-]{32}$/.test(cap) || !cap.startsWith(room + ".") || !/^[A-Za-z0-9_-]{43}$/.test(secret) || Buffer.from(secret, "base64url").length !== 32)
      throw Error();
    return { room, cap, secret, origin: base.origin };
  } catch { fail("invalid_link", "Use a complete Encrypted Edit/View link from the configured GopherForge origin. Compatible links are not accepted."); }
}

export class EncryptedRoomClient {
  constructor({ roomLink, name, origin = "https://gopherforge.app", fetchImpl = fetch, pollMs = 2000 }) {
    this.link = parseRoomLink(roomLink, origin);
    this.name = name ? nickname(name) : undefined;
    this.fetch = fetchImpl;
    this.pollMs = pollMs;
    this.tail = Promise.resolve();
    this.status = "not_joined";
  }
  serial(fn) {
    const result = this.tail.then(fn);
    this.tail = result.catch(() => {});
    return result;
  }
  async api(body, token = this.token) {
    let response;
    try {
      response = await this.fetch(this.link.origin + "/api/playground/secure", {
        method: "POST", redirect: "error", credentials: "omit", cache: "no-store",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + token },
        body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
      });
    } catch { fail("relay_unavailable", "Cannot reach the encrypted GopherForge relay. Read again before retrying an edit."); }
    if (!response.ok) {
      const messages = {
        401: ["rejoin_required", "Participant session ended. Join the room again."],
        403: ["permission_denied", "This room capability does not permit that action."],
        409: ["source_conflict", "The room advanced. Read the current source and review your edit before retrying."],
        410: ["room_ended", "This room expired, closed or ended on a relay restart. Ask for a new link."],
        413: ["room_limit", "The encrypted room's source/history budget is full. Preserve a local copy."],
        429: ["relay_busy", "The room or relay is busy. Retry later."],
      };
      const [code, message] = messages[response.status] ?? ["relay_unavailable", "The encrypted relay could not complete the request."];
      fail(code, message);
    }
    if (!response.headers.get("content-type")?.includes("application/json")) fail("invalid_relay", "Expected a JSON relay response.");
    const reader = response.body.getReader(), chunks = [];
    let length = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        length += value.length;
        if (length > 8 * 1024 * 1024) { await reader.cancel(); fail("invalid_relay", "Relay response exceeds the client budget."); }
        chunks.push(value);
      }
      return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch (e) {
      if (e instanceof RoomFailure) throw e;
      fail("invalid_relay", "Could not read the encrypted relay response.");
    }
  }
  async apply(reply) {
    if (reply.id !== this.link.room || !Number.isSafeInteger(reply.head) || reply.head < this.head || !Array.isArray(reply.events) || reply.events.length > 256 || !Array.isArray(reply.participants) || reply.participants.length > 12)
      fail("invalid_relay", "Invalid encrypted room state.");
    const updates = [];
    try {
      if (reply.snapshot) updates.push(await decrypt(this.link.secret, reply.snapshot));
      for (const event of reply.events) updates.push(await decrypt(this.link.secret, event.packet));
      const candidate = new Y.Doc();
      try {
        Y.applyUpdate(candidate, Y.encodeStateAsUpdate(this.doc));
        for (const bytes of updates) Y.applyUpdate(candidate, bytes);
        projectFromY(candidate);
        const merged = Y.encodeStateAsUpdate(candidate);
        validateUpdate(this.doc, merged);
        Y.applyUpdate(this.doc, merged, "remote");
      } finally { candidate.destroy(); }
    } catch { fail("invalid_ciphertext", "Room data could not be authenticated or validated. The key may be wrong; no source was changed locally."); }
    this.head = reply.head;
    this.expiresAt = reply.expiresAt;
    const retained = new Set([this.doc.clientID]);
    for (const peer of reply.participants) {
      if (!peer.packet || peer.id === this.peer) continue;
      try {
        const bytes = await decrypt(this.link.secret, peer.packet, "presence");
        if (bytes.length > 16384) continue;
        const decoder = decoding.createDecoder(bytes), count = decoding.readVarUint(decoder), ids = [];
        if (count > 16) continue;
        for (let i = 0; i < count; i++) {
          const id = decoding.readVarUint(decoder); ids.push(id);
          decoding.readVarUint(decoder);
          const state = JSON.parse(decoding.readVarString(decoder));
          if (id === this.doc.clientID || (state !== null && (!state.user || nickname(state.user.name) !== state.user.name || !/^#[a-f0-9]{6}$/i.test(state.user.color)))) throw Error();
        }
        applyAwarenessUpdate(this.awareness, bytes, "remote");
        ids.forEach(id => retained.add(id));
      } catch { /* Invalid presence never discards authenticated source. */ }
    }
    removeAwarenessStates(this.awareness, [...this.awareness.getStates().keys()].filter(id => !retained.has(id)), "remote");
    this.status = "connected";
  }
  async ensureJoined() {
    if (!this.token) await this.joinInner(this.name);
  }
  async joinInner(name) {
    if (!name) fail("nickname_required", "Ask the person for a display nickname, then call playground_join with that nickname.");
    this.name = nickname(name);
    if (this.token) {
      this.awareness.setLocalStateField("user", { name: this.name, color: peerColor(String(this.doc.clientID)) });
      await this.refresh();
      return this.summary();
    }
    const reply = await this.api({ op: "join" }, this.link.cap);
    if (!["edit", "view"].includes(reply.role) || typeof reply.participantCapability !== "string") {
      if (reply.participantCapability) await this.api({ op: "leave" }, reply.participantCapability).catch(() => {});
      fail("permission_denied", "Use an Edit or View link, not the Owner capability.");
    }
    this.token = reply.participantCapability;
    this.role = reply.role;
    this.peer = reply.peer;
    this.head = 0;
    this.doc = new Y.Doc();
    this.awareness = new Awareness(this.doc);
    try {
      await this.apply(reply);
      this.awareness.setLocalStateField("user", { name: this.name, color: peerColor(String(this.doc.clientID)) });
      await this.refresh();
    } catch (e) { await this.leaveInner(); throw e; }
    if (this.pollMs) {
      this.timer = setInterval(() => {
        if (this.polling || !this.token) return;
        this.polling = true;
        void this.serial(() => this.refresh()).catch(() => { this.status = "offline"; }).finally(() => { this.polling = false; });
      }, this.pollMs);
      this.timer.unref();
    }
    return this.summary();
  }
  join(name = this.name) { return this.serial(() => this.joinInner(name)); }
  async refresh() {
    const presence = await encrypt(this.link.secret, encodeAwarenessUpdate(this.awareness, [this.doc.clientID]), "presence");
    await this.apply(await this.api({ op: "sync", after: this.head, presence }));
  }
  summary() {
    return { mode: "encrypted", room: this.link.room, role: this.role, nickname: this.name, expiresAt: this.expiresAt, status: this.status, keyLocation: "client_side", execution: "person_must_press_local_button" };
  }
  read() {
    return this.serial(async () => {
      await this.ensureJoined(); await this.refresh();
      const project = projectFromY(this.doc), sourceHash = await sourceFingerprint(project.files);
      return {
        ...this.summary(), sourceHash, files: project.files, identities: project.identities,
        participants: [...this.awareness.getStates()].flatMap(([id, state]) => state?.user ? [{ id: String(id), name: state.user.name, color: state.user.color }] : []),
        results: project.runs.map(run => ({ ...run, currentSource: run.sourceHash === sourceHash, evidence: "participant_reported_not_attested" })),
        changes: project.changes,
        requests: project.changes.filter(c => /^request (run|test)$/.test(c.kind) && typeof c.sourceHash === "string" && /^[a-f0-9]{64}$/.test(c.sourceHash)).map(c => {
          const phase = c.kind.slice(8), result = project.runs.findLast(r => r.phase === phase && r.sourceHash === c.sourceHash && r.at >= c.at);
          return { id: c.id, name: c.name, phase, sourceHash: c.sourceHash, at: c.at, currentSource: c.sourceHash === sourceHash, status: result ? "result_reported" : "awaiting_local_button", ...(result ? { resultId: result.id } : {}) };
        }),
        recovery: { deleted: project.deleted, conflicts: project.conflicts },
      };
    });
  }
  async publish(baseHash, mutate) {
    await this.ensureJoined(); await this.refresh();
    if (this.role !== "edit") fail("permission_denied", "A View link cannot publish source or run requests.");
    const current = projectFromY(this.doc), hash = await sourceFingerprint(current.files);
    if (hash !== baseHash) fail("source_conflict", "Source changed since playground_read. Read and review the current files before retrying.");
    const candidate = new Y.Doc();
    try {
      Y.applyUpdate(candidate, Y.encodeStateAsUpdate(this.doc));
      const detail = mutate(candidate, projectFromY(candidate));
      projectFromY(candidate);
      const snapshot = await encrypt(this.link.secret, Y.encodeStateAsUpdate(candidate));
      const reply = await this.api({ op: "publish", head: this.head, snapshot });
      await this.apply(reply);
      Y.applyUpdate(this.doc, Y.encodeStateAsUpdate(candidate), "remote");
      return { ...this.summary(), ...detail, sourceHash: await sourceFingerprint(projectFromY(this.doc).files), status: "published", executed: false };
    } finally { candidate.destroy(); }
  }
  record(doc, kind, paths, extra = {}) {
    const changes = doc.getArray("changes"), id = randomUUID();
    changes.push([{ id, name: this.name, at: Date.now(), kind, paths, ...extra }]);
    if (changes.length > 32) changes.delete(0, changes.length - 32);
    return id;
  }
  write(baseHash, files) {
    const next = validateSource(files);
    if (Object.values(next).some(text => !text.isWellFormed())) fail("invalid_source", "Source must contain well-formed Unicode text that can be preserved as UTF-8.");
    return this.serial(() => this.publish(baseHash, (doc, previous) => {
      const paths = [...new Set([...Object.keys(previous.files), ...Object.keys(next)])].filter(p => previous.files[p] !== next[p]);
      doc.transact(() => {
        for (const [path, text] of Object.entries(next)) {
          if (previous.texts.has(path)) replaceText(previous.texts.get(path), text);
          else createFile(doc, path, text);
        }
        for (const [path, id] of Object.entries(previous.identities)) if (!Object.hasOwn(next, path)) doc.getMap("entries").get(id).set("deleted", true);
        this.record(doc, "agent edit", paths);
      });
      return { changedPaths: paths };
    }));
  }
  requestRun(baseHash, phase) {
    if (!["run", "test"].includes(phase)) fail("invalid_phase", "Choose run or test.");
    return this.serial(() => this.publish(baseHash, doc => ({ requestId: this.record(doc, "request " + phase, ["main.go"], { sourceHash: baseHash }), phase, requestState: "awaiting_local_button", message: "Encrypted request recorded in Recent changes. Ask the person to review the source and press Run/Test locally; poll playground_read for reported results." })));
  }
  cursor(path, anchor, head = anchor) {
    return this.serial(async () => {
      await this.ensureJoined(); await this.refresh();
      const text = projectFromY(this.doc).texts.get(path);
      if (!text || !Number.isSafeInteger(anchor) || !Number.isSafeInteger(head) || Math.min(anchor, head) < 0 || Math.max(anchor, head) > text.length)
        fail("invalid_cursor", "Choose a current file and UTF-16 cursor offsets inside that file.");
      this.awareness.setLocalStateField("cursor", {
        anchor: Y.relativePositionToJSON(Y.createRelativePositionFromTypeIndex(text, anchor)),
        head: Y.relativePositionToJSON(Y.createRelativePositionFromTypeIndex(text, head)),
      });
      await this.refresh();
      return { ...this.summary(), path, anchor, head, sourceUnchanged: true };
    });
  }
  async leaveInner() {
    clearInterval(this.timer);
    const token = this.token;
    this.token = undefined;
    if (token) await this.api({ op: "leave" }, token).catch(() => {});
    this.awareness?.destroy(); this.doc?.destroy();
    this.awareness = undefined; this.doc = undefined; this.status = "left";
    return { left: true, roomClosed: false };
  }
  leave() { return this.serial(() => this.leaveInner()); }
}
