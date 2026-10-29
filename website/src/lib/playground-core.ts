import { createHash, randomBytes } from "node:crypto";

// One bounded relay process. No shell, compiler, eval, or server execution.
export const roomLimits = {
  rooms: 32,
  files: 32,
  sourceBytes: 256 * 1024,
  fileBytes: 64 * 1024,
  participants: 24,
  runs: 32,
  outputBytes: 64 * 1024,
  ttlSeconds: 3600,
};
export class RelayError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}
export function assert(
  condition: unknown,
  message: string,
  status = 400,
): asserts condition {
  if (!condition) throw new RelayError(message, status);
}
const secret = () => randomBytes(24).toString("base64url");
const digest = (value: string) =>
  createHash("sha256").update(value).digest("hex");
export const sourceDigest = (files: Record<string, string>) =>
  digest(
    JSON.stringify(
      Object.entries(files).sort(([a], [b]) => a.localeCompare(b, "en")),
    ),
  );
export type Role = "owner" | "edit" | "view";
type Participant = {
  id: string;
  name: string;
  kind: "web" | "native" | "agent";
  role: Role;
  seenAt: number;
};
export type RoomRun = {
  id: string;
  participantID: string;
  device: string;
  revision: number;
  sourceDigest: string;
  phase: "run" | "test";
  status: "running" | "finished" | "failed";
  stdout: string;
  stderr: string;
  startedAt: number;
  finishedAt?: number;
};
type RunRequest = {
  id: string;
  revision: number;
  phase: "run" | "test";
  requestedAt: number;
  requestedBy: string;
  targetID?: string;
};
type Room = {
  id: string;
  title: string;
  expiresAt: number;
  revision: number;
  files: Record<string, string>;
  credentials: Map<string, { role: Role; participantID?: string }>;
  participants: Map<string, Participant>;
  runs: RoomRun[];
  requests: RunRequest[];
};
type State = { rooms: Map<string, Room> };
const globalState = globalThis as typeof globalThis & {
  gopherForgeRelay?: State;
};
function state(): State {
  return (globalState.gopherForgeRelay ??= { rooms: new Map() });
}
function prune() {
  for (const [id, room] of state().rooms)
    if (room.expiresAt <= Date.now()) state().rooms.delete(id);
}
export function validateFiles(value: unknown): Record<string, string> {
  assert(
    value && typeof value === "object" && !Array.isArray(value),
    "Files must be an object.",
  );
  const entries = Object.entries(value);
  assert(
    entries.length > 0 && entries.length <= roomLimits.files,
    "Use 1–32 text files.",
  );
  let bytes = 0;
  for (const [path, text] of entries) {
    assert(
      /^[a-zA-Z0-9_./-]{1,180}$/.test(path) &&
        !path.startsWith("/") &&
        path
          .split("/")
          .every((p) => p && p !== "." && p !== ".." && p !== "__proto__"),
      "Use safe relative file names.",
    );
    assert(
      typeof text === "string" && !text.includes("\0"),
      "Only UTF-8 text files are supported.",
    );
    const size = Buffer.byteLength(text);
    assert(size <= roomLimits.fileBytes, "Each file must be at most 64 KiB.");
    bytes += size;
  }
  assert(
    bytes <= roomLimits.sourceBytes,
    "The shared source limit is 256 KiB.",
  );
  assert(
    typeof (value as Record<string, string>)["main.go"] === "string",
    "Keep main.go as the Playground entry point.",
  );
  return Object.fromEntries(entries) as Record<string, string>;
}
export function authenticate(capability: unknown) {
  prune();
  assert(
    typeof capability === "string" && capability.length <= 180,
    "A room capability is required.",
    401,
  );
  const [id] = capability.split(".");
  const room = state().rooms.get(id);
  assert(
    room,
    "This room expired, was closed, or ended when the relay restarted. Your local copy is still yours.",
    410,
  );
  const grant = room.credentials.get(digest(capability));
  assert(grant, "This room capability is invalid or revoked.", 403);
  if (grant.participantID) {
    const participant = room.participants.get(grant.participantID);
    if (participant) participant.seenAt = Date.now();
  }
  return { room, ...grant };
}
function writable(role: Role) {
  assert(role !== "view", "This is a view-only link.", 403);
}
function integer(value: unknown): number {
  assert(
    Number.isSafeInteger(value) && Number(value) >= 0,
    "A valid source revision is required.",
  );
  return value as number;
}
function phase(value: unknown): "run" | "test" {
  assert(value === "run" || value === "test", "Choose run or test.");
  return value;
}
function text(value: unknown, max: number): string {
  assert(
    typeof value === "string" && value.length <= max,
    "Text exceeds this field's limit.",
  );
  return value;
}
function snapshot(room: Room, role: Role, participantID?: string) {
  const now = Date.now();
  return {
    id: room.id,
    title: room.title,
    expiresAt: room.expiresAt,
    revision: room.revision,
    sourceDigest: sourceDigest(room.files),
    files: room.files,
    role,
    participantID: participantID ?? null,
    participants: [...room.participants.values()].filter(
      (p) => now - p.seenAt < 45_000,
    ),
    runs: room.runs,
    requests: room.requests.filter((r) => now - r.requestedAt < 120_000),
    execution:
      "Only a person pressing Run/Test in the native app starts a local build. The relay never executes code.",
  };
}
function trimOutput(room: Room) {
  let bytes = room.runs.reduce((n, r) => n + Buffer.byteLength(r.stdout) + Buffer.byteLength(r.stderr), 0);
  while (bytes > 256 * 1024) {
    const index = room.runs.findIndex(r => r.status !== "running");
    if (index < 0) break;
    const [removed] = room.runs.splice(index, 1);
    bytes -= Buffer.byteLength(removed.stdout) + Buffer.byteLength(removed.stderr);
  }
}
export function roomAction(
  input: Record<string, unknown>,
  capability?: string,
) {
  prune();
  const op = input.op;
  if (op === "create") {
    assert(
      state().rooms.size < roomLimits.rooms,
      "The temporary relay is full. Keep your copy and try later.",
      503,
    );
    const files = validateFiles(input.files);
    const ttl =
      input.ttlSeconds === undefined
        ? roomLimits.ttlSeconds
        : integer(input.ttlSeconds);
    assert(
      ttl >= 60 && ttl <= 86400,
      "Choose a room lifetime from one minute to 24 hours.",
    );
    const id = randomBytes(12).toString("hex");
    const capabilities = {
      owner: id + "." + secret(),
      edit: id + "." + secret(),
      view: id + "." + secret(),
    };
    const room: Room = {
      id,
      title: text(input.title ?? "Go Playground", 80),
      files,
      revision: 0,
      expiresAt: Date.now() + ttl * 1000,
      credentials: new Map(),
      participants: new Map(),
      runs: [],
      requests: [],
    };
    for (const [role, token] of Object.entries(capabilities))
      room.credentials.set(digest(token), { role: role as Role });
    state().rooms.set(id, room);
    return { ...snapshot(room, "owner"), capabilities };
  }
  const { room, role, participantID } = authenticate(
    capability ?? input.capability,
  );
  if (op === "read") return snapshot(room, role, participantID);
  if (op === "join") {
    for (const [id, p] of room.participants)
      if (Date.now() - p.seenAt > 300_000) {
        room.participants.delete(id);
        for (const [key, grant] of room.credentials)
          if (grant.participantID === id) room.credentials.delete(key);
      }
    assert(
      room.participants.size < roomLimits.participants,
      "This room has reached its participant limit.",
      429,
    );
    assert(
      ["web", "native", "agent"].includes(String(input.kind)),
      "Unknown participant kind.",
    );
    const id = secret(),
      token = room.id + "." + secret();
    const name = text(input.name ?? "Guest", 50).trim() || "Guest";
    room.participants.set(id, {
      id,
      name,
      kind: input.kind as Participant["kind"],
      role,
      seenAt: Date.now(),
    });
    // A joined seat cannot close the room, even if created from an owner link.
    const seatRole = role === "owner" ? "edit" : role;
    room.credentials.set(digest(token), { role: seatRole, participantID: id });
    return { ...snapshot(room, seatRole, id), participantCapability: token };
  }
  if (op === "write") {
    writable(role);
    assert(
      integer(input.revision) === room.revision,
      "Source changed elsewhere. Your draft was kept; review the latest source before publishing.",
      409,
    );
    room.files = validateFiles(input.files);
    room.revision++;
    return snapshot(room, role, participantID);
  }
  if (op === "request_run") {
    writable(role);
    assert(
      integer(input.revision) === room.revision,
      "Read the current source before asking to run it.",
      409,
    );
    room.requests = room.requests.filter(
      (r) => Date.now() - r.requestedAt < 120_000,
    );
    assert(
      room.requests.length < 8,
      "Wait for an existing run request to be handled.",
      429,
    );
    const targetID =
      input.targetID === undefined ? undefined : text(input.targetID, 100);
    if (targetID)
      assert(
        room.participants.get(targetID)?.kind === "native",
        "That native device is not connected.",
      );
    const request: RunRequest = {
      id: secret(),
      revision: room.revision,
      phase: phase(input.phase),
      requestedAt: Date.now(),
      requestedBy: participantID ?? "AI / link holder",
      ...(targetID ? { targetID } : {}),
    };
    room.requests.push(request);
    return {
      request,
      state: "awaiting_local_button",
      message:
        "No code was executed. A person must press Run/Test on their native device. Read the room again for the result.",
    };
  }
  if (op === "begin_run") {
    writable(role);
    const p = participantID && room.participants.get(participantID);
    assert(
      p && p.kind === "native",
      "Only a joined native device can publish a local run.",
      403,
    );
    assert(
      integer(input.revision) === room.revision,
      "Publish or reload the current source before running.",
      409,
    );
    assert(
      !room.runs.some(
        (r) => r.participantID === participantID && r.status === "running",
      ),
      "This device already has an unfinished run. Finish it or reconnect with a new seat.",
      409,
    );
    assert(room.runs.filter(r => r.status === "running").length < 24, "This room has 24 unfinished device runs. Keep a copy and create another room if those devices cannot finish.", 429);
    const run: RoomRun = {
      id: secret(),
      participantID,
      device: p.name,
      revision: room.revision,
      sourceDigest: sourceDigest(room.files),
      phase: phase(input.phase),
      status: "running",
      stdout: "",
      stderr: "",
      startedAt: Date.now(),
    };
    room.runs.push(run);
    const running = room.runs.filter((r) => r.status === "running");
    const finished = room.runs
      .filter((r) => r.status !== "running")
      .slice(-(roomLimits.runs - running.length));
    room.runs = [...finished, ...running].sort(
      (a, b) => a.startedAt - b.startedAt,
    );
    if (typeof input.requestID === "string")
      room.requests = room.requests.filter(
        (r) =>
          !(
            r.id === input.requestID &&
            r.revision === room.revision &&
            (!r.targetID || r.targetID === participantID)
          ),
      );
    return { run, files: room.files };
  }
  if (op === "finish_run") {
    const run = room.runs.find((r) => r.id === input.runID);
    assert(
      run && participantID === run.participantID,
      "A device can only finish its own run.",
      403,
    );
    const stdout = text(input.stdout ?? "", roomLimits.outputBytes),
      stderr = text(input.stderr ?? "", roomLimits.outputBytes);
    assert(
      Buffer.byteLength(stdout) <= roomLimits.outputBytes &&
        Buffer.byteLength(stderr) <= roomLimits.outputBytes,
      "Output exceeds 64 KiB per stream.",
    );
    assert(
      typeof input.succeeded === "boolean",
      "A result status is required.",
    );
    if (run.status !== "running") {
      assert(
        run.stdout === stdout &&
          run.stderr === stderr &&
          (run.status === "finished") === input.succeeded,
        "This result is already final.",
        409,
      );
      return snapshot(room, role, participantID);
    }
    Object.assign(run, {
      stdout,
      stderr,
      status: input.succeeded ? "finished" : "failed",
      finishedAt: Date.now(),
    });
    trimOutput(room);
    return snapshot(room, role, participantID);
  }
  if (op === "close") {
    assert(
      role === "owner",
      "Only the owner capability can close this room.",
      403,
    );
    state().rooms.delete(room.id);
    return { closed: true };
  }
  throw new RelayError("Unknown room action.");
}
