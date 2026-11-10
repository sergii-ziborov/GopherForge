import {
  prepareModules,
  loadPreparedModules,
  modulesIdentity,
  type PreparedModules,
} from "../lib/go-modules";
import { GoBrowser, sha256, type Asset, type GoMode } from "../lib/go-browser";
import manifest from "../lib/go-toolchain.json";
const scope = self as unknown as {
  location: Location;
  postMessage: (data: unknown) => void;
  onmessage: ((event: MessageEvent) => void) | null;
};
let downloads=new AbortController();
const stage = (label: string) => scope.postMessage({ type: "stage", label });
async function load(item: Asset) {
  let cache: Cache | undefined;
  try {
    cache = await caches.open(
      "gopherforge-go-" + manifest.assets.compile.sha256,
    );
  } catch {}
  const url = new URL(item.url, scope.location.origin).href;
  const cached = await cache?.match(url);
  if (cached) {
    const data = new Uint8Array(await cached.arrayBuffer());
    if (data.length === item.bytes && (await sha256(data)) === item.sha256)
      return data;
    await cache?.delete(url);
  }
  const response = await fetch(url, {
    cache: "no-store",
    signal:downloads.signal,
    credentials: "omit",
    redirect: "error",
  });
  if (!response.ok || !response.body)
    throw new Error(
      "Go compiler download unavailable. Connect once to prepare the local tools, then retry.",
    );
  const reader = response.body.getReader(),
    chunks: Uint8Array[] = [];
  let size = 0,
    last = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > item.bytes) {
      await reader.cancel();
      throw new Error("Oversized Go compiler asset");
    }
    chunks.push(value);
    if (performance.now() - last > 200) {
      last = performance.now();
      scope.postMessage({
        type: "download",
        label: `Downloading Go tools · ${(size / 1048576).toFixed(1)} / ${(item.bytes / 1048576).toFixed(1)} MiB`,
      });
    }
  }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const part of chunks) {
    data.set(part, offset);
    offset += part.length;
  }
  if (size !== item.bytes || (await sha256(data)) !== item.sha256)
    throw new Error("Go compiler asset failed SHA-256 verification");
  try {
    await cache?.put(url, new Response(data));
  } catch {}
  return data;
}
const compiler = new GoBrowser(manifest, load, stage);
let busy = false,
  prepared: PreparedModules | null = null;
scope.onmessage = async ({
  data,
}: {
  data: {
    files: Record<string, string>;
    mode: GoMode;
    stdin: string;
    control?: SharedArrayBuffer;
    breakpoints?: Record<string, number[]>;
  };
}) => {
  if (busy) return;
  busy = true;
  downloads=new AbortController();
  try {
    if (data.mode === "packages") {
      const start = performance.now();
      prepared = await prepareModules(
        data.files,
        (input) => compiler.query(input),
        stage,
      );
      const { files: _, ...summary } = prepared;
      scope.postMessage({
        type: "result",
        result: {
          stdout: `Prepared ${prepared.modules.length} public modules. ${prepared.cached ? "Verified source cached in this browser." : "Ready for this tab; browser storage is unavailable."}`,
          stderr: "",
          exitCode: 0,
          durationMs: performance.now() - start,
          prepared: summary,
        },
      });
    } else {
      const identity = await modulesIdentity(data.files);
      if (prepared?.identity !== identity)
        prepared = await loadPreparedModules(data.files);
      const result = await compiler.perform(data.files, data.mode, data.stdin, {
        dependencies: prepared?.files,
        control: data.control ? new Int32Array(data.control) : undefined,
        breakpoints: data.breakpoints,
        onPlan: (points) => scope.postMessage({ type: "debug-plan", points }),
        onPause: (pause) => scope.postMessage({ type: "paused", pause }),
      });
      scope.postMessage({ type: "result", result });
    }
  } catch (error) {
    downloads.abort();
    scope.postMessage({
      type: "error",
      error: error instanceof Error ? error.message : String(error),
    });
  } finally {
    busy = false;
  }
};
