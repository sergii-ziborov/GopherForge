# GopherForge web

Next.js App Router website, blog and complete native-course library. Readings,
code, diagrams, editorial architecture comparisons and three-choice checks are
available without registration. Progress is local browser storage, independent
of native progress; no server-side code execution or grading is claimed.

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

## Hostwatch deployment and analytics

`Dockerfile` builds a non-root standalone Next.js service. Build from this
directory or use `deploy/compose.yaml`. Compose binds the app to loopback,
limits resources, drops capabilities and bounds logs. Inspect the runtime UID
if your platform remaps non-root users; adjust cache tmpfs ownership if needed.

`deploy/nginx.conf` provides reverse proxy, canonical redirects and a bounded
JSON access stream compatible with Hostwatch's traffic reader. It intentionally
omits query values and referrers. `deploy/gopherforge.logrotate` retains 14 daily
rotations. Client IP handling must follow the real trusted-proxy topology;
never trust arbitrary inbound forwarded headers.

Production: **https://gopherforge.app**, hosted on the existing Hetzner
application node with Hostwatch site ID `gopherforge` and governed target
`gopherforge-web`. Registration and DNS remain managed in Lovable; apex and
www point to the Hetzner origin. Nginx redirects www and HTTP to the HTTPS apex.
The previous Lovable project remains available at its lovable.app address.

`deploy/provision-hostwatch.py` is the additive operator setup for this
installation. It preserves unrelated profiles and governance, writes an atomic
config with a timestamped backup, and registers the exact non-root deployment.
The production profile uses UID/GID 10001, 256 MiB, half a CPU and loopback port
3047. Hostwatch MCP performs digest/revision-checked deployments and health
verification. `deploy/gopherforge-web.service`, the container's
`unless-stopped` policy and the enabled Podman restart unit provide startup
recovery. Reapply the restart policy after a governed container replacement. After replacement,
restore the news cache into the new container's writable tmpfs with
`python3 /srv/apps/gopherforge/news-feed/deliver.py /var/lib/gopherforge-news`
on the origin. Verify the community reader shows **Feed connected**; its
bundled saved edition is a fallback, not evidence of a live cache.

For a verified prebuilt standalone release on a capacity-constrained origin,
`deploy/Dockerfile.bundle` packages `standalone/` from the release build. It
replaces the builder's traced Sharp links with the same Sharp version installed
for Linux. Keep the build's Git revision and catalog hash in a release receipt;
verify the Next dependency's Sharp import and all public routes on the target.
Build with Podman's `--format docker` to retain the image health check, and
bound build CPU/memory. The full source Dockerfile remains the portable build
path when build capacity is available. No credentials belong in either bundle.

The installed agent tails the shared `/var/log/nginx/hostwatch.json.log` stream.
Nginx writes this site's query-free JSON to that stream as well as the separate
14-rotation GopherForge log; merely creating a per-site log would not feed this
agent. Live Hostwatch traffic reads have verified requests under this site ID.
Both apex/www certificates were issued before cutover and the new lineage was
reconfigured to HTTP webroot renewal. Certbot's staging renewal passed, and
`certbot.timer` remains enabled with the existing Nginx renewal hook.

Before each update, inspect `deployment_preview`, keep the old revision for
rollback, and verify health, static assets, course navigation, self-checks,
progress, sitemap and 404 behavior. Domain rollback requires reconnecting the
existing Lovable project and restoring its previous A records. Do not alter
registration, unrelated DNS records, other sites or registry credentials.

There is no public analytics dashboard. Analytics uses operational reverse-proxy
logs and Hostwatch's authenticated operator view. A deployment configuration is
not proof that analytics has received data; only a live traffic read establishes
that integration.
