# GopherForge

<img src="GopherForge/Resources/Assets.xcassets/AppIcon.appiconset/GopherForgeIcon-1024.png" width="112" alt="GopherForge turquoise gopher with copper goggles on dark teal">

A native Go workspace for iPhone and iPad. Write, compile, run, test and learn
with a bundled Go 1.27.1 toolchain.

[App Store](https://apps.apple.com/app/id6809702319) ·
[Website](https://gopherforge.app) ·
[Course](https://gopherforge.app/learn) ·
[Interview preparation](https://gopherforge.app/interview) ·
[News](https://gopherforge.app/news) ·
[App guide](https://gopherforge.app/guide) ·
[Support](https://gopherforge.app/support)

<img src="docs/app-store/screenshots/iphone-6.9/00-code.png" width="330" alt="Go worker-pool source in the GopherForge editor on iPhone">

## Releases

| Version | Status, checked 10 November 2026 | Changes |
| --- | --- | --- |
| **1.3.3 (56)** | In App Review · private TestFlight | Named cursors, encrypted browser/native live rooms, shared change history, Playground debug/tools, complete course downloads and a local DevOps terminal. |
| **1.3.2 (51)** | Available on the App Store | Compatible MCP Playground, local execution, shared Output and progress links. |
| **1.3.1 (49)** | Available on the App Store | Expanded curriculum: 220 teaching lessons, 132 interview guides, Gin, blockchain, security and production design. |
| **1.3.0 (48)** | Earlier TestFlight · Superseded by 1.3.1 | Direct web preview, restored lesson drafts and Practice, source-safety/import audit, offline React/npm subset and source debugger. |
| **1.2.0 (45)** | Previous App Store release | 15 readings on JSON v2, SQL, modern concurrency and agents; 92 interview guides, 12 algorithm labs, new icon and app guide. |
| **1.1.6 (44)** | Available on the App Store | Two ownership readings: borrowed bytes, Scanner tokens and sync.Pool. 171 teaching lessons and 124 readings. |
| **1.1.5 (43)** | Available on the App Store | Continue for Course and Interview, matching learning layouts, saved progress, and compact Projects/Learn/Settings roots. Fresh learning screenshots for six device sizes. |
| **1.1.5 (42)** | Superseded by build 43 | Removed duplicate root headings while retaining titles and Back navigation inside details. |
| **1.1.4 (39)** | Previous App Store release | MongoDB/Redis and production tooling, 88 interview guides, eight interactive algorithm labs, transparent scroll endings. |
| **1.1.3 (37)** | Previous App Store release | Architecture comparisons, clean Go, all 23 classic patterns and six concurrent Go patterns. |
| **1.1.2 (36)** | Previous App Store release | Practical command-line, container and Kubernetes lessons. |

**1.3.2** is the current App Store release, published 29 October 2026.

**1.3.3 (56)** is in App Review and not yet released on the App Store. Its native/web course has **229 lessons for guided study, including 182 readings,
and 22 question-and-answer challenges in 29 units**, with the previous 220 teaching lessons and
all stable IDs retained. Existing public 1.3.2 has compatible MCP sharing and
132 interview guides.

**Complete offline courses:** Learn → Course downloads lists every course with
its size; a course installs only when you tap Download, from that screen or from
its own Learn area. It installs full Go, DevOps or Interview documents. Export/import complete official files; remove
content without losing progress, bookmarks, drafts or independent lab states.
Lessons never fetch their content automatically. The signed app keeps a small
pinned catalog and bundled trusted runtimes; course bodies and QA fixtures are
absent from Release. [Files and instructions](https://gopherforge.app/downloads).

**DevOps:** a separate area brings together 34 readings in four units, six local
terminal labs and a terminal playground with persistent private files. The
terminal is interactive: one prompt with history, Tab completion, continuation
lines, type-ahead, a key row for Tab, arrows and Ctrl-C, ANSI colours and a
built-in editor (`nano FILE`). The bounded WASI shell parses Bash syntax and
interprets it over a private `/lab`: globs, `$(…)`, arithmetic, heredocs,
functions, `case`, `[[ ]]`, `set -euo pipefail`, redirects including `2>&1`, and
coreutils-style `ls`, `find`, `tree`, `grep -E`, `sed`, `awk`, `cut`, `sort`,
`uniq`, `diff`, `xargs` and more (`help` lists them). It has no host processes,
sockets, SSH, Docker or kubectl. Real infrastructure practice requires an owned
disposable native environment.

TestFlight access is private; there is no public invitation link.
Release status is a dated snapshot, not a live indicator.

[Version history](https://gopherforge.app/updates).

The app is a one-time purchase: US $6.99, US $4.99 in Ukraine, with localized
App Store prices elsewhere. No subscription or in-app purchase.

## Current curriculum

The native 1.3.3 (56) build and the web mirror include **Go for DevOps and
reliability**: a delivery feedback loop, bounded operational CLIs, reconciliation,
verified artifact promotion, SLO/error-budget burn, incident/data recovery, IAM, IaC state and DNS/TLS evidence.
Six complete Go examples, including a service capstone, have independent executable checks. Native process,
network and infrastructure exercises explicitly use your own disposable native
environment. The app does not become a cloud shell. Existing Bash/Git, Linux,
container, Kubernetes, security, database and coding-agent material is retained.

The 6 November course review aligns
self-checks in 48 readings, updates the encrypted-agent workflow and adds a
[tested DevOps capstone](docs/examples/go-devops-capstone/README.md). All 44
exercise solutions pass their hidden tests, all unfinished starters are rejected,
and 98 complete reading programs compile with native Go. These lesson refinements
are available on the web and in build 56. Stable lesson IDs and progress formats are preserved.


## What you can do

- **Build real Go.** Compile, run, test, vet and format on device. Compiler
  diagnostics point to source locations; test results are shown per case.
- **Keep your projects.** Editable multi-package sources, a searchable file
  tree, folders, tags, favorites and autosave. Import GitHub snapshots or Files
  folders; export and share your work.
- **Use the screen you have.** A compact iPhone editor, an iPad file tree and
  resizable dock, and adaptive Duo layouts. In laptop posture, code or Terminal
  stays above the hinge while keyboard or results occupy the lower display.
- **Learn Go.** The 1.3.3 source has 229 teaching lessons in 29 units, including 182 readings,
  plus 22 prediction challenges. Worked Go programs, diagrams, matching
  reviews and three-choice mistake practice accompany the material.
- **Continue studying.** Reopen the last course lesson or interview guide.
  The selected learning area, lesson completion, compiler-verified evidence
  and personal interview marks persist locally. Opening a page saves your
  place; it does not mark the material complete.
- **Explore concurrency.** Nine runnable Concurrency Lab scenarios show the
  events their goroutines and channels report as timelines.
- **Prepare for interviews.** A separate area with 132 worked guides, 15 topics,
  four difficulty levels and twelve interactive algorithm labs with 36 input
  scenarios. Course progress and interview self-assessment stay independent.
- **Read idiomatic code.** A deterministic, rule-based Idiom Coach, 14 original unit
  interview questions and 12 spot-the-bug exercises.
- **Try working examples.** Multi-package programs, Go-generated PNGs, and
  HTML/CSS/JavaScript projects previewed locally in WebKit.

### Architecture and patterns

The course includes **19 architecture lessons**, **eight clean-code lessons**,
plus **nine production system-design lessons** and **four advanced clean-code lessons**,
all **23 classic design patterns** and **six concurrency and resilience patterns**.
Scenario-based architecture ratings compare suitability for tools, domain-rich
applications and services; they are editorial guidance, not universal rankings.
Worked programs, diagrams, tradeoffs and independent review questions accompany
the material.

The 19 architecture and eight clean-code readings now include 81 further
sections on package structure, consistency, transactions, failure recovery,
API contracts, testing and incremental migration. Lesson IDs and saved progress
remain unchanged.

### Data stores and production tooling

Six MongoDB and six Redis readings are included in **Around Go: MongoDB
and Redis**. They cover shared clients, indexes, optimistic updates,
transactions, cursors, pool saturation, cache-aside, pipelines, leases,
consumer groups and latency/memory evidence. Go v2 MongoDB and go-redis v9
examples name their pinned versions and distinguish fragments from full programs.
Network examples run in a native development environment; WASI networking
and the existing module archive budgets are unchanged.

Packages, modules and tooling contains **14 teaching lessons**,
with the three existing prediction challenges preserved. Twelve new readings
explain version selection, checksums and private modules, workspaces, vendor,
embedded/generated inputs, parallel tests, benchmarks, profiles, build capacity,
toolchain/tool pins, fuzzing and startup/shutdown ownership. Every new reading
has a flow diagram, primary references, its own matching pair and a three-choice
review question.

Native code and lessons remove the lower scroll-edge backdrop and keep extra
end space inside scrollable content. This adds no source lines and preserves
the embedded-versus-full-screen lesson scrolling behavior.

### Web previews and Gin compatibility

Gin-style templates use an educational compatibility layer rather than the full
upstream Gin framework. Registered handlers are exercised through `httptest`;
the native app serves compatible local preview files. An arbitrary Go backend
cannot bind a listener inside the WASI guest. Full Node.js/npm runtimes are not bundled.
Full Gin/database services need an external native environment.

#### 1.3.0 beta: isolated offline React and source debugging

The beta adds **React + Gin study board** in Examples → Offline frontend. This feature is included in the current App Store 1.3.1 (49) binary. It bundles
esbuild 0.28.2 as WASI and a fixed browser catalog: React / React DOM 19.3.1
and scheduler 0.28.0. The installed app needs no registry or server for this mode.

```text
frontend packages
npm install --offline
npm run build
frontend preview
```

Native build 48 also offers **Output → Build & Preview**, plus
full-screen, reload and project sharing controls. Legacy static previews can
open in the browser or share their on-device address; isolated React previews
keep their WebKit-only origin and share the project archive. A loopback address
is not a public link. See [preview controls](docs/OFFLINE_FRONTEND.md#preview-controls-native-build-48).

Open Output for the preview. `frontend install/build` and the supported npm
commands invoke this app's bounded frontend builder, **not a full npm runtime**.
The compiler transpiles JS/JSX/TS/TSX, bundles browser imports, local JSON and CSS, and handles
SVG/text imports. TypeScript is not type-checked. Edit components, reducers,
forms or styles, then rebuild; stale previews are invalidated.

The preview reads generated assets and `web/api/*.json` through an isolated
WebKit scheme with no TCP listener. External HTTP(S), WebSockets, workers,
frames and popups are blocked. Preview browser data is temporary. Project
sources and generated output are autosaved in the project library.

Only bundled package versions are accepted. Package scripts must explicitly
use `gopherforge build` / `gopherforge preview`; lifecycle hooks, arbitrary
scripts, Node APIs, native addons, Vite plugins and remote package installation
are not supported. An explicit `gin-replay` recipe enables local requests to
real Go handlers through the educational Gin-compatible layer. Requests rebuild
small deterministic in-memory state using a bounded mutation log; no socket,
cloud runtime or general production server is added. The built-in study board
uses static JSON fixtures. A pinned external React + Gin GitHub project was used
only for interoperability tests; its code and example are not bundled in the app.
See the [offline frontend guide](docs/OFFLINE_FRONTEND.md) for the recipe and limits.

Tap a Go line number to set a breakpoint. **Run is unchanged with no breakpoints;
with breakpoints it automatically starts the beta source debugger.** Continue,
Step Into/Over/Out, Stop, an own-source call stack and bounded current-frame
locals are available. Temporary probes never overwrite saved source. Breakpoints
persist per project. This is a teaching source debugger, not full Delve:
[debugger guide](docs/SOURCE_DEBUGGER.md).

### JSON v2, modern concurrency, SQL and agents

The 1.2.0 curriculum adds fifteen worked readings. Three cover JSON v2 contracts,
presence/null semantics and input policy. Three explain WaitGroup.Go, deterministic
synctest timing and errgroup ownership. **Around Go: SQL services** has five lessons
on pools, row cleanup, transaction ownership, isolation/locking and bounded retries.
**Around Go: coding agents** has four lessons on practical workflows, repository
instructions, generated API verification and trust boundaries. SQL and agent
examples target an external native environment, not new app network integrations.

The audit also corrected Stack.Pop's retained references, Sum's numeric type
constraint and the three language-level iterator signatures. All existing lesson
IDs are preserved. The detailed [app guide](https://gopherforge.app/guide) explains
projects, testing, Continue, practice, package budgets and the sandbox.

### Interview preparation and coding agents

Learn has a separate **Interview** area, mirrored at [gopherforge.app/interview](https://gopherforge.app/interview), free on the web without registration. It contains **132 worked guides across 15 topics**, from Junior to Staff / expert: Go values and interfaces, memory/runtime, concurrency, algorithms, architecture, HTTP/SQL, testing/performance, modules/tooling, MongoDB, Redis, Docker/Kubernetes and workflows with Claude Code, Codex and Cursor. Each guide has answer reasoning, a common trap, a worked exercise, a follow-up and primary references. Difficulty is editorial guidance, not a hiring guarantee or an exhaustive list of possible questions.

Twelve algorithm laboratories cover lower-bound binary search, two sum, sliding windows, BFS, Dijkstra, top-K, merging, minimum-coin dynamic programming, topological sorting, union-find, LRU eviction and merging closed intervals. Choose among **36 scenarios** and step through computed states, including empty, duplicate, cyclic and unreachable inputs. These deterministic teaching traces include highlighted state, Go implementations and complexity. They do not execute arbitrary web input. `python3 scripts/verify_interview_algorithms.py` compiles all twelve examples, checks the original 500 randomized rounds and new 200-round property cases with Go's race detector.

Interview self-assessment is stored locally, independently from lesson completion and compiler verification. Eight **Go with coding agents** guides cover Claude Code, Codex and Cursor, repository context, generated API and dependency verification, permissions and prompt injection, concurrent-code review and independent engineering judgment. The app does not connect to AI providers; these guides teach workflows in your own development environment, with official documentation links. Tool interfaces and behavior may change; follow the version actually installed.

### Course and Interview screenshots

Current native screens, captured from the app rather than reconstructed mockups:

<img src="docs/screenshots/release49/course.png" width="300" alt="GopherForge 1.3.1 course with 220 teaching lessons in 28 units">
<img src="docs/screenshots/release49/interview.png" width="300" alt="GopherForge 1.3.1 Interview with 132 guides, Continue and topic path">

### Next.js website

The [website source](website/README.md) mirrors the public course, interview
preparation and algorithm demonstrations. Course and Interview use consistent
learning trees and readable highlighted code. **Continue**, filters, completion
marks and interview self-assessment are saved in browser-local storage and
survive a return visit when that storage is retained. App and browser progress
are independent; there is no account-based synchronization.

The site also offers an architecture comparison, a practical blog and
[ten original News articles](https://gopherforge.app/news), with source links,
illustrations and infographics. A separate [community feed](https://gopherforge.app/news/feed)
imports licensed Go news twice daily. Event dates are distinguished from
publication dates. Course, interview and original News pages have individual
metadata, structured data and entries in the [sitemap](https://gopherforge.app/sitemap.xml).

Lessons and interview preparation need no registration. The site does not
execute or upload arbitrary code. Analytics come only from query-free access
logs. [Building and deploying the site](website/README.md).

[Browse the course](https://gopherforge.app/learn) ·
[Prepare for interviews](https://gopherforge.app/interview) ·
[App screenshots](docs/app-store/screenshots)

## Packages and offline work

The compiler ships in the app; it is not downloaded at launch. Once project
sources and dependencies are present, builds run locally.

GitHub imports and package downloads need a connection. Pure-Go module archives
are checked against the Go checksum service before vendoring. In the current
source (1.1.1 onward), building prepares missing modules required by imports
using the versions already declared in `go.mod`. This is not a complete
replacement for Go's module solver. The earlier 1.1 release requires adding transitive
dependencies separately.

**A module must fit the archive limits:** at most **4,000 files**, **96 MiB
compressed**, and **512 MiB uncompressed**. File count includes every
non-directory entry in the downloaded ZIP, before tests, other-platform files
and unused source are filtered out; it is not a count of files the project
ultimately keeps. Automatic dependency preparation is limited to 80 modules
per pass.

For example, `modernc.org/libc@v1.75.3` contains **4,168 archive files** and is
refused before compilation. Retry cannot bypass this limit for the same
archive. A compatible smaller version or dependency may help when the
project's requirements allow it; passing the archive limits still does not
guarantee WASI compatibility. These are GopherForge resource budgets, not Go
language limits. [How the limits work](docs/PACKAGES.md#archive-budgets).

Settings → **Clear downloaded packages** removes dependency source across saved
user projects while keeping their code and dependency versions. Lessons and
built-in Examples are excluded. Packages download again when needed. This
control is available from version 1.1.1.

See [package behavior and limits](docs/PACKAGES.md).

## Limits

- Go programs run in a bounded WASI sandbox. cgo, native assembly and guest
  network sockets are unsupported.
- Module archives are capped at 4,000 files, 96 MiB downloaded and 512 MiB
  uncompressed, counted before platform/source filtering.
- The project console runs app operations; it is not a shell or SSH session.
- Local web previews are not public hosting. Imported HTML or JavaScript can
  make requests to remote services.
- Vendoring does not preserve arbitrary non-Go `go:embed` assets. `go.work`
  semantics and full module-version solving are not implemented.
- A tight infinite loop has no guaranteed Stop; close and reopen the app.
  There is no enforced aggregate guest file-write quota. Memory and captured
  output limits do not bound CPU time or writes to allowed guest files.
  [Execution contract](docs/RUNTIME_LIMITS.md).
- Compile-and-run has been demonstrated on a physical iPhone. Airplane-mode
  operation and sustained thermal/memory behavior remain unverified; simulator
  checks do not establish those results.

## Build and contribute

The app supports iOS/iPadOS 18 and later. Building requires Xcode 27.1
with the Duo SDK, XcodeGen and `zstd`.

```bash
./scripts/bootstrap.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  SWIFT_SUPPRESS_WARNINGS=NO build
```

[Build, device installation and tests](docs/BUILDING.md) ·
[Toolchain design](docs/TOOLCHAIN.md) ·
[Report an issue](https://github.com/sergii-ziborov/GopherForge/issues)

The [public lesson catalog](docs/website/lessons.json) supplies the read-only
website course without exposing hidden tests or verified exercise solutions.

## Privacy and license

No account, ads or tracking in the native app. Optional network requests and
user-selected file providers are described in [PRIVACY.md](PRIVACY.md).
Website hosting has its own operational logging; see the
[website privacy page](https://gopherforge.app/privacy).

GopherForge is proprietary software with publicly readable source, not an
open-source project. Copyright © 2026 Serhii Ziborov. All rights reserved.
[License](LICENSE) · [Third-party notices](GopherForge/Resources/ThirdPartyNotices.md) ·
[Support](SUPPORT.md) · [Terms](https://gopherforge.app/terms)

GopherForge is independent and is not affiliated with or endorsed by Google or
the Go project.

### October journal expansion

The [journal](https://gopherforge.app/news) now contains fifteen original long-form
articles. Five additions cover the 2026 developer survey, gopls 0.24, slice
backing storage, borrowed buffers/pooling and typed nil errors. Each new article has more than
2,000 words of prose, three original generated illustrations, highlighted
runnable examples where relevant, primary references and links into the course.
Edition dates fill unused archive days; actual publication dates remain separate.
News and evergreen technical guides use distinct structured-data types.

The two new course readings are
[borrowed bytes](https://gopherforge.app/learn/stdlib.borrowed-buffers) and
[pool ownership](https://gopherforge.app/learn/runtime.pool-ownership).
The native catalog is the source for both platforms; browser and app progress
remain independent.

## Source safety

The current development branch adds coordinated library writes, preserved conflict copies, scoped dependency publication, reviewed file-specific idiom repairs, strict terminal commands and a [visible import inventory](docs/IMPORT_SNAPSHOTS.md). Source implementation is not the same as a shipped build.

## Playground collaboration, nicknames and MCP

App Store **1.3.2 (51)** provides compatible guest rooms and progress links.
The **1.3.3 (56) build** includes encrypted Yjs rooms that
interoperate with the browser, nickname prompts, always-visible cursor labels,
participant-attributed recent changes, file recovery and local Debug/Check/Format/
Prepare packages. Dependency source is cached separately on the device, outside
the shared editable file set. Run/Test/Debug always require a local button.

Browser rooms use the same bounded encrypted relay and source fingerprint for
results. The key stays in the link fragment; source, Output and awareness are
AES-256-GCM encrypted before relay delivery. The native Yjs model is a checked-in,
licensed bundle generated by `website/scripts/build-native-collaboration.mjs` and
runs in JavaScriptCore; encryption uses CryptoKit. Source is never JavaScript.
Original UTF-8 source, stable file identities, concurrent edits and deleted-file
recovery have interoperability fixtures and native/browser tests. A nickname is
a self-chosen label, not authenticated authorship.

Remote Claude/Codex MCP clients and older native apps use **Compatible** rooms.
These carry plaintext source/output and exact-revision edits. The five MCP tools
are `playground_join` (named agent seat), `playground_read`, `playground_write`,
`playground_request_run` and `learning_progress_read`. A bearer token still limits
the room and maximum role when an agent uses a named participant capability.
No incoming edit, cursor, request, link or reconnect executes code. The relay has
no shell or compiler. [Complete connection/sharing guide](https://gopherforge.app/guide/mcp).

For encrypted agent sessions, install GopherForge's own JavaScript stdio server
from [npm](https://www.npmjs.com/package/gopherforge-mcp):
`npm install --global gopherforge-mcp@0.1.0`, then `gopherforge-mcp setup`.
It asks for a nickname and a complete encrypted Edit/View link, keeps the key
local and provides six room tools, including a named cursor. Run/Test requests
wait for a person to press the local button. The MCP host/provider can read
decrypted tool results. The guide explains all clients, roles and limits.

Rooms normally last one hour and can end earlier on a relay restart. Keep an
independent project/ZIP and review actual results for the captured source. Native
debugger Stop acts at checkpoints; ordinary tight loops have no guaranteed Stop.
Published progress snapshots are separately whitelisted, read-only and revocable;
learning storage formats and previous lesson IDs remain intact.

<img src="docs/screenshots/mcp51/playground-local-run.png" width="300" alt="Native GopherForge Playground running Go locally with syntax highlighting and local Output">
