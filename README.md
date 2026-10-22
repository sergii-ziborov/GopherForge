# GopherForge

A native Go workspace for iPhone and iPad. Write, compile, run, test and learn
with a bundled Go 1.27.1 toolchain.

[App Store](https://apps.apple.com/app/id6809702319) ·
[Website](https://gopherforge.app) ·
[Course](https://gopherforge.app/learn) ·
[Interview preparation](https://gopherforge.app/interview) ·
[News](https://gopherforge.app/news) ·
[Support](https://gopherforge.app/support)

<img src="docs/app-store/screenshots/iphone-6.9/00-code.png" width="330" alt="Go worker-pool source in the GopherForge editor on iPhone">

## Releases

| Version | Status, checked 23 October 2026 | Changes |
| --- | --- | --- |
| **1.1.6 (44)** | Waiting for App Review; Internal QA TestFlight | Two ownership readings: borrowed bytes, Scanner tokens and sync.Pool. 171 teaching lessons and 124 readings. |
| **1.1.5 (43)** | Available on the App Store | Continue for Course and Interview, matching learning layouts, saved progress, and compact Projects/Learn/Settings roots. Fresh learning screenshots for six device sizes. |
| **1.1.5 (42)** | Superseded by build 43 | Removed duplicate root headings while retaining titles and Back navigation inside details. |
| **1.1.4 (39)** | Previous App Store release | MongoDB/Redis and production tooling, 88 interview guides, eight interactive algorithm labs, transparent scroll endings. |
| **1.1.3 (37)** | Previous App Store release | Architecture comparisons, clean Go, all 23 classic patterns and six concurrent Go patterns. |
| **1.1.2 (36)** | Previous App Store release | Practical command-line, container and Kubernetes lessons. |

The store currently distributes **1.1.5 (43)**, verified on 23 October 2026.
**1.1.6 (44)** is in Internal QA TestFlight and waiting for App Review, with
automatic release after approval enabled. The update adds two worked readings about borrowed buffer
lifetimes and sync.Pool ownership. They are also available on the website.
Existing lesson IDs, completion, bookmarks and Continue storage remain unchanged.
TestFlight access is private; there is no public invitation link.
Release status is a dated snapshot, not a live indicator.

[Submission receipt](docs/releases/1.1.6-submission.json) ·
[Asset verification](docs/releases/1.1.6-assets-verified.json) ·
[QA results](docs/releases/1.1.6-qa.json) ·
[Version history](https://gopherforge.app/updates) ·
[Release records](docs/releases).

The app is a one-time purchase: US $6.99, US $4.99 in Ukraine, with localized
App Store prices elsewhere. No subscription or in-app purchase.

## What you can do

- **Build real Go.** Compile, run, test, vet and format on device. Compiler
  diagnostics point to source locations; test results are shown per case.
- **Keep your projects.** Editable multi-package sources, a searchable file
  tree, folders, tags, favorites and autosave. Import GitHub snapshots or Files
  folders; export and share your work.
- **Use the screen you have.** A compact iPhone editor, an iPad file tree and
  resizable dock, and adaptive Duo layouts. In laptop posture, code or Terminal
  stays above the hinge while keyboard or results occupy the lower display.
- **Learn Go.** 171 teaching lessons in 21 units, including 124 readings,
  plus 22 prediction challenges. Worked Go programs, diagrams, matching
  reviews and three-choice mistake practice accompany the material.
- **Continue studying.** Reopen the last course lesson or interview guide.
  The selected learning area, lesson completion, compiler-verified evidence
  and personal interview marks persist locally. Opening a page saves your
  place; it does not mark the material complete.
- **Explore concurrency.** Nine runnable Concurrency Lab scenarios show the
  events their goroutines and channels report as timelines.
- **Prepare for interviews.** A separate area with 88 worked guides, 12 topics,
  four difficulty levels and eight interactive algorithm labs with 24 input
  scenarios. Course progress and interview self-assessment stay independent.
- **Read idiomatic code.** A deterministic, rule-based Idiom Coach, 14 original unit
  interview questions and 12 spot-the-bug exercises.
- **Try working examples.** Multi-package programs, Go-generated PNGs, and
  HTML/CSS/JavaScript projects previewed locally in WebKit.

### Architecture and patterns

The course includes **19 architecture lessons**, **eight clean-code lessons**,
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

### Interview preparation and coding agents

Learn has a separate **Interview** area, mirrored at [gopherforge.app/interview](https://gopherforge.app/interview), free on the web without registration. It contains **88 worked guides across 12 topics**, from Junior to Staff / expert: Go values and interfaces, memory/runtime, concurrency, algorithms, architecture, HTTP/SQL, testing/performance, modules/tooling, MongoDB, Redis, Docker/Kubernetes and workflows with Claude Code, Codex and Cursor. Each guide has answer reasoning, a common trap, a worked exercise, a follow-up and primary references. Difficulty is editorial guidance, not a hiring guarantee or an exhaustive list of possible questions.

Eight algorithm laboratories cover lower-bound binary search, two sum, sliding windows, BFS, Dijkstra, top-K, merging and minimum-coin dynamic programming. Choose among **24 scenarios** and step through **111 computed states**, including duplicate, empty, unreachable and greedy-counterexample cases. These are deterministic teaching traces, with highlighted state and published Go implementations. They do not execute arbitrary web input or send code to a server. `python3 scripts/verify_interview_algorithms.py` compiles the eight published examples and checks boundary cases and 500 randomized reference comparisons with Go's race detector.

Interview self-assessment is stored locally, independently from lesson completion and compiler verification. Eight **Go with coding agents** guides cover Claude Code, Codex and Cursor, repository context, generated API and dependency verification, permissions and prompt injection, concurrent-code review and independent engineering judgment. The app does not connect to AI providers; these guides teach workflows in your own development environment, with official documentation links. Tool interfaces and behavior may change; follow the version actually installed.

### Course and Interview screenshots

Current native screens, captured from the app rather than reconstructed mockups:

<img src="docs/screenshots/buffer44-course-continue.png" width="300" alt="Course with 171 teaching lessons and Continue pointing to the borrowed-buffer reading">
<img src="docs/screenshots/root43-interview.png" width="300" alt="Interview preparation with matching progress card, Continue and topic path">

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
execute or upload arbitrary code. It is hosted on Hetzner through Hostwatch,
with query-free access-log analytics; domain registration and DNS remain in
Lovable. [Deployment and recovery](website/README.md).

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
