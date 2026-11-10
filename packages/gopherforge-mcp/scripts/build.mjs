import { build } from "esbuild";
import { readFile, writeFile, copyFile, mkdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = fileURLToPath(new URL("../", import.meta.url));
await mkdir(path.join(root, "dist"), { recursive: true });
await build({
  absWorkingDir: root,
  entryPoints: ["src/index.mjs"],
  outfile: "dist/index.mjs",
  bundle: true,
  packages: "external",
  platform: "node",
  format: "esm",
  target: "node22",
  legalComments: "eof",
});
await copyFile(path.join(root, "../../LICENSE"), path.join(root, "LICENSE"));
const sources = {};
for (const name of ["secure-collab.ts", "playground-files.ts", "playground-identity.ts", "source-fingerprint.ts"]) {
  sources[name] = createHash("sha256")
    .update(await readFile(path.join(root, "../../website/src/lib", name)))
    .digest("hex");
}
await writeFile(path.join(root, "protocol-manifest.json"), JSON.stringify({
  protocol: "gopherforge-browser-v2",
  encryption: "AES-256-GCM; 96-bit random IV; channel-bound AAD",
  sources,
}, null, 2) + "\n");
console.error("Built GopherForge's encrypted JavaScript MCP companion.");
