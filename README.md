# GopherForge — native Go workspace for iPhone and iPad

GopherForge is an early-development **native SwiftUI application** for learning,
editing, checking, testing and running Go locally on iPhone and iPad. There is
no WebView, localhost server, JavaScript runtime, or cloud compiler in the app.

It is the Go sibling of [Crabrix](https://github.com/sergii-ziborov/crabrix),
not a rebadge of it: the compiler contract, the diagnostics, the course and the
two flagship features are Go's, and the shared parts are infrastructure rather
than screens.

> Forge real Go, anywhere.

## What is built, and what is not

The hard product gate for this repository is:

> Can a bundled Go toolchain type-check, test and run Go locally inside an
> iPhone/iPad app while offline?

**That gate is open.** Hosting the Go compiler itself in WebAssembly is this
project's Gate A, and it has no published artifact yet — see
[docs/DEVICE-GATE.md](docs/DEVICE-GATE.md). Everything downstream of the
toolchain is built and tested; the toolchain slot is empty and says so.

Concretely, the app currently contains:

- an adaptive native `Projects / Build / Learn / Settings` shell — sidebar on
  iPad, tab bar on iPhone;
- a `UITextView` editor with Go and `go.mod` syntax highlighting, marked
  diagnostic lines, and a keyboard row carrying tab, braces, `:=` and `<-`;
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
- **Concurrency Lab**: four runnable scenarios that print structured events from
  ordinary instrumentation the learner can read, a trace model that finds
  goroutines which blocked and never resumed, and diagnoses that name the
  goroutine and the channel;
- a seven-unit course written for people who already program, where a lesson
  passes when `go test` passes rather than when text matches;
- review chosen from the mistakes the compiler and the coach actually saw, with
  the reason shown on every item;
- four project templates that build offline with no dependencies at all;
- a Share Extension that queues GitHub URLs through an App Group and never
  tries to foreground the host app, plus a launch-time drain that surfaces what
  it queued;
- Files import of a folder or a `.gopherforgeproject` package, opening the
  module root rather than the checkout root, bounded in file count and size.

Anything that needs the toolchain says so rather than offering a button that
can only fail: Build, Run, Test, the lab and every compile lesson are disabled
with the toolchain's own reason shown while none is staged.

The toolchain is staged **at build time**, verified by SHA-256, and copied into
the app bundle. The running app never downloads compiler components.

## Boundaries, stated up front

- **cgo is not supported.** It needs a native C toolchain.
- **Modules are not downloaded.** `GOPROXY=off` inside the sandbox, so a project
  with requirements must vendor them.
- **No network from a guest program.** One writable preopen, `/sandbox`, and no
  network imports.
- **`GOOS=wasip1`, not `js/wasm`.** The memo this product came from assumed a
  browser; this app has no JavaScript engine, so both the toolchain and the
  programs it builds target WASI and run in the same interpreter. There is no
  `wasm_exec.js` anywhere in the repository.

## License and ownership

GopherForge is commercial proprietary software, not an open-source MIT project.
Copyright © 2026 Serhii Ziborov. All rights reserved. See [LICENSE](LICENSE).

Bundled third-party components keep their original licenses, including the Go
toolchain and standard library under the BSD 3-Clause license of the Go
project. Attributions are maintained in
[GopherForge/Resources/ThirdPartyNotices.md](GopherForge/Resources/ThirdPartyNotices.md).

The Go gopher was designed by Renée French and is not used here. The app's mark
is original artwork.

## Build

Requirements:

- Xcode 27 beta or newer (Swift 6.3+ is required by WasmKit 0.3.1);
- XcodeGen;
- `zstd` on the build Mac.

```bash
./scripts/bootstrap.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  build
```

`bootstrap.sh` continues when no toolchain artifact is pinned, so the app builds
and runs with the compiler reported as missing. That state is visible in the
Build banner and in Settings, and every compiler gate treats it as a failure
rather than a skip.

For a signed physical build, select the same Apple development team for the
`GopherForge` and `GopherForgeShare` targets, register
`group.com.sergiiziborov.GopherForge`, and regenerate both provisioning
profiles.

## Verification

The normal test scheme excludes the expensive compiler gates:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  test
```

That scheme runs both suites. The UI tests drive the real app in the Simulator:
they open a template and check it lands in the editor, type into the buffer,
switch dock tabs, select a file in the tree, walk the course into a lesson, and
assert that every action needing the toolchain is disabled while none is
staged. They address elements by accessibility identifier rather than by
visible text, so a copy edit cannot silently stop a test from checking
anything.

Run the real bundled-toolchain gates with the dedicated scheme, which requires a
staged toolchain:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForgeCompilerGate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  test
```

No performance numbers are published in this README yet, because none have been
measured on this product. Crabrix's numbers are Crabrix's.

## Success criteria

The compiler gate passes only when all of these are demonstrated on a physical
iPhone or iPad:

1. airplane mode is enabled before launch;
2. the app reports a bundled `gotool.wasm` and its Go version;
3. **Build** produces a real `declared and not used` diagnostic at the right
   line and column;
4. the repaired program compiles and **Run** prints its output;
5. **Test** runs a table-driven `_test.go` and reports per-case results;
6. a multi-package module inside one `go.mod` builds and runs;
7. repeated builds stay within an acceptable memory and thermal envelope;
8. a non-terminating program can be stopped without leaving runaway work.

Items 1, 7 and 8 cannot be claimed from a Simulator run. See
[docs/DEVICE-GATE.md](docs/DEVICE-GATE.md).
