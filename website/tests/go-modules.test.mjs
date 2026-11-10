import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { unzipSync, zipSync } from "fflate";
import { GoBrowser } from "../src/lib/go-browser.ts";
import {
  prepareModules,
  ModuleDownloadError,
  compareVersions,
} from "../src/lib/go-modules.ts";
const manifest = JSON.parse(
  await readFile(
    new URL("../src/lib/go-toolchain.json", import.meta.url),
    "utf8",
  ),
);
const records = JSON.parse(
  await readFile(
    new URL("./fixtures/go-modules-uuid/responses.json", import.meta.url),
    "utf8",
  ),
);
const expected = JSON.parse(
  await readFile(
    new URL("./fixtures/go-modules-uuid/expected.json", import.meta.url),
    "utf8",
  ),
);
const engine = new GoBrowser(
  manifest,
  (a) => readFile(new URL("../public" + a.url, import.meta.url)),
  () => {},
);
const reader =
  (transform = (url, bytes) => bytes) =>
  async (url, max) => {
    const record = records[url];
    assert.ok(record, `Missing recorded proof: ${url}`);
    if (record.startsWith("HTTP "))
      throw new ModuleDownloadError(Number(record.slice(5)), url);
    const bytes = transform(url, new Uint8Array(Buffer.from(record, "base64")));
    assert.ok(bytes.length <= max);
    return bytes;
  };
test("verified public module resolves from real signed log proofs and executes with the browser Go compiler", async () => {
  const prepared = await prepareModules(
    expected.files,
    (input) => engine.query(input),
    () => {},
    reader(),
  );
  assert.deepEqual(prepared.modules, expected.modules);
  assert.equal(prepared.goSum, expected.goSum);
  const result = await engine.perform(
    { ...expected.files, "go.sum": prepared.goSum },
    "run",
    "",
    { dependencies: prepared.files },
  );
  assert.equal(result.exitCode, 0, JSON.stringify(result));
  assert.equal(result.stdout, expected.stdout);
});
test("tampered module bytes and signed checksum-log evidence are rejected before use", async () => {
  await assert.rejects(
    prepareModules(
      expected.files,
      (input) => engine.query(input),
      () => {},
      reader((url, bytes) => {
        if (url.endsWith(".zip")) {
          const files = unzipSync(bytes),
            name = Object.keys(files).find((name) => name.endsWith("/uuid.go"));
          files[name] = new TextEncoder().encode("package uuid\n// tampered");
          return zipSync(files);
        }
        return bytes;
      }),
    ),
    /checksum|hash|mismatch/i,
  );
  await assert.rejects(
    prepareModules(
      expected.files,
      (input) => engine.query(input),
      () => {},
      reader((url, bytes) => {
        if (url.includes("/lookup/")) {
          const text = new TextDecoder()
            .decode(bytes)
            .replace("NIvaJDMO", "AIvaJDMO");
          return new TextEncoder().encode(text);
        }
        return bytes;
      }),
    ),
    /checksum|security|mismatch|authenticat/i,
  );
});
test("module versions follow Go semantic ordering including pseudo versions", () => {
  assert.ok(compareVersions("v1.10.0", "v1.9.9") > 0);
  assert.ok(compareVersions("v1.0.0", "v1.0.0-rc.2") > 0);
  assert.ok(compareVersions("v1.0.0-rc.10", "v1.0.0-rc.2") > 0);
  assert.ok(
    compareVersions(
      "v0.0.0-20240101000000-aaaaaaaaaaaa",
      "v0.0.0-20230101000000-bbbbbbbbbbbb",
    ) > 0,
  );
});
