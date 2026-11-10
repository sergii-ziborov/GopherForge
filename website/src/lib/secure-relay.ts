// Versioned encrypted browser relay. The legacy native /api/playground contract is separate.
import { createHash, randomBytes } from "node:crypto";
import { RelayError, assert } from "./playground-core.ts";
export type CipherPacket = { iv: string; data: string };
type Role = "owner" | "edit" | "view";
type Event = { sequence: number; id: string; packet: CipherPacket };
type Room = {
  id: string;
  expiresAt: number;
  head: number;
  snapshotSequence: number;
  snapshot: CipherPacket;
  events: Event[];
  grants: Map<string, { role: Role; peer?: string }>;
  peers: Map<string, { role: Role; seenAt: number; presence?: CipherPacket }>;
  seen: Map<string, string>;
};
const state = globalThis as typeof globalThis & {
  gopherforgeSecureRoomsV2?: Map<string, Room>;
};
const rooms = () => (state.gopherforgeSecureRoomsV2 ??= new Map());
const digest = (s: string) => createHash("sha256").update(s).digest("hex");
const secret = () => randomBytes(24).toString("base64url");
const bytes = (p: CipherPacket) => p.data.length + p.iv.length;
export const secureLimits = {
  rooms: 32,
  peers: 12,
  packetBytes: 256 * 1024,
  snapshotBytes: 1536 * 1024,
  roomBytes: 3 * 1024 * 1024,
  residentBytes: 32 * 1024 * 1024,
  events: 256,
};
function packet(value: unknown, max: number): CipherPacket {
  assert(
    value && typeof value === "object" && !Array.isArray(value),
    "Use an encrypted packet",
  );
  const p = value as CipherPacket;
  assert(
    typeof p.iv === "string" &&
      /^[A-Za-z0-9_-]{16}$/.test(p.iv) &&
      typeof p.data === "string" &&
      /^[A-Za-z0-9_-]+$/.test(p.data) &&
      p.data.length <= Math.ceil(((max + 16) * 4) / 3) &&
      Buffer.from(p.data, "base64url").length >= 16,
    "Invalid encrypted packet",
    413,
  );
  return { iv: p.iv, data: p.data };
}
function prune() {
  for (const [id, r] of rooms()) {
    if (r.expiresAt <= Date.now()) {
      rooms().delete(id);
      continue;
    }
    for (const [peer, p] of r.peers)
      if (Date.now() - p.seenAt > 90000) {
        r.peers.delete(peer);
        for (const [hash, g] of r.grants)
          if (g.peer === peer) r.grants.delete(hash);
      }
  }
}
function size(r: Room) {
  return bytes(r.snapshot) + r.events.reduce((n, e) => n + bytes(e.packet), 0);
}
function capacity(extra = 0, except?: Room) {
  assert(
    [...rooms().values()].reduce(
      (n, r) => n + (r === except ? 0 : size(r)),
      0,
    ) +
      extra <=
      secureLimits.residentBytes,
    "Encrypted relay is full. Keep a local copy and retry later.",
    503,
  );
}
function auth(token: unknown) {
  prune();
  assert(
    typeof token === "string" && token.length <= 120,
    "A room capability is required",
    401,
  );
  const r = rooms().get(token.split(".")[0]);
  assert(
    r,
    "Room expired, was closed or ended on a relay restart. Your local copy is kept.",
    410,
  );
  const grant = r.grants.get(digest(token));
  assert(grant, "Invalid room capability", 403);
  if (grant.peer) {
    const peer = r.peers.get(grant.peer);
    assert(peer, "Reconnect this participant", 401);
    peer.seenAt = Date.now();
  }
  return { room: r, ...grant };
}
function snapshot(
  r: Room,
  role: Role,
  peer: string | undefined,
  after: unknown,
) {
  assert(
    after === undefined || (Number.isSafeInteger(after) && Number(after) >= 0),
    "Invalid source cursor",
  );
  const reset = after === undefined || Number(after) < r.snapshotSequence;
  return {
    id: r.id,
    role,
    peer,
    head: r.head,
    expiresAt: r.expiresAt,
    ...(reset
      ? { snapshot: r.snapshot, snapshotSequence: r.snapshotSequence }
      : {}),
    events: r.events.filter(
      (e) => e.sequence > (reset ? r.snapshotSequence : Number(after)),
    ),
    participants: [...r.peers].map(([id, p]) => ({
      id,
      role: p.role,
      ...(p.presence ? { packet: p.presence } : {}),
    })),
  };
}
export function secureAction(
  input: Record<string, unknown>,
  token?: string,
): Record<string, unknown> {
  prune();
  const op = input.op;
  if (op === "create") {
    assert(rooms().size < secureLimits.rooms, "Encrypted relay is full", 503);
    const initial = packet(input.snapshot, secureLimits.snapshotBytes);
    capacity(bytes(initial));
    const id = randomBytes(12).toString("hex");
    const ttl = Number(input.ttlSeconds ?? 3600);
    assert(
      Number.isSafeInteger(ttl) && ttl >= 60 && ttl <= 86400,
      "Choose a room lifetime between one minute and 24 hours",
    );
    const caps = {
      owner: id + "." + secret(),
      edit: id + "." + secret(),
      view: id + "." + secret(),
    };
    const room: Room = {
      id,
      expiresAt: Date.now() + ttl * 1000,
      head: 0,
      snapshotSequence: 0,
      snapshot: initial,
      events: [],
      grants: new Map(
        Object.entries(caps).map(([role, value]) => [
          digest(value),
          { role: role as Role },
        ]),
      ),
      peers: new Map(),
      seen: new Map(),
    };
    rooms().set(id, room);
    return { id, expiresAt: room.expiresAt, capabilities: caps };
  }
  const { room: r, role, peer } = auth(token);
  if (op === "join") {
    assert(
      r.peers.size < secureLimits.peers,
      "Room has 12 active participants",
      429,
    );
    const id = secret(),
      seat = r.id + "." + secret();
    r.peers.set(id, { role, seenAt: Date.now() });
    r.grants.set(digest(seat), { role, peer: id });
    return { ...snapshot(r, role, id, undefined), participantCapability: seat };
  }
  if (op === "close") {
    assert(role === "owner", "Only the owner can close the room", 403);
    rooms().delete(r.id);
    return { closed: true };
  }
  if (op === "leave") {
    if (peer) {
      r.peers.delete(peer);
      r.grants.delete(digest(token!));
    }
    return { left: true };
  }
  assert(peer, "Join before syncing", 403);
  if (op === "compact" || op === "publish") {
    assert(role !== "view", "This link is view-only", 403);
    assert(
      input.head === r.head,
      "Source advanced before this snapshot. Retry after syncing.",
      409,
    );
    const next = packet(input.snapshot, secureLimits.snapshotBytes);
    capacity(bytes(next), r);
    if (op === "publish") r.head++;
    r.snapshot = next;
    r.snapshotSequence = r.head;
    r.events = [];
    return snapshot(r, role, peer, r.head);
  }
  assert(op === "sync", "Unknown encrypted-room operation");
  if (input.presence) {
    r.peers.get(peer)!.presence = packet(input.presence, 16 * 1024);
  }
  if (input.updates !== undefined) {
    assert(
      Array.isArray(input.updates) && input.updates.length <= 32,
      "Use up to 32 encrypted updates",
    );
    if (input.updates.length)
      assert(role !== "view", "This link is view-only", 403);
    const pending: Event[] = [];
    for (const value of input.updates as {
      id: string;
      packet: CipherPacket;
    }[]) {
      assert(
        value &&
          typeof value.id === "string" &&
          /^[a-zA-Z0-9_-]{8,80}$/.test(value.id),
        "Invalid update identity",
      );
      const p = packet(value.packet, secureLimits.packetBytes),
        hash = digest(JSON.stringify(p)),
        seen = r.seen.get(value.id);
      if (seen) {
        assert(seen === hash, "An update identity cannot be reused", 409);
        continue;
      }
      assert(
        !pending.some((x) => x.id === value.id),
        "Duplicate update identity",
      );
      pending.push({
        id: value.id,
        sequence: r.head + pending.length + 1,
        packet: p,
      });
    }
    assert(
      r.events.length + pending.length <= secureLimits.events,
      "Sync and compact before sending more changes",
      409,
    );
    const nextSize = size(r) + pending.reduce((n, e) => n + bytes(e.packet), 0);
    assert(
      nextSize <= secureLimits.roomBytes,
      "Room history is full. Sync and compact, or export a copy.",
      413,
    );
    capacity(nextSize, r);
    for (const e of pending) {
      r.events.push(e);
      r.head = e.sequence;
      r.seen.set(e.id, digest(JSON.stringify(e.packet)));
    }
    while (r.seen.size > 2048) r.seen.delete(r.seen.keys().next().value!);
  }
  return snapshot(r, role, peer, input.after);
}
