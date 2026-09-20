# GopherForge — native Go workspace for iPhone and iPad

GopherForge is a **native SwiftUI application** for learning,
editing, checking, testing and running Go locally on iPhone and iPad. The Go
compiler runs offline. Website examples use an on-device localhost server and
WebKit for HTML, CSS and JavaScript previews.

It is the Go sibling of [Crabrix](https://github.com/sergii-ziborov/crabrix),
not a rebadge of it: the compiler contract, the diagnostics, the course and the
two flagship features are Go's, and the shared parts are infrastructure rather
than screens.

> Forge real Go, anywhere.

[**Product website**](https://gopherforge.app) ·
[Support](https://gopherforge.app/support) ·
[Privacy](https://gopherforge.app/privacy) ·
[Lovable editor](https://lovable.dev/projects/c56d903d-f45d-4e68-818f-1c334f7e4420)
Custom domain: **[gopherforge.app](https://gopherforge.app)**. Connected in Lovable
on 8 September 2026; DNS now points to the hosting server and HTTPS serves the
site.

**Launch pricing:** $6.99 in the US, $4.99 in Ukraine, and Apple-localized
prices elsewhere. One-time purchase, no subscription. App features,
limitations, privacy and support are shared with this repository; the website
should reflect the app's actual App Store availability.

## What it looks like

Every compiler result below is a real run of the bundled toolchain in the
Simulator — the test counts, the diagnostics, the program output and the
goroutine trace are what the app actually produced, not mock-ups.

| | |
| --- | --- |
| <img src="docs/screenshots/learn-path.png" alt="The Learn screen: a progress card over nine units, cards for Review, Practice and Achievements, and the units themselves on a rail, each with its own icon and a lessons-done badge"> | <img src="docs/screenshots/unit-path.png" alt="The Concurrency unit opened: a note for people who already program, and its lessons on a winding trail, each with its own icon and marked COMPILE"> |
| **The course is a journey.** Nine units on a rail, then the lessons inside one on a winding path. A node says whether it was ticked by hand or sealed by a compiler pass — and nothing is locked, because a course for people who already program is one they enter at goroutines. | **Inside a unit.** Every lesson is marked `READ` or `COMPILE` before it is opened, so it is clear which ones the toolchain will judge. |
| <img src="docs/screenshots/run-output.png" alt="The iPad workspace: a worker-pool program in the editor and an Output pane reporting it compiled and executed locally, printing 1 4 9 16 25"> | <img src="docs/screenshots/problems.png" alt="The Problems pane, badged 1, reading declared and not used: unusedTotal at main.go:10:5, with line 10 highlighted red in the editor and marked in the gutter"> |
| **Go, compiled and run on the device.** The file tree, the editor and the dock at once on iPad. Three goroutines, a jobs channel and a `WaitGroup` — built and executed inside the bounded WasmKit sandbox, with no network. | **Real diagnostics.** Go's own error text, parsed for line and column, with the line marked in the editor and in the gutter. |
| <img src="docs/screenshots/workspace-tests.png" alt="The Tests pane reading 4 passed, 0 failed with per-case rows for TestReverse and its subtests"> | <img src="docs/screenshots/lab.png" alt="The Concurrency Lab: nine runnable scenarios on a shelf, grouped into channels, coordination and ways it goes wrong"> |
| **`go test`, per case.** Run by the bundled toolchain and parsed from the same stream a developer reads, kept apart from diagnostics. | **Review is matching now.** Five terms on the left, five meanings on the right, up to five boards from lessons already finished. Achievements stay on Learn. |
| <img src="docs/screenshots/my-projects.png" alt="My projects: a search field for name, folder, tag or file, and three projects under Unfiled — Playground, Package with tests with a Build failed chip, and Worker pool with a Run ok chip"> | <img src="docs/screenshots/navigator-iphone-code.png" width="300" alt="The iPhone Build workspace with the file drawer closed: the code editor spans the available width, with no file column behind it"> |
| **Your projects, filed.** Search by name, folder, tag or file name — a project is often remembered as "the one with `parser.go`". Folders, tags, a star and a note, and nothing is ever evicted. | **iPhone editor.** Code uses the available width; Files opens one drawer only when tapped. |
| <img src="docs/screenshots/navigator-iphone-files.png" width="300" alt="The iPhone Files drawer opened once over the code editor, showing one searchable file tree"> | <img src="docs/screenshots/navigator-ipad-persistent.png" alt="The iPad Build workspace with one persistent, searchable file tree beside the editor"> |
| **iPhone files.** The file tree overlays the editor, and choosing a file closes it. | **iPad files.** One file tree stays beside the editor, including in a narrow iPad window. |

The navigator images come from the UI regression in
`NavigatorFlowUITests`, captured with `scripts/navigator_screenshots.sh`.

## What is built, and what is not

The hard product gate for this repository is:

> Can a bundled Go toolchain type-check, test and run Go locally inside an
> iPhone/iPad app while offline?

**In the Simulator, yes.** Hosting the Go compiler itself in WebAssembly was
this project's Gate A, and it closed on 2026-08-27 — with no patched Go at all.
`cmd/compile`, `cmd/link`, `cmd/vet` and `cmd/gofmt` cross-compile to
`wasip1/wasm` from a stock release and run under WasmKit; what cannot work is
`cmd/go`, which builds by spawning those tools as child processes, and WASI has
no way to spawn anything. So the app does the ordering itself and calls the
tools directly. A new Go release is a fifteen-second rebuild, not a rebase —
see [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md).

What is still unproven is everything only real hardware can answer: the offline
claim, the thermal and memory envelope, and stopping a runaway program. A
Simulator run must never be presented as if it had settled those.

Concretely, the app currently contains:

- a native `Projects / Build / Learn / Settings` shell in a tab bar on both
  devices, with the workspace inside it adapting: file tree beside the editor
  and a dock below it on iPad, a Files drawer over the full-width code on iPhone;
- what you type is kept without being asked to keep it. Every edit reaches the
  project immediately and the library shortly after, and leaving the foreground
  writes rather than waiting. There was a version where an edit lived only in
  the editor's own buffer until something wanted to build, and switching tab or
  vendoring a package could overwrite it from a stale project; that is what
  `WorkspaceAutosaveTests` exists to keep closed;
- a project library that keeps everything you make: folders, tags, a star and a
  note per project, grouped and searched by name, folder, tag or file name —
  because the project you are looking for is often "the one with `parser.go`
  in it" rather than whatever you called it six weeks ago. Nothing is evicted;
  the dashboard keeps a five-project strip and links to the rest;
- a workspace that changes shape by device: iPad shows the file tree, the editor
  and a dock at once, while iPhone becomes full-height
  `Code / Problems / Output / Tests / Idioms / Terminal` tabs with the switcher
  at the top, where the keyboard cannot bury it;
- a project console that maps `go build`, `go run`, `go test`, `go vet`,
  `go fmt`, `go mod`, `ls`, `cat`, `pwd` and `clear` to the app's own
  operations — app-scoped, never a shell;
- a course of 47 lessons across nine units. Another
  22 question-and-answer challenges are gathered into Practice rather than
  counted as course steps. The extra steps come from A Tour of Go
  and Effective Go — named results, make versus new, arrays, Stringer, any,
  function values, buffered channels, range-and-close, select default,
  directional channels, sync.Once, recover, http.Handler, strconv, image.Image —
  written for people who already program. Compile lessons finish when Check
  passes; Next skips without a tick; a hint can Realize the verified answer.
  Every code lesson ships a complete answer that a
  gate compiles against that lesson's own hidden test — so a lesson nobody can
  solve fails the build rather than a learner;
- two of those units close gaps the course had no business having. **Types you
  define** teaches struct literals, methods and receivers, pointers, closures
  and escape analysis — the course previously taught `:=` and `switch` and never
  once showed how to declare a type of your own. **Generics** teaches type
  parameters, constraints with `~`, generic containers, and the cases where a
  plain interface is the better answer; Go has had them since 1.18, and a course
  without them teaches the language as it was in 2021;
- the course drawn as a journey rather than a list: the units on a rail on the
  Learn screen, and inside a unit its own lessons on a winding path. Each node
  says whether it was ticked by hand or sealed by a compiler pass. Nothing is
  locked — a course written for people who already program is one they enter
  sideways, at goroutines, because that is what they came for.
  The two shapes are deliberate. The winding path costs work per node on every
  frame of a scroll, and measured here it carried seven units and pinned the
  main thread for thirty seconds at nine; it stays where the node count is small
  and bounded, which is inside a unit;
- a lesson that says where it sits and where it goes: the unit, which lesson of
  how many, whether the toolchain judges this one, and the next lesson by name
  at the end. Check runs the hidden test and records a passing compile lesson;
  Next moves on without a tick. Reading lessons can be marked done;
- a quiz closing each unit: one question at a time, four options, and the
  explanation the moment an answer is committed rather than at the end;
- a matching drill — terms on the left, meanings on the right, tiles of one
  fixed height so nothing moves while your thumb is reaching — whose wrong
  connections feed the same review queue a failed compile does;
- achievements earned by compiling, running, testing and fixing — eleven badges
  of four ranks each, where the bar measures the rung being climbed rather than
  the whole badge, so passing silver does not read as almost-gold;
- an example library under the five recent projects: single-idea programs,
  multi-package projects, three small sites with an offline Gin-compatible
  route subset, and graphics programs that write PNGs the app displays — the
  Mandelbrot set, a hand-written colour wheel, plotted waves, Sierpinski by
  chaos game, and Life drawn as a filmstrip — and one project with `go-cmp`
  already vendored so it builds offline against a real dependency. The Go
  sandbox checks the sites' routes with `httptest`; the app serves their HTML,
  CSS, JavaScript and JSON files on localhost for a live preview. A gate
  compiles, runs and checks the exact output of every example;
- package installation: resolve a module, see its popularity, licence and
  OpenSSF Scorecard, and vendor a checksum-verified copy into the project;
- a `UITextView` editor with Go, `go.mod`, HTML, CSS, JavaScript and JSON syntax highlighting, marked
  diagnostic lines, and an accessory row with three fixed regions: suggestions,
  a scrolling set of the symbols Go needs, and a control that puts the keyboard
  away. Long lines scroll sideways rather than wrapping, and the gutter numbers
  lines of the file — which is what a diagnostic points at, so a wrapped row
  counted as a line would mark code the compiler never mentioned;
- a compiler layer that stages a project into a job sandbox, runs one WASI
  module per phase, and parses what it wrote — format, vet, build, run, test;
- Go's plain-text diagnostics parsed for real, including package banners,
  column-less locations and the indented notes that belong to the finding above
  them;
- `go test` output parsed from the same stream a developer reads, kept apart
  from diagnostics;
- a build cache keyed on the toolchain tag, the phase and every file, so an
  unchanged program re-runs its stored artifact instead of rebuilding;
- **Idiom Coach**: a deterministic rule catalogue that flags Java-style getters,
  a context that is not the first parameter, discarded errors, upper-case error
  strings and a close in the receiving goroutine — each explaining itself, and
  repairing only the exact line it pointed at;
- **Review**: five-by-five matching boards, up to five in a session, dealt only
  from lessons already finished, so the board never asks for something the
  course has not taught yet;
- **Concurrency Lab**: nine runnable scenarios grouped by channels,
  coordination and ways it goes wrong. Their programs print structured events
  that the app draws as goroutine lanes, including blocked work;
- interview preparation: fourteen questions a Go interview asks, each with what
  a strong answer covers and the plausible answer that is wrong. No multiple
  choice — an interview is answered out loud, and four options train
  recognition instead;
- **Spot the bug**: twelve short programs with one fault each, found by tapping
  the line. Every fault is unambiguous under the bundled Go, the guess cannot be
  taken back, and a miss feeds the same review queue a failed compile does;
- a nine-unit course written for people who already program, where a lesson
  passes when `go test` passes rather than when text matches;
- review chosen from the mistakes the compiler and the coach actually saw, with
  the reason shown on every item;
- four project templates that build offline with no dependencies at all;
- GitHub import: paste a repository URL, or send one in from another app
  through the Share Extension, and the snapshot is downloaded, filtered to text
  the editor can open, and turned into a project. A Share Extension queues URLs
  through an App Group and never tries to foreground the host app; a
  launch-time drain surfaces what it queued as something tappable;
- Files import of a folder, a `.tar.gz` this app exported, or a
  `.gopherforgeproject` package, opening the module root rather than the
  checkout root, bounded in file count and size;
- a navigator whose search groups hits by file rather than listing a file once
  per match, and marks what it matched in the code as well as in the sidebar;
- panes that follow the work: a finished run opens Output, a failure opens
  Problems, and a test run opens Tests, so pressing Run never leaves you
  staring at the source it just left behind.

Anything that needs the toolchain says so rather than offering a button that
can only fail: Build, Run, Test, the lab and every compile lesson are disabled
with the toolchain's own reason shown while none is staged.

The toolchain is staged **at build time** — built from the Go on the machine,
or unpacked from a pinned archive verified by SHA-256. The Wasm tools are
copied into the app bundle; standard-library data is bundled as `goroot.zip`
and extracted locally into Caches before compilation, with a SHA-256 check. The running app never downloads compiler components.

## Boundaries, stated up front

- **cgo is not supported.** It needs a native C toolchain.
- **A package is installed once, then it is source.** The Packages screen
  resolves a module through `proxy.golang.org`, checks the download against
  `sum.golang.org` before writing anything, and vendors the result into the
  project. The compiler still runs with `GOPROXY=off`: it never sees a network,
  and every build after an install is offline. What is not done is verifying
  the checksum database's signed transparency-log proof — the trust there is
  TLS to the official endpoint, and that limit is stated in the app.
- **No network from a guest program.** One writable preopen, `/sandbox`, and no
  network imports.
- **`GOOS=wasip1`, not `js/wasm`.** The memo this product came from assumed a
  browser; this app has no JavaScript engine, so both the toolchain and the
  programs it builds target WASI and run in the same interpreter. There is no
  `wasm_exec.js` anywhere in the repository.
- **No `cmd/go` in the bundle, on purpose.** It builds by spawning the compiler
  and the linker, and WASI cannot spawn. The app plans the build itself, which
  is what keeps the bundled Go unpatched.
- **A program that loops forever cannot be stopped.** Everything a runaway
  guest can consume is capped except processor time: guest memory at 64 MiB,
  the function table at 32,768 entries, each output stream at 1 MiB — after
  which further bytes are counted, discarded, and reported in the output — and
  both build caches bounded in bytes as well as in entries. What
  has no ceiling is a loop that calls nothing — `for {}` or `select {}`.
  WasmKit 0.3.1 exposes no way to interrupt a running guest: its public surface
  is a resource limiter for memory and table growth and an execution
  interceptor whose methods cannot throw, and upstream has no fuel, epoch or
  deadline API. The app stays responsive and nothing is lost, but one thread
  spins until the app is closed. A genuine Stop needs an interrupt check inside
  the interpreter's instruction handlers, which means forking a
  performance-critical dependency; that is deferred deliberately rather than
  overlooked.
- **Transitive dependencies are not resolved for you.** Adding a module vendors
  that module. If it imports another one, that one has to be added too — the
  compatibility report names what is missing rather than failing partway
  through a build. `//go:embed` of non-Go assets does not survive vendoring,
  and assembly files are dropped. See [docs/PACKAGES.md](docs/PACKAGES.md).

## License and ownership

GopherForge is commercial proprietary software, not an open-source MIT project.
Copyright © 2026 Serhii Ziborov. All rights reserved. See [LICENSE](LICENSE).

Bundled third-party components keep their original licenses. Settings →
Third-Party Library groups them by family: **BSD 3-Clause** (Go toolchain wasm + go-cmp), **MIT**
(WasmKit only — zip is this app's own reader), **Apache 2.0 with Runtime Library Exception**
(swift-system and WasmKit's SwiftPM graph), and **unknown / their own terms**
for modules you vendor later. The `.wasm` tools are unmodified upstream Go,
not foreign native iOS binaries. The full list is
[GopherForge/Resources/ThirdPartyNotices.md](GopherForge/Resources/ThirdPartyNotices.md).

The Go gopher was designed by Renée French and is not used here. The app's
mascot is a gopher of our own — a different silhouette and a different face,
drawn from scratch in `scripts/make_app_icon.swift` so the icon is reproducible
from source rather than a binary nobody can regenerate. Go's published brand
colours are used as colours; no Go mark, logo, or gopher is reproduced, and
nothing here implies endorsement by the Go project.

`ThirdPartyNoticesTests` fails the build if a bundled dependency is missing
from the notices or recorded under the wrong licence, and
`scripts/build_toolchain.sh` refuses to produce a toolchain artifact unless
Go's own `LICENSE` and `PATENTS` are staged beside it — shipping the compiled
tools without them would not satisfy the BSD 3-Clause redistribution terms.

## Privacy and support

The app collects nothing. The policy is [PRIVACY.md](PRIVACY.md). Support is
[SUPPORT.md](SUPPORT.md).

## Build

Requirements:

- Xcode 26.6 or newer (Swift 6.3+ is required by WasmKit 0.3.1);
- XcodeGen;
- `zstd` on the build Mac.

Stable Xcode, not beta, and that distinction is the release pipeline rather
than a preference: Swift 6.3 ships in 26.6, which is what WasmKit needs, so
there is nothing a beta is required for. Beta Xcode is for testing the next
iOS ahead of time, and an App Store archive should not be the place that
happens. The commands below name `DEVELOPER_DIR` explicitly so that whichever
Xcode a Mac happens to have selected does not decide what gets built.

```bash
./scripts/bootstrap.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  build
```

The first build stages the toolchain. With Go installed it is built here, from
that release, in about fifteen seconds:

```bash
scripts/build_toolchain.sh
```

That output is roughly 180 MB and is deliberately not committed: it is build
artefacts cut from an unpatched Go, so it is something to reproduce rather than
to store. On a machine with no Go and no pinned artifact, `bootstrap.sh`
continues anyway and the app runs with the compiler reported as missing. That
state is visible in the Build banner and in Settings, and every compiler gate
treats it as a failure rather than a skip.

### On a device

The signing team is already in `project.yml`, and Xcode provisions both the app
and its extension automatically. Plug the iPhone or iPad in, unlock it, trust
the Mac, then:

```bash
./scripts/install_device.sh
```

It finds the connected device, builds signed, installs and launches. Pass a
device identifier from `xcrun devicectl list devices` to choose between several.

**It builds Release, and that is not a preference.** The whole product runs
inside a Wasm interpreter, and an unoptimised WasmKit is slower by orders of
magnitude — measured here, a Debug gate run in the Simulator does not finish
where a Release one takes nineteen seconds. On a phone that difference reads as
a Build button that does nothing at all. Pass `debug` only when you need a
debugger attached and know what you are trading for it.

Airplane mode, the thermal envelope, and stopping a runaway program have to be
checked on a device. Simulator numbers do not stand in for that.

## Verification

Every `xcodebuild` here passes `SWIFT_SUPPRESS_WARNINGS=NO`, and leaving it out
fails the build rather than producing a warning. Xcode 26.6 suppresses warnings
in package dependencies, WasmKit's `Package.swift` asks for warnings to be
treated as errors, and swiftc refuses both at once:

```
error: conflicting options '-warnings-as-errors' and '-suppress-warnings'
```

It cannot be set in `project.yml` — package dependencies build as their own
generated projects and do not inherit this one's settings, which was tried. On
the invocation it reaches every target. Xcode 27 beta does not add the flag, so
this appears only on the released Xcode, which is the one that builds releases.

The normal test scheme excludes the expensive compiler gates:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  SWIFT_SUPPRESS_WARNINGS=NO \
  test
```

That scheme runs both suites. The UI tests drive the real app in the Simulator:
they open a template and check it lands in the editor, type into the buffer,
switch panes, select a file in the tree, walk the course into a lesson, dismiss
the keyboard from its own row, and assert that every action needing the compiler
is offered exactly when a compiler is staged — written as that invariant rather
than as one configuration, because both states are real. They address elements
by accessibility identifier rather than by visible text, so a copy edit cannot
silently stop a test from checking anything.

Run the real bundled-toolchain gates with the dedicated scheme, which requires a
staged toolchain and its own configuration:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForgeCompilerGate \
  -configuration Gate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  SWIFT_SUPPRESS_WARNINGS=NO \
  test
```

`Gate` is a third configuration and it earns its place: these tests run a real
Go build inside the Wasm interpreter, which is unusably slow unoptimised, and
they cannot run in plain Release because `@testable import` needs a testability
a shipped binary should not carry. Each run also clears the build cache first —
a cached artifact makes a build that never happened look exactly like one that
did.

Measured on an M-series Mac in the Simulator, Go 1.27.1, cold cache. These are
the compiler gate's own per-test times, so they are re-measured every time it
runs rather than being a number somebody typed once:

| | |
| --- | --- |
| compile, link and run one program | 3.6 s |
| two-package module | 4.8 s |
| `declared and not used` reported | 0.5 s |
| table-driven `go test`, per-case results | 9.1 s |
| three repeated runs, cache warm after the first | 2.8 s total |
| one file edited, only its package recompiled | 17.6 s |
| a dependency changed, everything importing it rebuilt | 24.6 s |

Slower than the Go 1.24.2 figures these replaced — a larger compiler doing more
work inside the same interpreter. Still the same shape: the second build of an
unchanged program is cache-warm, and editing one file does not rebuild the
module.

These are Simulator numbers on a Mac and nothing more. They do not stand in
for a phone.
