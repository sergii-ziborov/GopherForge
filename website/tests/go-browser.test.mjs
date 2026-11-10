import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { GoBrowser, limitMemory } from "../src/lib/go-browser.ts";
import {
  examples,
  importSource,
  exportSource,
  renameSource,
  validateSource,
} from "../src/lib/playground-files.ts";
const manifest = JSON.parse(
  await readFile(
    new URL("../src/lib/go-toolchain.json", import.meta.url),
    "utf8",
  ),
);
test("the real browser WASI pipeline runs multi-package Go, stdin, internal/external tests, build and format", async () => {
  const engine = new GoBrowser(
    manifest,
    (a) => readFile(new URL("../public" + a.url, import.meta.url)),
    () => {},
  );
  for (const [name, mode, expected] of [
    ["hello", "run", "Hello from my browser"],
    ["input", "run", "Hello, Gopher!"],
    ["tests", "test", "PASS"],
    ["multi", "run", "Hello, Go"],
    ["multi", "test", "PASS"],
  ]) {
    const result = await engine.perform(
      examples[name].files,
      mode,
      examples[name].stdin ?? "",
    );
    assert.equal(result.exitCode, 0, JSON.stringify(result));
    assert.ok(result.stdout.includes(expected), JSON.stringify(result));
  }
  const generic = await engine.perform(
    {
      ...examples.hello.files,
      "main.go":
        'package main\nimport("fmt";"strconv")\ntype Box[T any] struct{Value T}\nfunc(b Box[T]) Map[U any](f func(T) U) Box[U]{return Box[U]{f(b.Value)}}\nfunc main(){fmt.Println(Box[int]{42}.Map(strconv.Itoa).Value)}',
    },
    "run",
  );
  assert.equal(generic.exitCode, 0, JSON.stringify(generic));
  assert.equal(generic.stdout, "42\n");
  const quota = await engine.perform(
    {
      ...examples.hello.files,
      "main.go":
        'package main\nimport "os"\nfunc main(){os.WriteFile("/tmp/huge",make([]byte,5<<20),0600)}',
    },
    "run",
  );
  assert.notEqual(quota.exitCode, 0);
  assert.match(quota.stderr, /guest-write limit/);
  const build = await engine.perform(examples.hello.files, "build");
  assert.equal(build.exitCode, 0);
  assert.ok(await WebAssembly.compile(build.wasm));
  const formatted = await engine.perform(
    {
      ...examples.hello.files,
      "main.go": "package main;func main(){println(1)}",
    },
    "format",
  );
  assert.match(
    formatted.formatted["main.go"],
    /func main\(\) \{ println\(1\) \}/,
  );
  const failed = await engine.perform(
    {
      ...examples.tests.files,
      "main.go":
        "package main\nfunc double(n int) int {return 0}\nfunc main(){}",
    },
    "test",
  );
  assert.notEqual(failed.exitCode, 0);
  assert.match(failed.stdout, /FAIL/);
  await assert.rejects(
    engine.perform(
      {
        ...examples.hello.files,
        "main.go":
          'package main\nimport "unknown.example/missing"\nfunc main(){}',
      },
      "run",
    ),
    /Dependency.*not present/,
  );
  const syntax = await engine.perform(
    {
      ...examples.hello.files,
      "main.go": "package main\nfunc main(){ unknown() }",
    },
    "run",
  );
  assert.notEqual(syntax.exitCode, 0);
  assert.match(syntax.stdout + syntax.stderr, /main.go:2/);
  const variant = {
    ...examples.hello.files,
    "not_windows.go":
      "//go:build windows\n\npackage main\nthis is intentionally invalid",
  };
  assert.equal((await engine.perform(variant, "run")).exitCode, 0);
  const embedded = {
    ...examples.hello.files,
    "main.go":
      'package main\nimport("fmt";_ "embed")\n//go:embed message.txt\nvar message string\nfunc main(){fmt.Print(message)}',
    "message.txt": "Embedded locally",
  };
  const result = await engine.perform(embedded, "run");
  assert.equal(result.exitCode, 0, JSON.stringify(result));
  assert.equal(result.stdout, "Embedded locally");
});
test("project ZIP round trips and file operations reject collisions and unsafe or oversized paths", () => {
  assert.deepEqual(
    importSource(exportSource(examples.multi.files), "project.zip"),
    examples.multi.files,
  );
  const renamed = renameSource(examples.multi.files, "greet", "hello");
  assert.ok(renamed["hello/greet.go"]);
  assert.ok(!renamed["greet/greet.go"]);
  assert.throws(
    () =>
      renameSource(
        examples.multi.files,
        "greet/greet.go",
        "greet/greet_test.go",
      ),
    /exists/,
  );
  for (const name of ["../escape", "/escape", "__proto__/bad", "greet"])
    assert.throws(() =>
      validateSource({ ...examples.multi.files, [name]: "bad" }),
    );
  assert.throws(
    () =>
      validateSource({
        ...examples.hello.files,
        "huge.txt": "x".repeat(65537),
      }),
    /64 KiB/,
  );
  assert.throws(() => limitMemory(new Uint8Array(10)), /Wasm/);
});

test("relay accepts the actual loopback preview origin and rejects unrelated origins", async () => {
  const { guardRequest } = await import("../src/lib/relay-http.ts");
  assert.doesNotThrow(() =>
    guardRequest(
      new Request("http://localhost:3066/api/playground", {
        headers: { host: "127.0.0.1:3066", origin: "http://127.0.0.1:3066" },
      }),
    ),
  );
  assert.throws(
    () =>
      guardRequest(
        new Request("https://gopherforge.app/api/playground", {
          headers: {
            host: "gopherforge.app",
            origin: "https://unrelated.example",
          },
        }),
      ),
    /origin/,
  );
});
