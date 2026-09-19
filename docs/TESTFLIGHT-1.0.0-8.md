# TestFlight: GopherForge 1.0.0 (8)

Build 8 is the App Review packaging pass after build 7: one fewer third-party
library in the binary, listing screenshots that match the chrome a reviewer
taps, and notes that no longer describe a dropped package or a 500-line
ceiling on vendored modules.

## What changed for review

- **ZIPFoundation is gone.** Module zips and `goroot.zip` are read by
  `ZipArchive` in this repository. Apple's binary scan still sees four
  unmodified Go `.wasm` tools and a zipped standard library. WasmKit and its
  SwiftPM graph remain Swift source compiled into the app.
- **Toolbar.** The bar is Run, Beautify and Tests. Compile-check, packages,
  rename and `.tar.gz` export live under **⋯**. Packages are not on All
  Projects or Settings.
- **500 lines** applies to a GitHub or Files import of the user's own
  project. Installed packages are vendored as published.
- **Third-Party Library** (Settings) groups BSD / MIT / Apache / unknown.
  ZIPFoundation must not appear there.

## Build and delivery

1. Source must be the pushed `main` commit containing this guide. App and
   Share Extension are `MARKETING_VERSION = 1.0.0` and
   `CURRENT_PROJECT_VERSION = 8`.
2. Run the **Default** Xcode Cloud workflow on `main` (released Xcode 26.6 /
   macOS 26.6.2, Archive - iOS, App Store Connect, Internal QA).
3. Confirm the Cloud archive names **GopherForge 1.0.0 (8)** and the exact
   `main` commit. Set What to Test from
   [`what-to-test.txt`](../release-evidence/1.0.0/8/what-to-test.txt).

## Reviewer notes worth repeating

The Go toolchain is bundled WebAssembly. Downloaded modules are source,
verified against `sum.golang.org`, vendored, and listed as packages. Programs
run in WasmKit with no network API. Zip is this app's own reader. Notices
cover Go, WasmKit, swift-system, swift-nio, swift-collections, swift-atomics,
swift-log, swift-argument-parser and go-cmp.
