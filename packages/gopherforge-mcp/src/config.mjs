import { homedir } from "node:os";
import path from "node:path";
import { mkdir, lstat, readFile, writeFile, rename } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";
import { EncryptedRoomClient, parseRoomLink } from "./room-client.mjs";
import { nickname } from "../../../website/src/lib/playground-identity.ts";

export const configPath = (env = process.env) => path.join(env.XDG_CONFIG_HOME || path.join(homedir(), ".config"), "gopherforge-mcp", "connection.json");
export async function readConfig(env = process.env) {
  if (env.GOPHERFORGE_ROOM_LINK) return {
    roomLink: env.GOPHERFORGE_ROOM_LINK,
    name: env.GOPHERFORGE_NICKNAME,
    origin: env.GOPHERFORGE_ORIGIN || "https://gopherforge.app",
  };
  const filename = configPath(env);
  let info;
  try { info = await lstat(filename); }
  catch { throw Error("Run gopherforge-mcp setup, or configure GOPHERFORGE_ROOM_LINK."); }
  if (!info.isFile() || info.isSymbolicLink() || info.size > 4096 || (process.platform !== "win32" && ((info.mode & 0o077) || (process.getuid && info.uid !== process.getuid()))))
    throw Error("The GopherForge connection file must be private to your user. Run setup again.");
  const value = JSON.parse(await readFile(filename, "utf8"));
  if (!value || typeof value.roomLink !== "string" || typeof value.name !== "string") throw Error("Invalid GopherForge connection file.");
  return { roomLink: value.roomLink, name: env.GOPHERFORGE_NICKNAME || nickname(value.name), origin: value.origin || "https://gopherforge.app" };
}
export async function saveConfig(config, env = process.env) {
  parseRoomLink(config.roomLink, config.origin);
  const filename = configPath(env), folder = path.dirname(filename);
  await mkdir(folder, { recursive: true, mode: 0o700 });
  const temporary = filename + "." + randomUUID() + ".tmp";
  await writeFile(temporary, JSON.stringify({ roomLink: config.roomLink, name: nickname(config.name), origin: config.origin || "https://gopherforge.app" }, null, 2) + "\n", { mode: 0o600, flag: "wx" });
  await rename(temporary, filename);
  return filename;
}
export async function setup(env = process.env) {
  if (!process.stdin.isTTY) throw Error("Run setup in an interactive terminal; it is separate from MCP stdio.");
  let muted = false;
  const output = new Writable({ write(chunk, _encoding, done) { if (!muted) process.stderr.write(chunk); done(); } });
  const prompt = createInterface({ input: process.stdin, output, terminal: true });
  let config;
  try {
    const name = nickname(await prompt.question("Your agent's display nickname (1–32 characters): "));
    process.stderr.write("Paste the complete Encrypted Edit/View link (hidden): ");
    muted = true;
    const roomLink = (await prompt.question("")).trim();
    muted = false; process.stderr.write("\n");
    config = { roomLink, name, origin: env.GOPHERFORGE_ORIGIN || "https://gopherforge.app" };
  } finally { muted = false; prompt.close(); }
  const client = new EncryptedRoomClient({ ...config, pollMs: 0 });
  try { await client.join(); }
  finally { await client.leave(); }
  const filename = await saveConfig(config, env);
  console.error("Encrypted room verified. Saved a private local connection file at " + filename + ". The room key is not sent to the relay.");
}
