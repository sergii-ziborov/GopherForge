# TestFlight: GopherForge 1.0.0 (5)

Build 5 fixes the Build workspace's file navigator. On iPhone, the editor uses
the available width until Files opens a single drawer over it. On iPad, one
searchable file tree remains beside the editor, even when the iPad window is
narrow. The UI regression test is
`NavigatorFlowUITests.testNavigatorOccupiesOnePlaceForTheDevice`.

As of 13 September 2026, build 5 has been archived locally and tested in the
Simulator but **has not been uploaded to TestFlight**. The local archive was
signed for development, and this Mac has neither an Apple Distribution
certificate nor App Store provisioning profiles. Xcode Cloud prepared build 4
with distribution signing on released Xcode and macOS; use that route for the
new upload. Do not present the local archive as a distributed build.

Apple rejected the build 4 App Review submission under Guideline 2.1 and
requested a physical-device recording of a typical app flow, starting at app
launch, along with a reply and App Review Information notes. This is a
separate requirement before resubmitting version 1.0; the
[review message](https://appstoreconnect.apple.com/apps/6809702319/distribution/reviewsubmissions/details/c9179887-1814-43ee-badc-fce5bbd1ac48)
has the complete instructions.

## Release path

1. Push the build 5 source and this guide to `main`. Both the app and Share
   Extension must have `CURRENT_PROJECT_VERSION = 5` in `project.yml` and the
   generated Xcode project.
2. In App Store Connect, run the **App Store Release** Xcode Cloud workflow on
   `main`. It needs released **Xcode 26.6** and **macOS 26.6.2**, Archive
   distribution preparation **App Store Connect**, and
   `XCODE_XCCONFIG_FILE=/Volumes/workspace/repository/ci_scripts/Release.xcconfig`.
   `ci_scripts/ci_post_clone.sh` stages the pinned Go toolchain and generates
   the project. [Apple says public Swift package dependencies require no
   separate Xcode Cloud connection](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud).
3. Check that the Cloud archive identifies **GopherForge 1.0.0 (5)** and the
   intended `main` commit. Wait for Apple to process it in TestFlight, then
   assign it to **Internal QA** and paste
   [`what-to-test.txt`](../release-evidence/1.0.0/5/what-to-test.txt) into the
   build's What to Test field.

The original GopherForge Cloud product and **App Store Release** workflow are
currently absent from the App Store Connect Cloud page, although build 4 was
created by that workflow. Re-creating it in Xcode 27 beta stops at a GitHub
authorization screen that asks for installation rights in upstream public
organizations such as `apple` and `swiftwasm`; this account cannot grant those
rights. [Apple's dependency guide](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud)
says public packages need no separate connection. Restore the original Cloud
product/workflow or resolve this onboarding defect with Apple before step 2.
A local development-signed archive is not a substitute for App Store Connect
distribution signing.

## Device check

On iPhone, open **Build → Code**. The left edge of the editor should sit near
the left edge of the workspace, with no narrow file column alongside it. Tap
**Files**: one searchable drawer appears over the editor. Select `go.mod`:
the drawer closes and the editor shows the module file. Reopen Files and select
`main.go`; the editor returns to the Go source at the same width.

On iPad, open **Build**. A single searchable file tree stays beside the editor.
Switch between `go.mod` and `main.go`; the tree remains visible. There should
be no Files button that opens a second tree. Repeat with a narrow Stage Manager
window. The screenshots in the [README](../README.md#what-it-looks-like) show
the expected closed iPhone editor, open iPhone drawer, and persistent iPad tree.

The regression passed on iPhone 14, iPhone 17 Pro Max, iPad Pro 11-inch and
iPad Pro 13-inch Simulators. One heavily loaded iPhone 17 Pro Max run missed
the file-row tap; a repeat with serial testing passed. The physical-device
check and the broader offline, thermal and memory work remain in
[Device gate](DEVICE-GATE.md).
