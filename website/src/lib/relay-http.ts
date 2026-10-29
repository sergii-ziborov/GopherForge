import { RelayError, assert } from "./playground-core.ts";
export const noStore = {
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
};
const buckets = new Map<string, { count: number; until: number }>();
export function guardRequest(
  request: Request,
  limit = 180,
  category = new URL(request.url).pathname,
) {
  const origin = request.headers.get("origin"),
    own = new URL(request.url).origin;
  const host = request.headers.get("host");
  const localOrigin = host && ["127.0.0.1:3064", "localhost:3064"].includes(host) ? "http://" + host : null;
  assert(
    !origin || origin === own || origin === "https://gopherforge.app" || origin === localOrigin,
    "This origin is not allowed.",
    403,
  );
  const key =
    category +
    ":" +
    (request.headers.get("x-forwarded-for") ?? "local").split(",")[0].trim();
  const now = Date.now();
  if (buckets.size > 5000)
    for (const [k, b] of buckets) if (b.until <= now) buckets.delete(k);
  const b = buckets.get(key);
  if (!b || b.until <= now) buckets.set(key, { count: 1, until: now + 60_000 });
  else {
    assert(++b.count <= limit, "Too many requests. Try again shortly.", 429);
  }
  assert(buckets.size <= 10_000, "Relay busy. Try again shortly.", 503);
}
export async function readJSON(
  request: Request,
  max = 400 * 1024,
): Promise<Record<string, unknown>> {
  assert(
    request.headers.get("content-type")?.includes("application/json"),
    "Send application/json.",
    415,
  );
  assert(
    Number(request.headers.get("content-length") ?? 0) <= max,
    "Request too large.",
    413,
  );
  const reader = request.body?.getReader();
  assert(reader, "Missing request body.");
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > max) {
      await reader.cancel();
      throw new RelayError("Request too large.", 413);
    }
    chunks.push(value);
  }
  let value: unknown;
  try {
    value = JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new RelayError("Invalid JSON.");
  }
  assert(
    value && typeof value === "object" && !Array.isArray(value),
    "Send one JSON object.",
  );
  return value as Record<string, unknown>;
}
export function errorResponse(error: unknown) {
  return Response.json(
    {
      error:
        error instanceof RelayError
          ? error.message
          : "The request could not be completed.",
    },
    {
      status: error instanceof RelayError ? error.status : 500,
      headers: noStore,
    },
  );
}
