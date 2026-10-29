# Three practical archive guides, published 29 October 2026

| Edition | Subject | Prose words excluding fenced code | Primary references | ImageGen assets |
| --- | --- | ---: | ---: | ---: |
| 24 October | Go database/sql pools, deadlines and transaction ownership | 2,230 | 6 | 3 |
| 25 October | Go HTTP and Kubernetes graceful shutdown | 2,215 | 6 | 3 |
| 28 October | Go concurrency tests with synctest and explicit events | 2,114 | 8 | 3 |

Edition dates fill the requested archive gaps. The actual publication date is **29 October**, displayed separately and retained in Article JSON-LD, Open Graph and RSS. These are original evergreen engineering guides, not fabricated historical announcements. Their examples, incident scenarios and configuration budgets are editorial work rather than benchmark results.

All nine assets were produced by separate built-in ImageGen calls. `assets.json` records exact prompts, originals, project WebP paths, dimensions and hashes. Runtime assets total 898,758 bytes. No stock-photo substitution or programmatic image generation was used; PNG originals were encoded as WebP without changing the composition.

The `examples/` directory contains complete original Go sources and tests, also offered as `/downloads/go-engineering-examples-20261029.zip`. Native Go 1.27.3 passed `go test -race -count=100 -timeout=30s ./...`. Three intentional synctest defects were detected. The SQL driver is synthetic and HTTP tests bind loopback; this is not a real PostgreSQL, Kubernetes, load-test or native-app sandbox certification. See `examples-qa.json`.

36 web tests and the production build passed. The three new pages and 35 internal destinations passed local checks, with self-canonical URLs, Article schema, three illustrations, descriptive alt text, code formatting, archive dates and a working download. All three pages measured 390px document width at a 390px viewport. The public sitemap now has **442 URLs**, and RSS has **21 original articles**. The official Google test of the published synctest guide found **two valid items** (Article and Breadcrumbs); this is not proof of indexing or ranking.

Production source is `62d6054`; Hostwatch deployment `gopherforge-archive-62d6054-20261029` succeeded. A preflight first exposed exhausted server disk availability. Only unused GopherForge images and reproducible superseded GopherForge contexts were removed, leaving 4.5 GiB available and several recent rollback images. The replacement retained the progress volume and restart policy. A disposable snapshot survived replacement, was checked for noindex headers and was revoked afterwards. The external feed was delivered into the replacement. The user's local port-3064 Playground was not restarted, and no native app binary was changed.

Publication evidence: `publication.json`, `prepublication-qa.json`, `server-build-cleanup.json`, `published.jpg`. Sources and scope: `research.json`. The three Markdown files mirror the published editorial text.
