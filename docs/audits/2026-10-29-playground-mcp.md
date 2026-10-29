# MCP Playground and explicit progress links — 29 October 2026

The owner requested interactive Claude/Codex access, execution only on the device whose person pressed Run, shared Output, mobile connection guidance and progress URLs usable by other assistants. This is a development preview, separate from the already-submitted 1.3.1 (49). The preview does not complete the full 18-package roadmap.

## Implemented contract

- Guest temporary rooms with separate Owner/Edit/View capabilities. 32 room capacity; 32 text files, 64 KiB/file, 256 KiB source per room. One-hour UI lifetime; fixed expiry and early restart/owner closure. Relay storage is volatile memory, with at most 256 KiB retained result text per room. No compiler, shell or eval on the relay.
- Shared edits use exact revision compare-and-swap. A stale edit is rejected; native and browser drafts remain local. This is not CRDT merging or browser Go execution.
- Native Run/Test takes an immutable source snapshot and uses the existing bundled Go/WASI compiler. A separate participant credential may publish only its own result. Peers only receive Output labelled with the reporting device and source revision. Remote edits, joins, reconnects and AI requests never call a compiler. Native Stop limits are unchanged.
- Stateless Streamable HTTP MCP at `/mcp`: initialize, ping, tools/list/call, resource reads with optional bearer credentials. Public tool discovery needs no account; every room operation requires its capability. Tools: playground_read, playground_write, playground_request_run, learning_progress_read. Run requests wait for a local button.
- Mobile uses the HTTPS MCP connector supported by the AI client, not a Node process on iOS. The app participates only while foregrounded. A real Claude/Codex mobile-account connection is not claimed from a protocol test.
- Explicit progress publication returns a public/unlisted 90-day HTML and JSON snapshot, with a separate revocation key. Whitelisted IDs, app-reported compiler marks, self-assessments and saved places only: no code, drafts, attempts, names or device identifiers. Publication and opening a link do not mutate local progress.
- Progress files have a separate persistent volume and a daily expiry service. Room state remains intentionally volatile. The relay can read shared source/Output; this preview is not end-to-end encrypted. Links are bearer access, not named-user permissions.
- Four existing coding-agent readings and two interview answers were expanded with MCP, execution provenance, mobile scope, conflict recovery, progress context and prompt-injection boundaries. Existing IDs and counts (220 teaching / 22 challenges / 173 readings; 132 interview guides) stay intact.

## Verification

- 33 web checks passed, including roles, stale revision rejection, invalid paths, exact Unicode identity, per-device result ownership, idempotent final results, expiry, snapshot filtering/revocation and MCP protocol behavior.
- 14 native model/content checks passed in `build/playground50/contracts-fixed.xcresult`. This includes an actual bundled Go run with Output received by a separate seat whose compiler call count remains zero; independent explicit runs on two seats; exact draft relaunch; and progress export without changing the store.
- Official `@modelcontextprotocol/sdk` 1.32.2 connected through Streamable HTTP, initialized, listed tools, read/wrote a revision and requested a run. Automatic run count remained zero; a View write was rejected.
- Earlier failing content gate was retained in `build/playground50/contracts.xcresult`; new diagrams were missing walkthroughs and the MCP specification host was absent from the reference allowlist. Both were corrected before the passing rerun.
- Production web build and local browser room creation checked. Two native UI checks also passed in Release (`build/playground50/ui.xcresult`): Projects → Playground → local Go output and Learn → Share progress → preview without publishing. Production deployment and beta delivery receipts follow when confirmed. No full app regression, remote iCloud sync, browser execution or physical airplane-mode certification is claimed.

## Sources

- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
- https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- https://learn.chatgpt.com/docs/extend/mcp
- https://code.claude.com/docs/en/mcp
- https://support.claude.com/en/articles/11175166-getting-started-with-custom-connectors-using-remote-mcp

## Final lifecycle follow-up

The first internal upload (50) was expired before final delivery after the expiry/reconnect walkthrough identified a missing local Leave action. Final candidate 51 adds **Leave room, keep local draft**, including after an expiry/restart, preserves last local Output on disk and prevents an older pending-result acknowledgement from clearing a new room’s result. Existing local files and learning records are unchanged. Browser reconnection was exercised with an unpublished edit followed immediately by reload: the exact draft stayed visible, publication was blocked for review, and the owner’s Close action survived reload.

Apple also released 1.3.1 (49) automatically: live App Store Connect now reports READY_FOR_SALE. The site and README status are updated separately from the new MCP beta; the release receipt is `docs/releases/1.3.1-build49-release.json`.

## Confirmed final beta

**1.3.2 (51)** is VALID / IN_BETA_TESTING in Internal QA, native source `697ee9b`. The final lifecycle model/content gate passed 14 checks and the final Release UI gate passed two checks; the UI test now requires a new run to finish rather than accepting a restored previous result. Public 1.3.1 (49) remains separate. Native and web source stay aligned; the web editor also retains clean incoming revisions in its local backup. See [beta receipt](../releases/1.3.2-build51-beta.json).
