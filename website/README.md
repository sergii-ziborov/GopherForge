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
Blog articles are authored in `src/content/posts.json`. Existing native lesson
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

An operator must provision TLS, install the proxy and rotation config, register
the site's domains/logs in Hostwatch and configure an allowlisted image and
deployment target for this service. `deploy/hostwatch-site.example.json` is an
integration worksheet, not an executable Hostwatch configuration schema. The
connected Hostwatch MCP currently has no GopherForge target, so this project
has **not yet been deployed there**. No existing production website or DNS has
been replaced by these files.

Before domain cutover, verify the container health endpoint, static assets,
lesson navigation, search, self-checks, local progress, sitemap and 404 response
on the new origin. Verify Hostwatch receives a real request and separates this
site's traffic from other projects. Keep the previous origin available for
rollback. DNS and TLS must support both apex and www before redirects are used.

There is no public analytics dashboard. Analytics uses operational reverse-proxy
logs and Hostwatch's authenticated operator view. A deployment configuration is
not proof that analytics has received data; only a live traffic read establishes
that integration.
