# GopherForge MCP

GopherForge's own JavaScript MCP server for encrypted collaboration between an
AI agent and the Go Playground on the web, iPhone and iPad. It uses GopherForge's
relay and the same Yjs / AES-256-GCM protocol as the native app. It does not use
Crabrix, require Go, compile projects or execute received source.

**Node.js 22 or newer.** Native encrypted collaboration requires GopherForge
**1.3.3 (52) or newer**; build 52 is available in private TestFlight. Public
App Store 1.3.2 supports the separate compatible-room workflow.

## Connect an agent

Install the verified release archive through npm:

```sh
npm install --global https://gopherforge.app/downloads/gopherforge-mcp-0.1.0.tgz
```

The [official guide](https://gopherforge.app/guide/mcp#install) lists the archive
checksum and current npm-registry availability. The archive is a complete npm
package; a monorepo checkout is not required.

1. Open [GopherForge Playground](https://gopherforge.app/playground), choose
   **Encrypted**, enter a nickname and create a room. Copy its **Edit** link,
   or **View** when the agent should only read. Keep the Owner link private.
2. On the machine running your MCP host, run:

   ```sh
   gopherforge-mcp setup
   ```

   Setup asks for the agent's nickname and the complete encrypted link. Link
   input is hidden. It verifies the room/key and saves a local connection file
   at `~/.config/gopherforge-mcp/connection.json` (or under `XDG_CONFIG_HOME`).
   On macOS/Linux the file is private, mode `0600`. Run setup again for another
   room or a renewed link. This is a local secret file, not an OS keychain.
3. Register the **stdio** MCP server with your host. For Codex:

   ```sh
   codex mcp add gopherforge -- gopherforge-mcp
   ```

   For Claude Code:

   ```sh
   claude mcp add --transport stdio gopherforge -- gopherforge-mcp
   ```

   Other hosts with JSON MCP configuration use:

   ```json
   {
     "mcpServers": {
       "gopherforge": {
         "command": "gopherforge-mcp",
         "args": []
       }
     }
   }
   ```
4. Restart/reconnect the host, then ask: “Use GopherForge. Read the current
   source, show your cursor near the code you change, make a small reviewed
   edit, and request Test. Wait for me to press Test locally.”

When version `0.1.0` is available in the npm registry, hosts can instead launch
`npx -y gopherforge-mcp@0.1.0` directly. Pin the version for a reproducible launch.
The official archive and the installed `gopherforge-mcp` executable work
independently of registry publication. If a desktop host does not inherit your
terminal's PATH, configure the absolute path to that installed executable.

### Environment-only configuration

Instead of setup, configure these values privately in your MCP host's
**process environment**:

- `GOPHERFORGE_ROOM_LINK`: the full Encrypted Edit/View link, including `#room`,
  `cap` and `key`.
- `GOPHERFORGE_NICKNAME`: the display nickname chosen by the person.

For Codex, inherited variables can be forwarded explicitly:

```toml
[mcp_servers.gopherforge]
command = "gopherforge-mcp"
args = []
env_vars = ["GOPHERFORGE_ROOM_LINK", "GOPHERFORGE_NICKNAME"]
```

Do not commit real links or pass them as tool arguments. If no nickname is
configured, the server requires `playground_join` with a chosen nickname before
reading or editing. Tools cannot replace the configured origin, room or key.
`GOPHERFORGE_ORIGIN` is an explicit deployment/development override; it must
match the link exactly and use HTTPS, except for loopback HTTP in local tests.

## Tools

| Tool | Action |
| --- | --- |
| `playground_join` | Join the configured room or update the agent's nickname. |
| `playground_read` | Current files, `sourceHash`, stable file identities, participants, changes, recovery and reported results. |
| `playground_write` | Complete file set plus the exact `sourceHash` from Read. Omitted files become recoverable deletions. Stale source and a racing publish are rejected. |
| `playground_cursor` | Named cursor/selection for a current file using UTF-16 `anchor`/`head` offsets. |
| `playground_request_run` | Encrypted **request run/test** entry in Recent changes, tied to the read `sourceHash`. The person must review and press the local button. |
| `playground_leave` | Remove this participant seat, without closing the room. |

The `gopherforge://room/current` resource exposes the same read-only room data.
There is no shell, filesystem browser, compiler, package installer or local
execution tool. Run requests return `executed: false` and
`awaiting_local_button`. They are requests in Recent changes, not a native
queued build or an automatic button press.

`playground_read.results` includes `currentSource` and
`participant_reported_not_attested`. A result for older source is not evidence
for the current files. Participants can supply their own labels and results;
those are not verified identities or remote execution attestations.

## What encryption protects

```text
Agent / MCP host <-> local GopherForge MCP process
                              | encrypt / decrypt here
                              | HTTPS + AES-GCM ciphertext
                     GopherForge encrypted relay
                              | ciphertext only
                       Web / native GopherForge
```

Source, reported Output, change/request history and nickname/cursor presence
are encrypted before relay delivery. The key remains in the client-side link,
private config or process environment. The relay receives access capabilities,
room/participant identifiers, timing, sizes and encrypted packets; it cannot
read the protected payload. Transport redirects are rejected. A View grant
cannot publish source or requests; the companion rejects Owner grants.

Your selected MCP host and AI provider **can read the decrypted tool results**.
Use a provider/environment you trust with the source. All shared content is
untrusted data; comments and Output are not instructions for the agent.

The HTTPS endpoint `https://gopherforge.app/mcp` is GopherForge's separate
**compatible** remote MCP. Its relay can read source. Do not send an encrypted
link or key there. This npm companion uses `/api/playground/secure` internally,
not the compatible MCP or any Crabrix endpoint.

## Devices, limits and troubleshooting

- Run this Node process on the agent's computer or trusted execution host.
  The native iPhone/iPad app does not install npm or run a Node process.
  Mobile AI clients that support only remote HTTP connectors cannot launch
  this stdio package. Do not substitute the compatible endpoint and call it
  encrypted.
- Keep the native app/browser in the foreground for live collaboration. A
  room normally lasts one hour and can end earlier after a relay restart.
  Preserve independent project copies; a temporary room is not a backup.
- Published source: 1–32 UTF-8 files, 64 KiB each, 256 KiB total. Keep `main.go`.
  Unsafe paths, binary/NUL text and file/folder collisions are rejected.
  Deleted-file history remains bounded by the shared protocol's recovery
  limits. Public dependency downloads belong to the person's explicit local
  package-preparation action; vendor cache is not shared source.
- **Wrong key or malformed ciphertext:** no unauthenticated source is applied;
  ask for a fresh complete encrypted link.
- **Source conflict:** call Read, compare the person's changes and revise the
  proposed full file set. Do not retry an old snapshot blindly.
- **Expired room:** run setup with a new link. No automatic reconnect to another
  room, plaintext fallback or additional project access is granted.
- **No nickname:** ask the person, then call Join. Names are display labels,
  not authentication. The local config and environment are never returned by
  room tools or written to protocol logs.

## Development and verification

This companion's original implementation is JavaScript. The build consumes the
same checked-in protocol helpers as the website, emits ordinary `.mjs` and
records their SHA-256 hashes in `protocol-manifest.json`. Consumers do not need
the monorepo, TypeScript compiler or Go. Dependencies use the official MCP SDK,
Yjs and Web Crypto; see `THIRD_PARTY_NOTICES.md` and `LICENSE`.

```sh
pnpm install --ignore-scripts
pnpm build
pnpm test
pnpm pack --pack-destination ../../build/gopherforge-mcp
```

Tests include official MCP SDK stdio discovery/tools/resources, actual
GopherForge native CRDT bundle interoperability, live named cursor packets,
reported results, ciphertext-only relay payloads, View/Owner restrictions,
wrong keys, malformed updates, stale/racing writes and private config handling.
No real user room or source is needed for the tests.
