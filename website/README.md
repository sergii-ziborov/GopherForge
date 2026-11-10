# GopherForge web

Next.js App Router website, blog and complete native-course library. Readings,
code, diagrams, editorial architecture comparisons and three-choice checks are
available without registration. Progress is local browser storage, independent
of native progress; no server-side code execution or grading is claimed. The browser Playground runs Go locally in a dedicated worker.

## Browser Go toolchain

The browser reuses the pinned native Go 1.27.1 compile/link artifacts, with a small
Go parser/planner built from `toolchain/planner.go`. To prepare generated assets:

```sh
GOPHERFORGE_GO=/path/to/go1.27/bin/go ./scripts/build-go-browser.sh
```

The pinned native artifact must already exist in `../GopherForge/Resources/Toolchain`.
The generated manifest records exact asset hashes; `public/toolchain` is ignored
build output and must be included in runtime bundles. Keep the Go license and
patent notice beside those assets. Source never goes to a remote compiler.

## Browser IDE and rooms

The workspace offers Run/Test/Check/Format/Build, a source debugger ported from
the native AST instrumentation, a searchable file tree and a resizable output
dock. Debug pauses the worker through SharedArrayBuffer; the Playground route
and worker assets require the configured COOP/COEP headers. Links into
Playground use document navigation so those headers take effect even from a
non-isolated course/home page. Production uses Next’s webpack builder so the TypeScript Worker is bundled as
JavaScript, rather than emitted as a raw media asset. Original source is
compiled before instrumentation. Never auto-run received source or room requests.

`toolchain/modules.go` uses x/mod's official checksum database client and pinned
sum.golang.org key. `go-modules.ts` verifies Go h1 archive hashes, resolves bounded
public module graphs and caches prepared source separately from user files.
Run the deterministic captured-proof tests with `pnpm test`. Refresh the UUID
integration fixture deliberately with `node scripts/verify-go-modules.mjs`;
that command contacts the official public Go proxy/log and executes the result.

Encrypted browser rooms use Yjs and AES-256-GCM, with the encryption key only in
URL fragments. The bounded in-memory `/api/playground/secure` endpoint receives
ciphertext, enforces Edit/View/Owner capabilities and uses exact-head snapshot
compaction/publication. The hook keeps a server-only CRDT replica so compaction
never publishes unacknowledged local updates as if they were already shared.
Offline edits and conflicted/deleted files remain recoverable/exportable.
Legacy `/api/playground` and remote MCP retain the compatible native protocol;
they see plaintext and reject whole-file revision conflicts. Public native 1.3.2 and remote MCP use the compatible mode. Native 1.3.3 (52),
currently in preparation, also joins encrypted rooms through the same Yjs wire format.
Both modes ask for a nickname and show named cursors and bounded edit history.
MCP clients call `playground_join` before attributed writes; a configured View bearer
cannot escalate through another participant capability.

The trusted native JavaScriptCore engine is built from the same model with
`node scripts/build-native-collaboration.mjs`. Regenerate the checked-in
`../GopherForge/Resources/PlaygroundCRDT.js` and license notices whenever that
model changes. Native CryptoKit handles AES-GCM; this bundle never executes Go.

## Content and development

The native source is authoritative. From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/export_lesson_catalog.sh
python3 website/scripts/sync-content.py
cd website
pnpm install --frozen-lockfile
pnpm test
pnpm build
pnpm start
```

Requires Node 22+ and the pinned pnpm version in package.json. Local preview:
http://127.0.0.1:3047. Course content and all lesson routes are prerendered;
search receives only summaries, not the full source catalog. Highlighting is
server-side. No runtime CMS, registration, database or browser analytics SDK.
Blog articles are authored in `src/content/posts.json`; original news and
analysis live in `src/content/news.json`. Keep verified event dates separate
from actual publication dates: the journal orders events, while RSS orders
publications. Include the source-check date, primary references, related
articles and three generated assets per story. Asset prompts and hashes are
recorded in `../docs/website/news-image-manifest.json`. Existing native lesson
IDs are URL slugs; keep them stable.

## Deployment

`Dockerfile` builds a non-root standalone Next.js service. Build from this
directory or use `deploy/compose.yaml`, which binds the app to loopback, limits
resources, drops capabilities and bounds logs. `deploy/Dockerfile.bundle`
packages a verified prebuilt `standalone/` release for hosts with little build
capacity. No credentials belong in either image.

`deploy/nginx.conf` provides the reverse proxy, canonical redirects and a
bounded JSON access log that omits query values and referrers;
`deploy/gopherforge.logrotate` keeps 14 daily rotations. Client IP handling must
follow the real trusted-proxy topology; never trust arbitrary forwarded headers.

Production is **https://gopherforge.app**. Before each update, keep the previous
revision for rollback and verify health, static assets, course navigation,
self-checks, progress, the sitemap and 404 behavior. There is no public
analytics dashboard or browser analytics SDK.
