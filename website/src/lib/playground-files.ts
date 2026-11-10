import { strFromU8, strToU8, unzipSync, zipSync } from "fflate";
export const safeSourcePath = (path: string) =>
  /^[a-zA-Z0-9_./-]{1,180}$/.test(path) &&
  !path.startsWith("/") &&
  path
    .split("/")
    .every(
      (p) =>
        p && ![".", "..", "__proto__", "constructor", "prototype"].includes(p),
    );
export function validateSource(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Choose a source project");
  const entries = Object.entries(value);
  if (entries.length < 1 || entries.length > 32)
    throw new Error("Use 1–32 text files");
  let total = 0;
  for (const [path, text] of entries) {
    if (!safeSourcePath(path)) throw new Error("Use safe relative file paths");
    if (typeof text !== "string" || text.includes("\0"))
      throw new Error("Only UTF-8 text files are supported");
    const size = new TextEncoder().encode(text).length;
    if (size > 65536) throw new Error("Each file must be at most 64 KiB");
    total += size;
    for (const [other] of entries)
      if (other !== path && other.startsWith(path + "/"))
        throw new Error("A file and a folder cannot use the same path");
  }
  if (total > 262144) throw new Error("The source limit is 256 KiB");
  if (typeof (value as Record<string, string>)["main.go"] !== "string")
    throw new Error("Keep main.go as the entry point");
  return Object.fromEntries(entries);
}
export function renameSource(
  files: Record<string, string>,
  from: string,
  to: string,
) {
  if (from === "main.go") throw new Error("Keep main.go as the entry point");
  const next: Record<string, string> = {};
  let found = false;
  for (const [path, text] of Object.entries(files)) {
    const renamed = path === from || path.startsWith(from + "/");
    found ||= renamed;
    const name = renamed ? to + path.slice(from.length) : path;
    if (Object.hasOwn(next, name) || (renamed && Object.hasOwn(files, name)))
      throw new Error("The destination already exists");
    next[name] = text;
  }
  if (!found) throw new Error("Choose an existing file or folder");
  return validateSource(next);
}
export function exportSource(files: Record<string, string>) {
  return zipSync(
    Object.fromEntries(
      Object.entries(validateSource(files)).map(([p, s]) => [p, strToU8(s)]),
    ),
    { level: 6 },
  );
}
export function importSource(bytes: Uint8Array, name: string) {
  if (bytes.length > 2 * 1024 * 1024)
    throw new Error("Choose a source archive under 2 MiB");
  if (name.endsWith(".json"))
    return validateSource(JSON.parse(strFromU8(bytes)));
  if (!name.endsWith(".zip"))
    throw new Error("Choose a ZIP or a GopherForge JSON source copy");
  let count = 0,
    total = 0;
  const archive = unzipSync(bytes, {
    filter: (file) => {
      if (file.name.endsWith("/")) return false;
      if (
        ++count > 32 ||
        file.originalSize > 65536 ||
        (total += file.originalSize) > 262144
      )
        throw new Error("Archive exceeds the 32-file / 256 KiB source limit");
      return true;
    },
  });
  const names = Object.keys(archive);
  let prefix = "";
  if (!names.includes("main.go")) {
    const roots = new Set(names.map((p) => p.split("/")[0]));
    if (roots.size === 1) prefix = [...roots][0] + "/";
  }
  const decoder = new TextDecoder("utf-8", { fatal: true });
  return validateSource(
    Object.fromEntries(
      Object.entries(archive).map(([p, b]) => [
        p.slice(prefix.length),
        decoder.decode(b),
      ]),
    ),
  );
}
export const examples: Record<
  string,
  { label: string; files: Record<string, string>; stdin?: string }
> = {
  hello: {
    label: "Hello, Go",
    files: {
      "go.mod": "module playground\n\ngo 1.27.1\n",
      "main.go":
        'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello from my browser")\n}\n',
    },
  },
  tests: {
    label: "Functions & tests",
    files: {
      "go.mod": "module playground\n\ngo 1.27.1\n",
      "main.go":
        'package main\n\nimport "fmt"\n\nfunc double(n int) int { return n * 2 }\n\nfunc main() { fmt.Println(double(21)) }\n',
      "main_test.go":
        'package main\n\nimport "testing"\n\nfunc TestDouble(t *testing.T) {\n\tfor _, n := range []int{0, 1, -3, 21} {\n\t\tif got := double(n); got != n*2 {\n\t\t\tt.Errorf("double(%d) = %d", n, got)\n\t\t}\n\t}\n}\n',
    },
  },
  input: {
    label: "Read standard input",
    stdin: "Gopher\n",
    files: {
      "go.mod": "module playground\n\ngo 1.27.1\n",
      "main.go":
        'package main\n\nimport (\n\t"bufio"\n\t"fmt"\n\t"os"\n)\n\nfunc main() {\n\tscanner := bufio.NewScanner(os.Stdin)\n\tif scanner.Scan() {\n\t\tfmt.Printf("Hello, %s!\\n", scanner.Text())\n\t}\n}\n',
    },
  },
  multi: {
    label: "Multiple packages",
    files: {
      "go.mod": "module playground\n\ngo 1.27.1\n",
      "main.go":
        'package main\n\nimport (\n\t"fmt"\n\t"playground/greet"\n)\n\nfunc main() { fmt.Println(greet.Hello("Go")) }\n',
      "greet/greet.go":
        'package greet\n\nfunc Hello(name string) string { return "Hello, " + name }\n',
      "greet/greet_test.go":
        'package greet_test\n\nimport (\n\t"testing"\n\t"playground/greet"\n)\n\nfunc TestHello(t *testing.T) {\n\tif greet.Hello("Go") != "Hello, Go" { t.Fatal("unexpected greeting") }\n}\n',
    },
  },
};
