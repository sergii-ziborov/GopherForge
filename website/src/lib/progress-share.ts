import { createHash, randomBytes } from "node:crypto";
import { mkdir, readFile, writeFile, readdir, unlink, stat } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { assert } from "./playground-core.ts";

export type LearningSnapshot = {
  schemaVersion: 1;
  source: "app" | "web";
  sharedAt: string;
  completed: string[];
  compilerVerified: string[];
  assessments: Record<string, "understood" | "revisit">;
  lastLessonID: string | null;
  lastInterviewID: string | null;
};
const id = (v: unknown): v is string =>
  typeof v === "string" && /^[a-zA-Z0-9._:-]{1,160}$/.test(v);
export function parseSnapshot(value: unknown): LearningSnapshot {
  assert(
    value && typeof value === "object" && !Array.isArray(value),
    "Invalid progress snapshot.",
  );
  const v = value as Record<string, unknown>;
  assert(
    v.schemaVersion === 1 && ["app", "web"].includes(String(v.source)),
    "Unsupported progress snapshot.",
  );
  for (const key of ["completed", "compilerVerified"])
    assert(
      Array.isArray(v[key]) &&
        (v[key] as unknown[]).length <= 1000 &&
        (v[key] as unknown[]).every(id),
      "Invalid lesson IDs.",
    );
  assert(
    v.assessments &&
      typeof v.assessments === "object" &&
      !Array.isArray(v.assessments) &&
      Object.keys(v.assessments).length <= 1000 &&
      Object.entries(v.assessments).every(
        ([k, mark]) =>
          id(k) && ["understood", "revisit"].includes(String(mark)),
      ),
    "Invalid interview marks.",
  );
  assert(
    (v.lastLessonID === null || id(v.lastLessonID)) &&
      (v.lastInterviewID === null || id(v.lastInterviewID)),
    "Invalid saved place.",
  );
  const completed = [...new Set(v.completed as string[])];
  const verified = [...new Set(v.compilerVerified as string[])];
  assert(
    verified.every((x) => completed.includes(x)),
    "Compiler marks must belong to completed lessons.",
  );
  assert(
    v.source === "app" || verified.length === 0,
    "Web marks are self-reported.",
  );
  // Whitelist fields: no code, attempt history, names, device IDs or credentials.
  return {
    schemaVersion: 1,
    source: v.source as "app" | "web",
    sharedAt: new Date().toISOString(),
    completed,
    compilerVerified: verified,
    assessments: v.assessments as LearningSnapshot["assessments"],
    lastLessonID: v.lastLessonID as string | null,
    lastInterviewID: v.lastInterviewID as string | null,
  };
}
const folder = () =>
  process.env.GOPHERFORGE_SHARE_DIR ??
  join(tmpdir(), "gopherforge-progress-shares");
const hash = (v: string) => createHash("sha256").update(v).digest("hex");
type Stored = {
  snapshot: LearningSnapshot;
  expiresAt: string;
  revokeHash: string;
};
const validShareID = (id: string) => /^[a-f0-9]{32}$/.test(id);
const publisher = globalThis as typeof globalThis & { gopherForgeShareQueue?: Promise<void> };
export async function publishProgress(value: unknown) {
  const previous = publisher.gopherForgeShareQueue ?? Promise.resolve();
  let unlock!: () => void;
  publisher.gopherForgeShareQueue = new Promise<void>(resolve => { unlock = resolve; });
  await previous;
  try { return await publishUnlocked(value); } finally { unlock(); }
}
async function publishUnlocked(value: unknown) {
  const snapshot = parseSnapshot(value),
    dir = folder();
  assert(Buffer.byteLength(JSON.stringify(snapshot)) <= 32 * 1024, "A progress snapshot must fit within 32 KiB.");
  await mkdir(dir, { recursive: true, mode: 0o700 });
  // Opportunistic cleanup complements the deployment’s daily retention timer.
  const names = (await readdir(dir)).filter((n) =>
    /^[a-f0-9]{32}\.json$/.test(n),
  );
  if (names.length > 0)
    for (const name of names) {
      try {
        const v = JSON.parse(await readFile(join(dir, name), "utf8")) as Stored;
        if (Date.parse(v.expiresAt) <= Date.now())
          await unlink(join(dir, name));
      } catch {
        /* preserve unreadable records for inspection */
      }
    }
  assert(
    (await readdir(dir)).length < 10_000,
    "The sharing service is full. Download your progress instead.",
    503,
  );
  const sizes = await Promise.all((await readdir(dir)).filter(n => /^[a-f0-9]{32}\.json$/.test(n)).map(async n => (await stat(join(dir, n))).size));
  assert(sizes.reduce((sum, n) => sum + n, 0) + Buffer.byteLength(JSON.stringify(snapshot)) + 512 <= 32 * 1024 * 1024, "The sharing storage budget is full. Download your progress instead.", 503);
  const shareID = randomBytes(16).toString("hex"),
    revokeToken = randomBytes(24).toString("base64url");
  const expiresAt = new Date(Date.now() + 90 * 86400_000).toISOString();
  await writeFile(
    join(dir, shareID + ".json"),
    JSON.stringify({ snapshot, expiresAt, revokeHash: hash(revokeToken) }),
    { flag: "wx", mode: 0o600 },
  );
  return {
    shareID,
    revokeToken,
    expiresAt,
    path: "/progress/" + shareID,
    jsonPath: "/api/progress-shares/" + shareID,
  };
}
export async function readSharedProgress(
  shareID: string,
): Promise<{ snapshot: LearningSnapshot; expiresAt: string } | null> {
  if (!validShareID(shareID)) return null;
  try {
    const value = JSON.parse(
      await readFile(join(folder(), shareID + ".json"), "utf8"),
    ) as Stored;
    if (Date.parse(value.expiresAt) <= Date.now()) { await unlink(join(folder(), shareID + ".json")); return null; }
    return { snapshot: value.snapshot, expiresAt: value.expiresAt };
  } catch {
    return null;
  }
}
export async function revokeProgress(shareID: string, token: unknown) {
  assert(
    validShareID(shareID) && typeof token === "string" && token.length <= 100,
    "Invalid revocation key.",
    403,
  );
  let value: Stored;
  try {
    value = JSON.parse(
      await readFile(join(folder(), shareID + ".json"), "utf8"),
    );
  } catch {
    return { revoked: true };
  }
  assert(hash(token) === value.revokeHash, "Invalid revocation key.", 403);
  await unlink(join(folder(), shareID + ".json"));
  return { revoked: true };
}
