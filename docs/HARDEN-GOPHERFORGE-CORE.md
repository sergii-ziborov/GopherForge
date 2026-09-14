# Core hardening evidence — 14 September 2026

Base: `de40934de4c5adb8cd2a59d85793a00b8333eab8`.
Integrated into `main` for build 1.0.0 (6).

This change keeps library identity in the existing `ProjectLibraryItem.id` UUID.
The optional `sourceRevision` field decodes old JSON without changing exported
project archives. Source saves, build results and filing metadata are separate
actor operations. The workspace restores the last saved item at launch and
retains an unsaved project for retry/export when switching races a disk error.

| Requirement | Test or evidence | Result |
| --- | --- | --- |
| Two same-name projects remain independent | `ProjectLibraryTests.testTwoProjectsWithTheSameNameKeepIndependentSource` | PASS in simulator |
| Rename keeps ID, files and filing; legacy JSON decodes | `testRenameAndFilingSurviveSourceSave`, `testADocumentWrittenBeforeFilingExistedStillDecodes`, `WorkspaceAutosaveTests.testRenameKeepsLiveUnsavedSourceAndProjectID` | PASS in simulator |
| Relaunch does not replace edited Playground | `WorkspaceAutosaveTests.testPrepareRestoresSavedProjectInsteadOfReplacingItWithPlayground` | PASS in simulator |
| Older source saves and build results do not roll back newer source | `ProjectLibraryTests.testOlderSourceSaveCannotRollBackANewerRevision`, `testBuildResultCannotReplaceSourceEditedAfterBuildStarted`, real-toolchain `BundledCompilerGateTests.testBuildFinishingAfterAnEditKeepsTheNewSource`; workspace format checks project ID and revision | PASS in simulator, including Build A → edit/save B → finish A |
| Switch before debounce keeps an edit | `WorkspaceAutosaveTests.testSwitchingProjectsBeforeDebounceKeepsTheFirstEdit` | PASS in simulator |
| Write failure is visible and retryable; export remains available | `WorkspaceAutosaveTests.testSaveFailureIsVisibleAndRetryKeepsTheEdit` forces a filesystem write failure | PASS for write failure; actual ENOSPC NOT RUN |
| Format ignores imports; Run ignores test-only imports; Test still validates them | `GoBuildPlannerTests.testFormatDoesNotResolveImports`, `testRunIgnoresImportsUsedOnlyByTests` | PASS in simulator |
| Multiple main targets select independently | `GoBuildPlannerTests.testRunSelectsTheRequestedMainPackage`, `testRunDoesNotCompileAnUnrelatedMainTarget`, `WorkspaceAutosaveTests.testSelectingAnotherMainFileChangesTheRunTarget`; artifact key includes package pattern | PASS in simulator |
| Idiom Coach does not block typing or apply stale findings | Analysis moved off the main actor; results require matching ID and revision | Code inspection only; responsiveness measurement NOT RUN |
| Stop ends a CPU loop and blocking guest call within one second | WasmKit 0.3.1 `EngineInterceptor` has only function enter/exit hooks; no guest-instruction interrupt. A loop inside one function never reaches a hook. | BLOCKED; no fake Stop added |
| Guest file quota rejects write/seek/truncate before exceeding limit | WasmKit 0.3.1 `WASIBridgeToHost.FileSystemOptions` publicly offers host or memory FS, but its factory is internal and neither implementation has a pre-write quota. Output capture limits stdout/stderr only. | BLOCKED; no after-the-fact truncation claimed |
| Physical iPhone/iPad Gate B | `docs/DEVICE-GATE.md` requires real devices, currently unavailable to this session | NOT RUN |
| OpenSpec strict validation | The described archive/catalog `openspec/changes/harden-gopherforge-core/` was not attached or found locally; `openspec` CLI is not installed | NOT RUN |
| TestFlight upload | Build 1.0.0 (6) release procedure in `docs/TESTFLIGHT-1.0.0-6.md`; App Store Connect Xcode Cloud | PENDING; this simulator evidence is not a delivery receipt |

The first controlled run against the base failed the three new regression
tests for duplicate names, Format with an unresolved import and Run with a
test-only unresolved import. Xcode 26.6 could not build the pinned WasmKit due
to conflicting `-warnings-as-errors`/`-suppress-warnings` flags in this local
setup. Xcode 27 beta compiled the app. A first iOS 26.5 simulator launch failed
preflight with `Busy`; the already booted iOS 18.2 simulator ran the tests.

Verification commands:

```sh
xcodebuild test -quiet -project GopherForge.xcodeproj -scheme GopherForge \
  -destination 'platform=iOS Simulator,id=3FAF353F-BA0C-4F22-9443-92F60E557BF6' \
  -parallel-testing-enabled NO -only-testing:GopherForgeTests CODE_SIGNING_ALLOWED=NO

xcodebuild test -quiet -project GopherForge.xcodeproj -scheme GopherForgeCompilerGate \
  -destination 'platform=iOS Simulator,id=3FAF353F-BA0C-4F22-9443-92F60E557BF6' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO

xcodebuild build -quiet -project GopherForge.xcodeproj -scheme GopherForge \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

The final ordinary suite passed **309/309** tests in the iOS 18.2 Simulator.
The separate bundled compiler gate passed **8/8** tests on the same simulator.
After integrating into `main`, the ordinary suite passed **309/309** and the
compiler gate passed **8/8** again. The added real-toolchain Build A/edit B
race test passed **1/1** on `main`; the final compiler-gate run with that test
passed **9/9**. The navigator regression passed **1/1** on each of the iPhone
17 Pro Max and iPad Pro 13-inch simulators after integration.
The final ordinary scheme reports one intentional skip: the compiler-gate
class runs in its dedicated scheme, where none of its nine tests were skipped.
The gate runs real bundled Go compile, link, run and test work, but these
simulator results do not close physical-device Gate B.
The Release simulator build passed under Xcode 27.0 beta (27A5228h). Its
`GopherForge` executable was 20 MB with SHA-256
`b673d51919407c15494a7d7ea3fe9ebaed28a9e544f9b8180b1d506f042f0619`.
This is not a signed iOS archive or TestFlight binary.
Machine-readable summaries are in
[`unit-tests-summary.json`](../release-evidence/harden-gopherforge-core/unit-tests-summary.json)
and [`compiler-gate-summary.json`](../release-evidence/harden-gopherforge-core/compiler-gate-summary.json).
The navigator UI check passed on iPhone and iPad simulators. The refreshed
[iPhone Code](screenshots/navigator-iphone-code.png),
[iPhone Files](screenshots/navigator-iphone-files.png) and
[iPad persistent tree](screenshots/navigator-ipad-persistent.png) images show
one drawer on iPhone and one persistent tree on iPad; they are not hardware
Gate B evidence.
