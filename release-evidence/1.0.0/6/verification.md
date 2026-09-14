# Build 6 local verification — 14 September 2026

Merged source: `main`, including `d094afd`, `f4b5db2` and `0c95326`.
Build settings: `MARKETING_VERSION=1.0.0`, `CURRENT_PROJECT_VERSION=6`
for the app and Share Extension. Local toolchain: Xcode 27.0 beta
(`27A5228h`) on macOS 27.0.

| Check | Command or evidence | Actual result |
| --- | --- | --- |
| All ordinary XCTest cases | `xcodebuild test -quiet -project GopherForge.xcodeproj -scheme GopherForge -destination 'platform=iOS Simulator,id=3FAF353F-BA0C-4F22-9443-92F60E557BF6' -parallel-testing-enabled NO -only-testing:GopherForgeTests -resultBundlePath /tmp/gopherforge-build6-unit-final.xcresult CODE_SIGNING_ALLOWED=NO` | PASS: 309 tests, 0 failures; 1 dedicated compiler test class intentionally skipped in the ordinary scheme. [Summary](unit-tests-summary.json) |
| Bundled Go compiler gate, including Build A → edit/save B → finish A | Same command with `-scheme GopherForgeCompilerGate -only-testing:GopherForgeTests/BundledCompilerGateTests` and no explicit result path | PASS: 9/9; real bundled Go compiler, not a mock. [Summary](compiler-gate-summary.json) |
| iPhone file navigator | Same test command with destination `D972F5DC-132F-4F46-9B09-BEE179EFF196`, `-only-testing:GopherForgeUITests/NavigatorFlowUITests/testNavigatorOccupiesOnePlaceForTheDevice` | PASS: 1/1, iPhone 17 Pro Max Simulator. [Summary](navigator-iphone-summary.json) |
| iPad file navigator | Same UI command with destination `0E4C4DB1-DDF4-4CCF-B71E-D78E3C00ABE8` | PASS: 1/1, iPad Pro 13-inch Simulator. [Summary](navigator-ipad-summary.json) |
| Release simulator build | `xcodebuild build -quiet -project GopherForge.xcodeproj -scheme GopherForge -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` | PASS. The built app and Share Extension both report version `1.0.0 (6)`. Executable SHA-256: `b673d51919407c15494a7d7ea3fe9ebaed28a9e544f9b8180b1d506f042f0619`. This is unsigned simulator output, not a TestFlight archive. |
| Branch integration | `git branch -r --no-merged main` after fetch and fast-forward | PASS: no other remote branch remains unmerged. |
| Physical iPhone/iPad Gate B | `xcrun devicectl list devices` | NOT RUN: physical iPhone and Watch are unavailable; no connected physical iPad. |
| Stop ≤1 second; pre-write guest-file quota | Pinned WasmKit 0.3.1 API review, [requirements](../../../docs/HARDEN-GOPHERFORGE-CORE.md) | BLOCKED; neither was represented by a UI-only Stop or post-execution trimming. |
| OpenSpec strict validation | Catalog archive absent; `openspec` CLI unavailable | NOT RUN. |
| TestFlight delivery | Existing Xcode Cloud Default workflow on App Store Connect | PENDING until a Cloud build and processed Internal QA assignment are confirmed. |

The source-level and simulator evidence verifies the project and navigator fixes
to the extent stated above. It does not establish the physical-device or runtime
requirements that remain open.
The ordinary result also recorded three priority-inversion runtime warnings in
`OutputLimitTests`; they did not fail the suite. Absolute local paths in the
tracked summary were shortened to repository-relative paths.
