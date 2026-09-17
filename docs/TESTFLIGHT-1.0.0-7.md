# TestFlight: GopherForge 1.0.0 (7)

Build 7 is the package-navigator work plus the App Review packaging for
packages and binaries. Dependencies show as packages (add / remove / search),
not as a `vendor/` file dump. Source the app imports or vendors as the user's
own code is capped at **500 lines**. Every SwiftPM pin, including WasmKit's
graph, is named in Settings → Acknowledgements.

## Build and delivery

1. Source must be the pushed `main` commit containing this guide. App and
   Share Extension are `MARKETING_VERSION = 1.0.0` and
   `CURRENT_PROJECT_VERSION = 7`.
2. Run the **Default** Xcode Cloud workflow on `main` (released Xcode 26.6 /
   macOS 26.6.2, Archive - iOS, App Store Connect, Internal QA).
3. Confirm the Cloud archive names **GopherForge 1.0.0 (7)** and the exact
   `main` commit. Set What to Test from
   [`what-to-test.txt`](../release-evidence/1.0.0/7/what-to-test.txt).

## Reviewer notes worth repeating

The Go toolchain is bundled WebAssembly. Downloaded modules are source, verified
against `sum.golang.org`, vendored, and listed as packages. Programs run in
WasmKit with no network API. Third-party notices cover Go, WasmKit,
swift-system, ZIPFoundation, swift-nio, swift-collections, swift-atomics,
swift-log, swift-argument-parser and go-cmp.
