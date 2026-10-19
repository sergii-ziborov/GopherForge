# GopherForge

A native Go workspace for iPhone and iPad. Write, compile, run, test and learn
with a bundled Go 1.27.1 toolchain.

[App Store](https://apps.apple.com/app/id6809702319) ·
[Website](https://gopherforge.app) ·
[Course](https://gopherforge.app/learn) ·
[Support](https://gopherforge.app/support)

<img src="docs/app-store/screenshots/iphone-6.9/00-code.png" width="330" alt="Go worker-pool source in the GopherForge editor on iPhone">

## Releases

| Version | Status, checked 20 October 2026 | Changes |
| --- | --- | --- |
| **1.1.1 (33)** | Previous App Store release | Package downloads and retry handling, package cleanup for saved user projects, learning corrections, and iPhone/iPad workspace fixes. |
| **1.1.2 (34)** | Earlier Internal QA TestFlight | Corrected Duo header and full-width iPhone landscape code with floating section controls. |
| **1.1.2 (35)** | Earlier Internal QA TestFlight | 26 reading lessons, four new units, an explicit Review finish action, minimum three-pair boards and three-round sessions, and fixed landscape controls behind the keyboard. |
| **1.1.2 (36)** | Available on the App Store | 25 practical Around Go lessons across command line, containers and Kubernetes; highlighted shell commands and manifests. |
| **1.1.3 (37)** | Private TestFlight; Waiting for Review | 53 new readings: architecture comparisons, clean Go, all 23 classic patterns and six concurrent Go patterns. |

Version 1.1.2 (36) released automatically after approval. Version 1.1.3 (37)
is available to existing Internal QA testers in TestFlight and is submitted to
App Review, with automatic release after approval. TestFlight access is private;
there is no public invitation link. [Version history](https://gopherforge.app/updates) ·
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
- **Learn Go.** The public 1.1.2 course has 92 teaching lessons, 22 question-and-answer challenges and the 69 original visual guides. The submitted 1.1.3 update contains **145 lessons across 20 units**, including 98 reading lessons. Architecture has 19 lessons and a scenario comparison, clean code has eight, and patterns cover all 23 classic designs plus six Go concurrency and resilience patterns. The 25 practical Around Go lessons remain available. New readings include diagrams, highlighted complete Go programs, explanations, tradeoffs and review questions.
- **Explore concurrency.** Nine runnable Concurrency Lab scenarios show the
  events their goroutines and channels report as timelines.
- **Read idiomatic code.** A deterministic, rule-based Idiom Coach, 14 interview
  questions and 12 spot-the-bug exercises.
- **Try working examples.** Multi-package programs, Go-generated PNGs, and
  HTML/CSS/JavaScript projects previewed locally in WebKit.

### Submitted update: architecture and patterns

Version 1.1.3 adds 53 reading lessons. Its course has 145 teaching lessons across 20
units, including 98 readings: 19 architecture lessons with scenario-based fit
ratings, eight clean-code lessons, all 23 classic design patterns and six
concurrent Go patterns. Worked programs, diagrams, tradeoffs and independent
review questions accompany the new material. The update is in private TestFlight and Waiting for Review.
[Submission and release settings](docs/releases/1.1.3-submission.json) ·
[Verified screenshots and product assets](docs/releases/1.1.3-assets-verified.json).

The 19 architecture and eight clean-code readings now include 81 further
sections on package structure, consistency, transactions, failure recovery,
API contracts, testing and incremental migration. Lesson IDs and saved progress
remain unchanged.

### Next.js website

The [new website source](website/README.md) includes the complete native-course
export, five practical blog articles, a scenario-based architecture comparison,
highlighted code, reading self-checks and optional local browser progress.
It needs no registration and does not execute or upload arbitrary code.
The site is live at **https://gopherforge.app**, on Hetzner through Hostwatch.
The course is organized into five learning trees with collapsible units,
readable highlighted code, consistent progress filters and mobile layouts.
Hostwatch receives query-free access-log analytics; domain registration and DNS
remain in Lovable. [Deployment and recovery](website/README.md).

[Browse the course](https://gopherforge.app/learn) ·
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

Requires Xcode 27.1 with the Duo SDK, XcodeGen and `zstd`.

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
