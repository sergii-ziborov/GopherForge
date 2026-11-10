#!/usr/bin/env node
import { main } from "../dist/index.mjs";
await main().catch(() => {
  // Errors from configuration, decryption and HTTP never echo links or keys.
  console.error("GopherForge MCP could not start. Check Node 22+, the encrypted room link and your nickname. Run gopherforge-mcp --help for setup.");
  process.exitCode = 1;
});
