# TestFlight: GopherForge 1.0.0 (6)

Build 6 carries the workspace hardening on `main`. It preserves each project's
UUID across rename and relaunch, keeps a newer source edit when an older build
finishes, reports failed saves with retry/export, and selects the intended Go
command for Build/Run while Format ignores unresolved imports. The iPhone
Files drawer and iPad persistent tree from build 5 remain in place.

Build 6 is intended for **internal TestFlight**. A real Stop for a CPU loop or a
blocking guest call within one second, and a file quota enforced before guest
writes, are still **BLOCKED** with the pinned WasmKit 0.3.1 integration. Do not
describe either as fixed. Physical iPhone/iPad Gate B and an actual ENOSPC
exercise remain **NOT RUN** until device evidence exists. The requirement table
and exact tests are in [the hardening evidence](HARDEN-GOPHERFORGE-CORE.md).
On the merged source, the ordinary iOS 18.2 Simulator suite passed **309/309**,
the real bundled-compiler gate passed **9/9**, and the navigator UI test passed
on both iPhone 17 Pro Max and iPad Pro 13-inch Simulators. These are simulator
results, not physical-device evidence. The exact commands and xcresult
summaries are in [the local verification record](../release-evidence/1.0.0/6/verification.md).

## Build and delivery

1. Source must be the pushed `main` commit containing this guide. Both the app
   and Share Extension have `MARKETING_VERSION = 1.0.0` and
   `CURRENT_PROJECT_VERSION = 6` in `project.yml` and the generated Xcode
   project. `ci_scripts/ci_post_clone.sh` stages the pinned Go toolchain and
   regenerates the project in Xcode Cloud.
2. Run the existing **Default** GopherForge Xcode Cloud workflow on `main`:
   released Xcode 26.6/macOS 26.6.2, Archive - iOS, App Store Connect
   distribution preparation, and
   `XCODE_XCCONFIG_FILE=/Volumes/workspace/repository/ci_scripts/Release.xcconfig`.
   Its TestFlight Internal Testing post-action should select **Internal QA**.
   The Cloud **Next Build Number** must produce build **6**. Apple's
   [build-number setting](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds/)
   is separate from the checked-in Xcode build setting.
3. Confirm the Cloud archive names **GopherForge 1.0.0 (6)** and the exact
   `main` commit. Wait for App Store Connect processing, confirm the build is
   available to **Internal QA**, and set What to Test from
   [`what-to-test.txt`](../release-evidence/1.0.0/6/what-to-test.txt).

Until step 3 is confirmed, upload and tester availability are **NOT RUN**.
The local Release Simulator build is not a signed TestFlight archive.

## Tester path

Open the existing Playground, edit `main.go`, leave Build, return, and relaunch.
The edit should still be there and no template should replace it. Create two
projects with the same name, edit each, rename one, and confirm both retain
their separate code. While Build is running, edit and save the source; its
result may finish, but the newer edit should remain after relaunch. Try Format
with an unresolved import: formatting should still work. Put an unresolved
import only in `_test.go`: Run should still run, while Test should report the
test problem. Select another `main.go` from a command subdirectory and confirm
Run uses that command.

On iPhone, Build → Code should fill the available width. Files opens exactly
one drawer and selecting a file closes it. On iPad, one file tree should remain
beside the editor, including in a narrow Stage Manager window; there should be
no second drawer. The expected appearances are in the
[README screenshots](../README.md#what-it-looks-like).

Do not use Stop to test a runaway program in this build. If a save reports
“Не сохранено”, keep the app open, use Retry or Export, and report what filled
the device storage. Record physical iPhone and iPad observations against
[DEVICE-GATE](DEVICE-GATE.md); simulator results do not close it.
