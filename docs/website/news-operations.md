# News and community reader

Published content is English. `/news` contains five GopherForge editorial analyses of events dated 16–20 October 2026; publication is dated 20 October rather than backdated to the event. Each article contains over 1,500 prose words, primary references, related reading and three distinct ImageGen illustrations (including an infographic). `news-image-manifest.json` records the assets, prompts and original workspace copies. Runtime WebP assets total about 2 MB; original PNGs remain in `build/news-seo/originals/`.

## Content and SEO

- Original articles: `website/src/content/news.json`; dates, source list, section anchors, interlinks, image prefix and prose word count.
- RSS: `/news/rss.xml`, five original editorial articles only.
- Sitemap: original articles with all three images; crawlable `/learn/units/[id]` subject hubs; lessons and interview guides.
- Article schema, canonical and Open Graph metadata; lesson LearningResource and breadcrumbs; subject hubs use Course schema. No invented reviews, ratings, CVEs or vendor endorsements.
- Imported articles are **noindex**, canonical to their original publisher and absent from the sitemap. They are not presented as original GopherForge reporting.
- `/login` and `/register` are explicitly inactive design previews with disabled inputs and no backend or credential storage. They are noindex. Course and interview access remains free without an account.
- `releases.json` is the website's release record. Sync reads it rather than restoring stale versions. Current public app: 1.1.4 (39); 1.1.5 (40) is TestFlight / waiting for App Review. Bundled Go remains 1.27.1. Native US price remains $6.99 one-time.
- Existing browser progress keys, Continue and course/interview data are preserved. Browser and app progress are independent.

## Full external articles

Initial source: `https://go.dev/blog/feed.atom`. The feed provides full article HTML, not only summaries. Ten initial articles contain 545–5,109 words each. Text, code, headings, lists and article reference URLs are retained; layout is adapted, active HTML and embeds are removed, third-party images are not republished. Each reader identifies the original author, date, source, CC BY 4.0 licence and changes. Source/credit links remain public because attribution is required. Go code's BSD notice and disclaimer are available at `/licenses/go-code.txt`.

Licence evidence: `https://go.dev/copyright` and `https://creativecommons.org/licenses/by/4.0/`. RSS availability alone is not treated as republication permission. Golang Weekly (`https://golangweekly.com/rss/`) and Microsoft's Go blog (`https://devblogs.microsoft.com/go/feed/`) were discovered but are not copied in full without verified permission. Future unlicensed source-link access can route to registration once accounts exist; the current preview does not pretend access can be unlocked.

## Scheduled refresh

The existing Hetzner origin runs the importer twice daily at **06:15 and 18:15 UTC**, with up to three minutes of jitter and a persistent timer. New articles are imported when the publisher posts them; the schedule does not fabricate two daily stories.

- Code: `/srv/apps/gopherforge/news-feed/{sync.py,deliver.py,run.sh}`
- Persistent last-good state: `/var/lib/gopherforge-news/{feed.json,status.json}`
- Units: `gopherforge-news.service`, `gopherforge-news.timer` (repository templates under `website/scripts/feed/`).
- Importer: fixed HTTPS source, bounded response/entry sizes, timeout, redirect allowlist, XML entity rejection, lock, source-URL deduplication, up to 100 retained items, atomic cache replacement. Failed fetches retain the previous edition and record failure status.
- Delivery: checks the exact container and `io.hostwatch.publication=gopherforge-web` ownership label; uses Podman copy and an atomic rename inside the existing `/tmp` tmpfs. Container root remains read-only, no new public port or mount, no Hostwatch governance/config change.
- Reader uses `/tmp/gopherforge-news-feed`, overridable via `GOPHERFORGE_FEED_DIR` for local verification. A bundled licensed seed remains readable if the live cache is absent.
- Following deployment/recreation, run the service once to restore the current host cache. The site's existing recovery unit also restores it after a container restart. Verify the actual timer and recovery configuration in the publication receipt.

Operations:

```sh
systemctl status gopherforge-news.timer gopherforge-news.service
systemctl list-timers gopherforge-news.timer
journalctl -u gopherforge-news.service --since today
systemctl start gopherforge-news.service
```

Publication uses the existing Hostwatch image target and preview/digest/revision workflow. Keep the previous image digest for rollback. Rolling back the site image does not remove the host's feed state. To stop refresh without deleting content: `systemctl disable --now gopherforge-news.timer`.

## Verification

`pnpm test` covers native/web content parity, existing progress round trips, substantive original articles, assets and licensed seed. `python3 -m unittest discover -s scripts/feed -p 'test_*.py'` checks full-text/code preservation, unsafe input rejection and last-good preservation. `SITE_URL=... node scripts/smoke.mjs` checks 333 routes plus internal links, schema, canonical, sitemap images, RSS, attribution, inactive forms, version copy and retained pricing. Publication receipt records the exact tested build, timer status, public checks and visual evidence.
