import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, lstat, chmod, rm } from "node:fs/promises";
import path from "node:path";
import { tmpdir } from "node:os";
import { saveConfig, readConfig, configPath } from "../dist/index.mjs";
import { fixture } from "./fixtures.mjs";

test("interactive connection configuration uses private local permissions and environment overrides", async () => {
  const temporary = await mkdtemp(path.join(tmpdir(), "gopherforge-mcp-test-")), env = { XDG_CONFIG_HOME: temporary }, f = await fixture();
  try {
    await saveConfig({ roomLink: f.link("edit"), name: "My helper", origin: "https://gopherforge.app" }, env);
    assert.equal((await lstat(configPath(env))).mode & 0o777, 0o600);
    const config = await readConfig(env); assert.equal(config.name, "My helper"); assert.equal(config.roomLink, f.link("edit"));
    assert.equal((await readConfig({ ...env, GOPHERFORGE_ROOM_LINK: f.link("view"), GOPHERFORGE_NICKNAME: "Other seat" })).name, "Other seat");
    await chmod(configPath(env), 0o644);
    await assert.rejects(readConfig(env), /private/);
  } finally { f.close(); await rm(temporary, { recursive: true, force: true }); }
});
