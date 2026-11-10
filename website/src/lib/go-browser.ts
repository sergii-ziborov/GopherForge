import {
  WASI,
  File,
  Directory,
  OpenFile,
  PreopenDirectory,
  ConsoleStdout,
} from "@bjorn3/browser_wasi_shim";
import { gunzipSync, unzipSync } from "fflate";
import {
  GoDebugSession,
  bindBreakpoints,
  type DebugPoint,
  type DebugPause,
} from "./go-debug.ts";

export type GoMode =
  "run" | "test" | "build" | "check" | "format" | "debug" | "packages";
export type GoResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
  formatted?: Record<string, string>;
  wasm?: Uint8Array;
  prepared?: Omit<import("./go-modules.ts").PreparedModules, "files">;
};
export type GoPlan = {
  files: Record<string, string>;
  steps: { tool: "compile" | "link"; args: string[]; label: string }[];
  binaries: string[];
  formatted?: Record<string, string>;
  error?: string;
  points?: DebugPoint[];
  modules?: import("./go-modules.ts").ModuleSpec;
  verified?: string[];
  need?: string[];
  latest?: string;
};
export type Asset = {
  url: string;
  sha256: string;
  bytes: number;
  expandedBytes: number;
  expandedSHA256: string;
};
export type GoManifest = {
  assets: Record<"compile" | "link" | "planner" | "stdlib", Asset>;
  standard: string[];
};
type Tree = Map<string, File | Directory>;
const encoder = new TextEncoder();
export async function sha256(bytes: Uint8Array): Promise<string> {
  return Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)),
    ),
    (v) => v.toString(16).padStart(2, "0"),
  ).join("");
}
export function insert(root: Tree, path: string, file: File) {
  const parts = path.split("/").filter(Boolean),
    name = parts.pop()!;
  let dir = root;
  for (const part of parts) {
    if (part === ".." || part === ".") throw new Error("Invalid compiler path");
    let node = dir.get(part);
    if (!node) {
      node = new Directory(new Map());
      dir.set(part, node);
    }
    if (!(node instanceof Directory))
      throw new Error("Conflicting file and folder paths");
    dir = node.contents as Tree;
  }
  dir.set(name, file);
}
function get(root: Tree, path: string): File {
  let node: File | Directory = new Directory(root);
  for (const part of path.split("/").filter(Boolean)) {
    if (!(node instanceof Directory))
      throw new Error("Missing compiler output");
    node = node.contents.get(part) as File | Directory;
  }
  if (!(node instanceof File))
    throw new Error("Compiler did not produce output");
  return node;
}
// Bound generated program memory, including memory.grow. Compiler has its own budget.
export function limitMemory(
  bytes: Uint8Array,
  pages = 2048,
): Uint8Array<ArrayBuffer> {
  let pos = 8;
  const read = () => {
    let n = 0;
    for (let i = 0; i < 5; i++) {
      if (pos >= bytes.length) throw new Error("Truncated Wasm");
      const b = bytes[pos++];
      n += (b & 127) * 2 ** (7 * i);
      if (!(b & 128)) return n;
    }
    throw new Error("Invalid Wasm integer");
  };
  const u = (n: number) => {
    const a = [];
    do {
      let b = n & 127;
      n = Math.floor(n / 128);
      if (n) b |= 128;
      a.push(b);
    } while (n);
    return a;
  };
  if (
    bytes.length < 8 ||
    bytes[0] !== 0 ||
    bytes[1] !== 97 ||
    bytes[2] !== 115 ||
    bytes[3] !== 109
  )
    throw new Error("Compiler did not produce Wasm");
  while (pos < bytes.length) {
    const start = pos,
      id = bytes[pos++],
      length = read(),
      end = pos + length;
    if (end > bytes.length) throw new Error("Invalid Wasm section");
    if (id === 5) {
      if (read() !== 1) throw new Error("One program memory is required");
      const flags = read();
      if (flags > 1) throw new Error("Unsupported program memory");
      const initial = read(),
        max = flags === 1 ? read() : pages;
      if (initial > pages || pos !== end)
        throw new Error("Program exceeds its memory budget");
      const payload = [1, 1, ...u(initial), ...u(Math.min(max, pages))],
        header = [5, ...u(payload.length)];
      const out = new Uint8Array(
        start + header.length + payload.length + bytes.length - end,
      );
      out.set(bytes.subarray(0, start));
      out.set(header, start);
      out.set(payload, start + header.length);
      out.set(bytes.subarray(end), start + header.length + payload.length);
      return out;
    }
    pos = end;
  }
  throw new Error("Generated program has no memory");
}
export async function invoke(
  module: WebAssembly.Module,
  args: string[],
  stdin: string,
  tree: Tree,
  compiler = false,
  debug?: GoDebugSession,
) {
  let stdout = "",
    stderr = "",
    size = 0;
  const decoders = [new TextDecoder(), new TextDecoder()];
  const capture = (i: number) =>
    new ConsoleStdout((bytes) => {
      size += bytes.length;
      if (size > (compiler ? 16 : 1) * 1024 * 1024)
        throw new Error("Stopped at the 1 MiB output limit");
      const s = decoders[i].decode(bytes, { stream: true });
      if (i === 0) stdout += s;
      else stderr += s;
    });
  const wasi = new WASI(
    args,
    [
      "GOROOT=/goroot",
      "GOOS=wasip1",
      "GOARCH=wasm",
      "GOMAXPROCS=1",
      "GOGC=50",
      "TMPDIR=/tmp",
      "PWD=/work",
      `GOMEMLIMIT=${compiler ? 384 : 96}MiB`,
    ],
    [
      new OpenFile(new File(encoder.encode(stdin))),
      capture(0),
      capture(1),
      new PreopenDirectory("/", tree),
    ],
    { debug: false },
  );
  if (!compiler) {
    const quota = 4 * 1024 * 1024;
    let writes = 0;
    const usage = () => {
      const seen = new Set<File | Directory>();
      let bytes = 0,
        nodes = 0;
      const visit = (values: Tree) => {
        for (const file of values.values()) {
          if (seen.has(file)) continue;
          seen.add(file);
          if (++nodes > 512)
            throw new Error("Program stopped at the 512-file/folder limit");
          if (file instanceof File) bytes += file.data.length;
          else visit(file.contents as Tree);
        }
      };
      visit(tree);
      return bytes;
    };
    for (const name of ["path_open", "path_create_directory"]) {
      const call = wasi.wasiImport[name];
      wasi.wasiImport[name] = (...args: (number | bigint)[]) => {
        usage();
        return call(...args);
      };
    }
    const original = wasi.wasiImport;
    for (const name of [
      "fd_allocate",
      "fd_filestat_set_size",
      "fd_pwrite",
      "fd_write",
    ]) {
      const call = original[name];
      original[name] = (...args: (number | bigint)[]) => {
        const fd = wasi.fds[Number(args[0])];
        if (fd instanceof OpenFile) {
          let end = fd.file_pos;
          if (name === "fd_allocate") end = BigInt(args[1]) + BigInt(args[2]);
          else if (name === "fd_filestat_set_size") end = BigInt(args[1]);
          else {
            const memory = new DataView(wasi.inst.exports.memory.buffer),
              pointer = Number(args[1]),
              count = Number(args[2]);
            if (
              count > 65536 ||
              pointer < 0 ||
              pointer + count * 8 > memory.byteLength
            )
              throw new Error("Invalid guest write");
            let size = 0;
            for (let i = 0; i < count; i++)
              size += memory.getUint32(pointer + i * 8 + 4, true);
            writes += size;
            end =
              (name === "fd_pwrite" ? BigInt(args[3]) : fd.file_pos) +
              BigInt(size);
          }
          if (
            end > BigInt(quota) ||
            writes > quota ||
            usage() + Math.max(0, Number(end) - fd.file.data.length) > quota
          )
            throw new Error("Program stopped at the 4 MiB guest-write limit");
        }
        return call(...args);
      };
    }
  }
  const instance = await WebAssembly.instantiate(module, {
    wasi_snapshot_preview1: wasi.wasiImport,
    ...(debug
      ? {
          gopherforge_debug: {
            checkpoint: (
              kind: number,
              id: number,
              goroutine: number,
              pointer: number,
              length: number,
            ) => {
              const memory = instance.exports.memory as WebAssembly.Memory;
              pointer >>>= 0;
              length >>>= 0;
              if (
                length > 65536 ||
                pointer > memory.buffer.byteLength ||
                length > memory.buffer.byteLength - pointer
              )
                throw new Error("Invalid debug memory range");
              debug.checkpoint(
                kind,
                id,
                goroutine,
                new Uint8Array(memory.buffer, pointer, length),
              );
            },
          },
        }
      : {}),
  });
  let exitCode = 1;
  try {
    exitCode = wasi.start(instance as Parameters<WASI["start"]>[0]);
  } catch (e) {
    stderr += "\n" + (e instanceof Error ? e.message : String(e));
  }
  stdout += decoders[0].decode();
  stderr += decoders[1].decode();
  return { stdout, stderr, exitCode };
}
export class GoBrowser {
  private modules = new Map<string, WebAssembly.Module>();
  private standard: Tree = new Map();
  private manifest: GoManifest;
  private load: (asset: Asset) => Promise<Uint8Array>;
  private stage: (label: string) => void;
  constructor(
    manifest: GoManifest,
    load: (asset: Asset) => Promise<Uint8Array>,
    stage: (label: string) => void,
  ) {
    this.manifest = manifest;
    this.load = load;
    this.stage = stage;
  }
  async prepare(mode: GoMode) {
    const names: ("planner" | "compile" | "link")[] =
      mode === "format" || mode === "packages"
        ? ["planner"]
        : [
            "planner",
            "compile",
            ...(mode === "check" ? [] : ["link" as const]),
          ];

    const pending = names.filter((name) => !this.modules.has(name));
    const [assets,standardData]=await Promise.all([
      Promise.all(pending.map(async name=>[name,await this.load(this.manifest.assets[name])] as const)),
      mode!=="format"&&mode!=="packages"&&!this.standard.size ? this.load(this.manifest.assets.stdlib) : Promise.resolve(null)
    ]);
    const prefetched = new Map(assets);
    for (const name of names) {
      if (this.modules.has(name)) continue;
      this.stage("Preparing Go " + name);
      const item = this.manifest.assets[name],
        compressed = prefetched.get(name)!,
        bytes = gunzipSync(compressed);
      if (
        bytes.length !== item.expandedBytes ||
        (await sha256(bytes)) !== item.expandedSHA256
      )
        throw new Error("Go tool integrity mismatch");
      this.modules.set(
        name,
        await WebAssembly.compile(limitMemory(bytes, 8192)),
      );
    }
    if (mode !== "format" && mode !== "packages" && !this.standard.size) {
      this.stage("Preparing the Go standard library");
      const data = standardData!;
      let total = 0;
      for (const [name, bytes] of Object.entries(unzipSync(data))) {
        total += bytes.length;
        if (total > 256 * 1024 * 1024)
          throw new Error("Standard library expansion limit");
        if (name.endsWith("/")) continue;
        if (name.includes("..") || name.startsWith("/") || name.includes("\\"))
          throw new Error("Invalid standard library path");
        insert(this.standard, name, new File(bytes, { readonly: true }));
      }
    }
  }

  async query(input: Record<string, unknown>): Promise<GoPlan> {
    await this.prepare("format");
    const tree: Tree = new Map([
      ["work", new Directory(new Map())],
      ["tmp", new Directory(new Map())],
    ]);
    const result = await invoke(
      this.modules.get("planner")!,
      ["planner"],
      JSON.stringify(input),
      tree,
      true,
    );
    if (result.exitCode !== 0)
      throw new Error(result.stderr || result.stdout || "Go planner failed");
    const plan = JSON.parse(result.stdout) as GoPlan;
    if (plan.error) throw new Error(plan.error);
    return plan;
  }
  async perform(
    files: Record<string, string>,
    mode: GoMode,
    stdin = "",
    options: {
      dependencies?: Record<string, string>;
      control?: Int32Array;
      breakpoints?: Record<string, number[]>;
      onPause?: (snapshot: DebugPause) => void;
      onPlan?: (points: DebugPoint[]) => void;
    } = {},
  ): Promise<GoResult> {
    await this.prepare(mode);
    const start = performance.now();
    if (mode === "debug") {
      if (!options.control)
        throw new Error("Debug requires isolated shared memory");
      const checked = await this.perform(files, "build", stdin, {
        dependencies: options.dependencies,
      });
      if (checked.exitCode !== 0) return checked;
    }
    const allFiles = { ...options.dependencies, ...files };
    let tree: Tree = new Map([
      ["work", new Directory(new Map())],
      ["tmp", new Directory(new Map())],
      ["goroot", new Directory(this.standard)],
    ]);
    const planned = await invoke(
      this.modules.get("planner")!,
      ["planner"],
      JSON.stringify({
        Files: files,
        Dependencies: options.dependencies ?? {},
        Mode: mode,
        Standard: this.manifest.standard,
      }),
      tree,
      true,
    );
    if (planned.exitCode !== 0)
      throw new Error(planned.stderr || planned.stdout || "Go planner failed");
    const plan = JSON.parse(planned.stdout) as GoPlan;
    if (plan.error) throw new Error(plan.error);
    if (plan.formatted)
      return {
        stdout: "Go files formatted locally.",
        stderr: "",
        exitCode: 0,
        formatted: plan.formatted,
        durationMs: performance.now() - start,
      };
    for (const [p, s] of Object.entries(allFiles))
      insert(tree, "work/" + p, new File(encoder.encode(s)));
    for (const [p, s] of Object.entries(plan.files))
      insert(tree, p, new File(encoder.encode(s)));
    let stdout = "",
      stderr = "";
    for (const step of plan.steps) {
      this.stage(step.label);
      const result = await invoke(
        this.modules.get(step.tool)!,
        step.args,
        "",
        tree,
        true,
      );
      stdout += result.stdout;
      stderr += result.stderr;
      if (result.exitCode !== 0)
        return {
          stdout,
          stderr,
          exitCode: result.exitCode,
          durationMs: performance.now() - start,
        };
    }
    let wasm: Uint8Array | undefined;
    if (
      mode === "run" ||
      mode === "test" ||
      mode === "build" ||
      mode === "debug"
    ) {
      for (const path of plan.binaries) {
        wasm = limitMemory(get(tree, path).data);
        if (mode === "build") break;
        this.stage(
          mode === "test" ? "Running tests locally" : "Running locally",
        );
        // The guest gets fresh project files, with no compiler or standard archives.
        const work: Tree = new Map();
        for (const [p, s] of Object.entries(files))
          insert(work, p, new File(encoder.encode(s)));
        const guestTree: Tree = new Map([
          ["work", new Directory(work)],
          ["tmp", new Directory(new Map())],
        ]);
        let debug: GoDebugSession | undefined;
        if (mode === "debug") {
          bindBreakpoints(
            plan.points ?? [],
            options.breakpoints ?? {},
            options.control!,
          );
          options.onPlan?.(plan.points ?? []);
          debug = new GoDebugSession(
            plan.points ?? [],
            options.control!,
            options.onPause ?? (() => {}),
          );
        }
        const result = await invoke(
          await WebAssembly.compile(new Uint8Array(wasm)),
          [path, ...(mode === "test" ? ["-test.v"] : [])],
          stdin,
          guestTree,
          false,
          debug,
        );
        stdout += result.stdout;
        stderr += result.stderr;
        if (result.exitCode !== 0)
          return {
            stdout,
            stderr,
            exitCode: result.exitCode,
            durationMs: performance.now() - start,
          };
      }
    }
    return {
      stdout:
        stdout ||
        (mode === "check"
          ? "Go check passed."
          : mode === "build"
            ? "WebAssembly build ready to download."
            : "No stdout."),
      stderr,
      exitCode: 0,
      durationMs: performance.now() - start,
      ...(mode === "build" ? { wasm } : {}),
    };
  }
}
