# TestFlight: GopherForge 1.0.0 (5)

Build 5 fixes the Build workspace's file navigator. On iPhone, the editor uses
the available width until Files opens a single drawer over it. On iPad, one
searchable file tree remains beside the editor, even when the iPad window is
narrow. The UI regression test is
`NavigatorFlowUITests.testNavigatorOccupiesOnePlaceForTheDevice`.

On 13 September 2026, Xcode Cloud **build 5 succeeded** from `main` commit
`4f717ea8b30bece03ff603917d14c4c82552e1f2`, and App Store Connect
completed the upload of **GopherForge 1.0.0 (5)**. The **Internal QA** group
has access to the build, and its **What to Test** field contains the
[navigator check](../release-evidence/1.0.0/5/what-to-test.txt). The separate
local archive was development-signed and was not uploaded.

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
2. In App Store Connect, run the GopherForge Xcode Cloud workflow on `main`.
   It needs released **Xcode 26.6** and **macOS 26.6.2**, Archive
   distribution preparation **App Store Connect**, and
   `XCODE_XCCONFIG_FILE=/Volumes/workspace/repository/ci_scripts/Release.xcconfig`.
   `ci_scripts/ci_post_clone.sh` stages the pinned Go toolchain and generates
   the project. [Apple says public Swift package dependencies require no
   separate Xcode Cloud connection](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud).
3. Check that the Cloud archive identifies **GopherForge 1.0.0 (5)** and the
   intended `main` commit. Wait for Apple to process it in TestFlight, confirm
   the **Internal QA** post-action assigned the group, and paste
   [`what-to-test.txt`](../release-evidence/1.0.0/5/what-to-test.txt) into the
   build's What to Test field.

The original **App Store Release** workflow created build 4 but disappeared
from the Cloud page. On 13 September, a replacement **Default** workflow was
connected to the public [main repository](https://github.com/sergii-ziborov/GopherForge).
It has Manual Start, released Xcode/macOS, the release xcconfig variable,
**Archive - iOS** with **App Store Connect** distribution preparation, and a
**TestFlight Internal Testing** post-action for **Internal QA**. Its first,
temporary Build-only run failed because the environment variable had not yet
been saved. The first Archive run, Cloud build 2, reached distribution but
failed because the replacement Cloud product started numbering at 1 while
App Store Connect already had build 4 of version 1.0.0. Set **Next Build
Number** to **5** in Cloud Settings; Cloud build 5 then archived and delivered
successfully. [Apple documents this setting](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds/).

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
