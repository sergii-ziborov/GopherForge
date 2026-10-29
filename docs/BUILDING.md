# Building GopherForge

## Requirements

- Xcode 27.1 with the Duo SDK; WasmKit requires Swift 6.3 or later.
- XcodeGen and `zstd`.
- An Apple development team for physical-device builds.

Use the Xcode installation explicitly so a different system selection does
not silently change the compiler or SDK.

## Prepare and build

```bash
./scripts/bootstrap.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  SWIFT_SUPPRESS_WARNINGS=NO build
```

Bootstrap stages the pinned toolchain and generates the Xcode project from
`project.yml`. Toolchain artifacts are SHA-256 verified. The Wasm tools and
standard-library archive are bundled with the app; the running app does not
download compiler components. See [TOOLCHAIN.md](TOOLCHAIN.md).

To build a toolchain from an installed Go release:

```bash
scripts/build_toolchain.sh
```

Use Release for realistic compiler performance. Debug builds of the Wasm
interpreter are much slower and are intended for debugging the app itself.

## Physical devices

Connect and unlock the iPhone or iPad, trust the Mac, then run:

```bash
./scripts/install_device.sh
```

The script builds Release, installs and launches. It accepts a device identifier
from `xcrun devicectl list devices` when several devices are connected. The
signing team is configured in `project.yml`; a different developer must use
their own team and provisioning access.

## Tests

Choose an available simulator with `xcrun simctl list devices available` and
replace `<simulator-UUID>` below with its identifier.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForge -configuration Gate \
  -destination 'platform=iOS Simulator,id=<simulator-UUID>' \
  SWIFT_SUPPRESS_WARNINGS=NO test
```

The ordinary scheme covers model and UI behavior. Run UI tests sequentially
when checking keyboard focus. Native Duo posture checks require setting the
owned simulator's actual orientation and fold in Device Hub. A forced layout
fixture does not verify physical hinge placement; an assertion about fixed
hinge tabs is not applicable to a fully flat inner display.

Compiler gates run the bundled toolchain against real programs:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj \
  -scheme GopherForgeCompilerGate -configuration Gate \
  -destination 'platform=iOS Simulator,id=<simulator-UUID>' \
  SWIFT_SUPPRESS_WARNINGS=NO test
```

Gate enables optimization and testability. Compiler checks require a staged
toolchain and clear their caches so a cached artifact cannot stand in for a
new build. Keep `SWIFT_SUPPRESS_WARNINGS=NO`: dependency warning suppression
can conflict with WasmKit's warnings-as-errors setting during builds.

### Gin examples through the project console

`BundledContentGateTests/testGinSitesRunThroughTerminal` opens all three site
templates in a real workspace, submits `go run` through `ProjectTerminalSession`
and checks each route transcript against the template's expected output. Run it
with the `GopherForgeCompilerGate` scheme and
`-only-testing:GopherForgeTests/BundledContentGateTests/testGinSitesRunThroughTerminal`.

`LocalSiteServerTests` separately checks local pages, JSON, asset loading and
JavaScript interactions in WebKit. These examples use the documented educational
Gin-compatible subset; their Go routes run through `httptest`, while the native
host serves the web files. This does not verify an arbitrary upstream Gin server.

Full Node.js/npm runtimes are not bundled. Unsupported runtime commands
fail clearly without running Go or changing the project. The next-build offline
frontend experiment accepts a documented command subset; a host Mac's installed
JavaScript tools do not become available in the iOS console.

### Offline React frontend (next build)

`scripts/prepare_frontend.py` runs during bootstrap and app builds. Go 1.24+ and
curl are needed on the build host. It compiles the committed esbuild Go driver
to WASI, verifies pinned package archives with SHA-512, retains their licenses,
and stages `Frontend/` resources with SHA-256 checksums. This preparation may
use the network on a clean build host; **the installed app never downloads a
compiler or frontend package**. Do not replace it with runtime registry access.

Focused simulator checks, using an owned simulator UUID:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1-RC.app/Contents/Developer \
  xcodebuild -project GopherForge.xcodeproj -scheme GopherForge \
  -configuration Gate -destination 'platform=iOS Simulator,id=<simulator-UUID>' \
  -parallel-testing-enabled NO -only-testing:GopherForgeTests/OfflineFrontendTests \
  -only-testing:GopherForgeTests/ProjectTerminalSessionTests \
  -only-testing:GopherForgeTests/LocalSiteServerTests \
  SWIFT_SUPPRESS_WARNINGS=NO test
```

These tests execute the bundled WASI compiler, render React in the production
WebKit scheme handler, exercise a form, reducer, filter, CSS and local JSON,
and verify that preview requests cannot reach a known working loopback HTTP
listener. Terminal checks cover offline/frozen installs, actual builds,
autosave, stale-preview invalidation and failure without file replacement.
An unsupported `node:fs` import must fail instead of gaining filesystem access.

`BundledContentGateTests/testOfflineReactTemplateGoRoutesRunWithoutNetworking`
runs install → frontend build → Go Run through the real project console using
the compiler-gate scheme. It checks exact Gin-compatible route output, retained
React preview freshness and the absence of a TCP listener. The native UI flow
`WorkspaceFlowUITests/testOfflineReactExampleBuildsFromTerminalAndOpensFullScreen`
opens the actual example, types the commands and captures embedded/full-screen
WebKit views.

Simulator checks do not establish physical-device offline, thermal or memory
behavior. Check those separately on hardware.

## Archives

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  scripts/release_archive.sh --testflight build/release
```

The script creates an archive and exports a signed IPA; it does not upload or
submit it for review. The `--testflight` option permits the prerelease host/SDK
workflow when applicable. Export needs an Apple Distribution certificate and
provisioning access. Saved manual export options can be selected through
`GOPHERFORGE_EXPORT_OPTIONS_PLIST`.

[Release records](releases) retain the exact build, validation and submission
status. Screenshots start with real code; see the capture scripts under
`scripts/` and [the listing audit](app-store/listing.md).
