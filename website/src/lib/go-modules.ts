import { unzipSync } from "fflate";
import { sha256, type GoPlan } from "./go-browser.ts";
export type ModuleSpec = {
  module: string;
  go: string;
  requires: { path: string; version: string }[];
  excludes: { path: string; version: string }[];
  hasReplace: boolean;
};
export type PreparedModules = {
  identity: string;
  files: Record<string, string>;
  modules: { path: string; version: string; checksum: string }[];
  goSum: string;
  treeHash: string;
  cached?: boolean;
};
type ReadPublic = (url: string, maximum: number) => Promise<Uint8Array>;
type Query = (input: Record<string, unknown>) => Promise<GoPlan>;
const encoder = new TextEncoder(),
  decoder = new TextDecoder("utf-8", { fatal: true });
const base = "https://proxy.golang.org/";
const encodePath = (path: string) =>
  path.replace(/[A-Z]/g, (c) => "!" + c.toLowerCase());
const b64 = (bytes: Uint8Array) => {
  let s = "";
  for (let i = 0; i < bytes.length; i += 8192)
    s += String.fromCharCode(...bytes.subarray(i, i + 8192));
  return btoa(s);
};
export const modulesIdentity = (files: Record<string, string>) =>
  sha256(
    encoder.encode((files["go.mod"] ?? "") + "\0" + (files["go.sum"] ?? "")),
  );
function validModule(path: string, version: string) {
  if (
    !/^[A-Za-z0-9][A-Za-z0-9._~/-]*$/.test(path) ||
    !path.includes(".") ||
    path.split("/").some((p) => !p || p === "." || p === "..") ||
    path.length > 180 ||
    !/^v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?(?:\+incompatible)?$/.test(version) ||
    version.length > 100
  )
    throw new Error(
      "Use a public module path and an exact version such as v1.6.0",
    );
}
export function compareVersions(a: string, b: string) {
  const parse = (s: string) => {
    const [core, pre] = s
      .replace(/^v/, "")
      .replace(/\+incompatible$/, "")
      .split("-", 2);
    return { core: core.split(".").map(Number), pre: pre?.split(".") };
  };
  const x = parse(a),
    y = parse(b);
  for (let i = 0; i < 3; i++)
    if (x.core[i] !== y.core[i]) return x.core[i] - y.core[i];
  if (!x.pre || !y.pre) return x.pre ? -1 : y.pre ? 1 : 0;
  for (let i = 0; i < Math.max(x.pre.length, y.pre.length); i++) {
    const p = x.pre[i],
      q = y.pre[i];
    if (p === undefined) return -1;
    if (q === undefined) return 1;
    if (p === q) continue;
    const pn = /^\d+$/.test(p),
      qn = /^\d+$/.test(q);
    if (pn && qn) return Number(p) - Number(q);
    if (pn !== qn) return pn ? -1 : 1;
    return p < q ? -1 : 1;
  }
  return 0;
}
export class ModuleDownloadError extends Error {
  status: number;
  constructor(status: number, url: string) {
    super(`Package download failed (${status}): ${new URL(url).pathname}`);
    this.status = status;
  }
}
async function publicBytes(url: string, maximum: number, signal?: AbortSignal) {
  let cache: Cache | undefined;
  try {
    cache = await caches.open("gopherforge-go-module-downloads-v1");
  } catch {}
  const saved = await cache?.match(url);
  if (saved) {
    const bytes = new Uint8Array(await saved.arrayBuffer());
    if (bytes.length <= maximum) return bytes;
    await cache?.delete(url);
  }
  const response = await fetch(url, {
    credentials: "omit",
    signal: signal ?? AbortSignal.timeout(45000),
    redirect: "follow",
  });
  if (!response.ok || !response.body)
    throw new ModuleDownloadError(response.status, url);
  if (
    !["proxy.golang.org", "storage.googleapis.com", "sum.golang.org"].includes(
      new URL(response.url).hostname,
    )
  )
    throw new Error("Unexpected package mirror redirect");
  const reader = response.body.getReader(),
    parts: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > maximum) {
      await reader.cancel();
      throw new Error("Package download exceeded its byte budget");
    }
    parts.push(value);
  }
  const out = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  try {
    await cache?.put(url, new Response(out));
  } catch {}
  return out;
}
export async function goDirHash(
  files: Record<string, Uint8Array>,
): Promise<string> {
  const names = Object.keys(files);
  const paths = new Map(names.map((n) => [n, encoder.encode(n)]));
  names.sort((a, b) => {
    const x = paths.get(a)!,
      y = paths.get(b)!;
    for (let i = 0; i < Math.min(x.length, y.length); i++)
      if (x[i] !== y[i]) return x[i] - y[i];
    return x.length - y.length;
  });
  const lines: string[] = [];
  for (let i = 0; i < names.length; i += 16) {
    const batch = names.slice(i, i + 16);
    lines.push(
      ...(await Promise.all(
        batch.map(async (n) => (await sha256(files[n])) + "  " + n + "\n"),
      )),
    );
  }
  return (
    "h1:" +
    b64(
      new Uint8Array(
        await crypto.subtle.digest("SHA-256", encoder.encode(lines.join(""))),
      ),
    )
  );
}
function sums(text: string) {
  const result = new Map<string, string>();
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const [path, version, hash, ...extra] = line.split(/\s+/);
    if (extra.length || !/^h1:[A-Za-z0-9+/]{43}=$/.test(hash ?? ""))
      throw new Error("Invalid go.sum entry");
    const key = path + " " + version;
    if (result.has(key) && result.get(key) !== hash)
      throw new Error("Conflicting go.sum entries");
    result.set(key, hash);
  }
  return result;
}
async function expectedSums(
  path: string,
  version: string,
  known: Map<string, string>,
  query: Query,
  stage: (s: string) => void,
  read: ReadPublic = publicBytes,
) {
  if (
    known.has(path + " " + version) &&
    known.has(path + " " + version + "/go.mod")
  )
    return;
  stage("Authenticating " + path + " with the signed Go checksum log");
  const remote: Record<string, string> = {};
  let latest = "";
  let cache: Cache | undefined;
  try {
    cache = await caches.open("gopherforge-go-sumdb-v1");
    const prior = await cache.match("https://gopherforge.app/__sumdb/latest");
    latest = prior ? await prior.text() : "";
  } catch {}
  for (let pass = 0; pass < 24; pass++) {
    const result = await query({
      Mode: "sumdb",
      Module: path,
      Version: version,
      Remote: remote,
      Latest: latest,
    });
    if (result.need?.length) {
      for (const name of result.need) {
        if (
          !/^\/(?:lookup\/[A-Za-z0-9!._@/+~-]+|tile\/[A-Za-z0-9/._-]+)$/.test(
            name,
          ) ||
          name.includes("..")
        )
          throw new Error("Invalid checksum proof URL");
        try {
          remote[name] = b64(
            await read("https://sum.golang.org" + name, 1024 * 1024),
          );
        } catch (error) {
          if (error instanceof ModuleDownloadError && error.status === 404)
            remote[name] = "HTTP 404";
          else throw error;
        }
      }
      continue;
    }
    if (!result.verified?.length)
      throw new Error("The checksum log did not authenticate this module");
    for (const line of result.verified) {
      const [p, v, hash] = line.split(/\s+/);
      if (p !== path || (v !== version && v !== version + "/go.mod"))
        throw new Error("Unexpected checksum-log record");
      const key = p + " " + v;
      if (known.has(key) && known.get(key) !== hash)
        throw new Error("Checksum log disagrees with go.sum for " + key);
      known.set(key, hash);
    }
    if (result.latest)
      try {
        await cache?.put(
          "https://gopherforge.app/__sumdb/latest",
          new Response(result.latest),
        );
      } catch {}
    return;
  }
  throw new Error("Checksum verification exceeded its proof budget");
}
export function extractModuleArchive(
  bytes: Uint8Array,
  path: string,
  version: string,
) {
  let entries = 0,
    expanded = 0;
  const prefix = path + "@" + version + "/";
  const archive = unzipSync(bytes, {
    filter: (file) => {
      if (
        ++entries > 12000 ||
        (expanded += file.originalSize) > 64 * 1024 * 1024 ||
        file.originalSize > 8 * 1024 * 1024
      )
        throw new Error("Module ZIP exceeds its archive budget");
      if (
        file.name.includes("\\") ||
        /[\r\n\0]/.test(file.name) ||
        !file.name.startsWith(prefix) ||
        file.name
          .slice(prefix.length)
          .split("/")
          .some((p) => p === "." || p === "..")
      )
        throw new Error("Unsafe module ZIP path");
      return !file.name.endsWith("/");
    },
  });
  return { archive, prefix };
}
export async function prepareModules(
  source: Record<string, string>,
  query: Query,
  stage: (s: string) => void,
  read: ReadPublic = publicBytes,
): Promise<PreparedModules> {
  const root = (
    await query({ Mode: "modules", ModText: source["go.mod"] ?? "" })
  ).modules!;
  if (root.hasReplace)
    throw new Error(
      "Browser package preparation does not support replace directives. Use an exact public requirement or import compatible vendor source.",
    );
  const known = sums(source["go.sum"] ?? ""),
    queue = [...root.requires],
    seen = new Set<string>(),
    selected = new Map<string, string>();
  while (queue.length) {
    const item = queue.shift()!;
    validModule(item.path, item.version);
    const key = item.path + " " + item.version;
    if (seen.has(key)) continue;
    seen.add(key);
    if (seen.size > 64)
      throw new Error("Module graph exceeds 64 version nodes");
    const previous = selected.get(item.path);
    if (!previous || compareVersions(item.version, previous) > 0)
      selected.set(item.path, item.version);
    if (selected.size > 24)
      throw new Error("Use at most 24 public modules in the browser");
    await expectedSums(item.path, item.version, known, query, stage, read);
    stage("Reading " + item.path + " " + item.version);
    const data = await read(
      base + encodePath(item.path) + "/@v/" + encodePath(item.version) + ".mod",
      1024 * 1024,
    );
    if ((await goDirHash({ "go.mod": data })) !== known.get(key + "/go.mod"))
      throw new Error("go.mod checksum mismatch for " + item.path);
    const spec = (
      await query({ Mode: "modules", ModText: decoder.decode(data) })
    ).modules!;
    if (spec.go && Number(spec.go.split(".")[1]) > 27)
      throw new Error(
        item.path +
          " requires Go " +
          spec.go +
          "; this browser bundles Go 1.27.1",
      );
    queue.push(...spec.requires);
  }
  for (const x of root.excludes)
    if (selected.get(x.path) === x.version)
      throw new Error(
        "The selected version is excluded by go.mod: " +
          x.path +
          " " +
          x.version,
      );
  const files: Record<string, string> = {},
    modules: PreparedModules["modules"] = [];
  let size = 0;
  for (const [path, version] of [...selected].sort(([a], [b]) =>
    a < b ? -1 : 1,
  )) {
    stage("Downloading " + path + " " + version);
    const bytes = await read(
      base + encodePath(path) + "/@v/" + encodePath(version) + ".zip",
      12 * 1024 * 1024,
    );
    const { archive, prefix } = extractModuleArchive(bytes, path, version);
    const checksum = await goDirHash(archive);
    if (checksum !== known.get(path + " " + version))
      throw new Error("Module ZIP checksum mismatch for " + path);
    for (const [name, data] of Object.entries(archive)) {
      const relative = name.slice(prefix.length);
      if (
        relative.endsWith("_test.go") ||
        relative
          .split("/")
          .some((p) => [".git", "vendor", "testdata"].includes(p))
      )
        continue;
      let text: string;
      try {
        text = decoder.decode(data);
      } catch {
        continue;
      }
      if (text.includes("\0")) continue;
      const target = "vendor/" + path + "/" + relative;
      if (Object.hasOwn(source, target))
        throw new Error(
          "Prepared package collides with imported vendor source: " + target,
        );
      if (
        data.length > 1024 * 1024 ||
        (size += data.length) > 8 * 1024 * 1024 ||
        Object.keys(files).length >= 512
      )
        throw new Error("Prepared source exceeds 512 files / 8 MiB");
      files[target] = text;
    }
    modules.push({ path, version, checksum });
  }
  const goSum =
    [...known.entries()]
      .sort(([a], [b]) => (a < b ? -1 : 1))
      .map(([key, value]) => key + " " + value)
      .join("\n") + "\n";
  const identity = await modulesIdentity({ ...source, "go.sum": goSum }),
    treeHash = await sha256(
      encoder.encode(
        JSON.stringify(
          Object.entries(files).sort(([a], [b]) => (a < b ? -1 : 1)),
        ),
      ),
    );
  const prepared: PreparedModules = {
    identity,
    files,
    modules,
    goSum,
    treeHash,
  };
  try {
    const cache = await caches.open("gopherforge-prepared-modules-v1");
    await cache.put(
      "https://gopherforge.app/__prepared/" + identity,
      new Response(JSON.stringify(prepared)),
    );
    prepared.cached = true;
  } catch {
    prepared.cached = false;
  }
  return prepared;
}
export async function loadPreparedModules(
  source: Record<string, string>,
): Promise<PreparedModules | null> {
  try {
    const identity = await modulesIdentity(source),
      cache = await caches.open("gopherforge-prepared-modules-v1"),
      response = await cache.match(
        "https://gopherforge.app/__prepared/" + identity,
      );
    if (!response) return null;
    const text = await response.text();
    if (text.length > 16 * 1024 * 1024)
      throw new Error("Prepared cache is oversized");
    const value = JSON.parse(text) as PreparedModules;
    if (
      value.identity !== identity ||
      value.treeHash !==
        (await sha256(
          encoder.encode(
            JSON.stringify(
              Object.entries(value.files).sort(([a], [b]) => (a < b ? -1 : 1)),
            ),
          ),
        ))
    )
      throw new Error("Prepared cache changed");
    return value;
  } catch {
    return null;
  }
}
