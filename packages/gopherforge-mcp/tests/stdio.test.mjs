import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { fixture, files } from "./fixtures.mjs";
import { secureAction } from "../../../website/src/lib/secure-relay.ts";
import { fileURLToPath } from "node:url";

test("published JavaScript entry point serves official MCP clients over stdio without leaking room keys", { timeout: 30000 }, async () => {
  const relay = http.createServer(async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    try {
      assert.equal(request.url, "/api/playground/secure");
      const value = secureAction(JSON.parse(Buffer.concat(chunks).toString()), request.headers.authorization?.replace(/^Bearer /, ""));
      response.writeHead(200, { "Content-Type": "application/json" }); response.end(JSON.stringify(value));
    } catch (error) { response.writeHead(error.status || 500, { "Content-Type": "application/json" }); response.end(JSON.stringify({ error: error.message })); }
  });
  await new Promise(resolve => relay.listen(0, "127.0.0.1", resolve));
  const origin = "http://127.0.0.1:" + relay.address().port, f = await fixture(origin);
  const executable = process.env.GF_MCP_PACKAGE_BIN || fileURLToPath(new URL("../bin/gopherforge-mcp.mjs", import.meta.url));
  const transport = new StdioClientTransport({ command: process.execPath, args: [executable], env: { PATH: process.env.PATH, GOPHERFORGE_ROOM_LINK: f.link("edit"), GOPHERFORGE_NICKNAME: "SDK agent", GOPHERFORGE_ORIGIN: origin }, stderr: "pipe" });
  const client = new Client({ name: "gopherforge-release-test", version: "1.0.0" });
  let stderr = ""; transport.stderr?.on("data", bytes => { stderr += bytes; });
  const call = async (name, args = {}) => { const reply = await client.callTool({ name, arguments: args }); assert.ok(!reply.isError, JSON.stringify(reply)); return reply.structuredContent ?? JSON.parse(reply.content[0].text); };
  try {
    await client.connect(transport);
    const tools = await client.listTools();
    assert.deepEqual(tools.tools.map(t => t.name).sort(), ["playground_cursor", "playground_join", "playground_leave", "playground_read", "playground_request_run", "playground_write"]);
    assert.equal(client.getServerVersion().name, "gopherforge-mcp");
    const joined = await call("playground_join", { nickname: "Chosen helper" }); assert.equal(joined.nickname, "Chosen helper");
    const current = await call("playground_read"); assert.deepEqual(current.files, files);
    const written = await call("playground_write", { sourceHash: current.sourceHash, files: { ...files, "note.txt": "Encrypted agent addition" } });
    assert.equal(written.executed, false);
    await call("playground_cursor", { path: "main.go", anchor: 4 });
    const request = await call("playground_request_run", { sourceHash: written.sourceHash, phase: "test" });
    assert.equal(request.requestState, "awaiting_local_button"); assert.equal(request.executed, false);
    const resource = await client.readResource({ uri: "gopherforge://room/current" });
    assert.equal(JSON.parse(resource.contents[0].text).files["note.txt"], "Encrypted agent addition");
    const invalid = await client.callTool({ name: "playground_read", arguments: { roomLink: "not permitted" } });
    assert.ok(invalid.isError);
    await call("playground_leave");
    assert.equal(stderr.includes(f.secret), false); assert.equal(stderr.includes(f.room.capabilities.edit), false);
  } finally {
    await client.close(); f.close(); relay.closeAllConnections();
    await new Promise(resolve => relay.close(resolve));
  }
});
